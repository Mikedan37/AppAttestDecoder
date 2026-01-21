# Assertion Generation Must Be Single-Shot

## Observed Behavior

During App Attest verification, the backend correctly rejected assertions with:

```
"Signature did not verify under supplied public key"
```

Investigation revealed:
- Two assertions were generated in one UI flow
- One assertion was logged/inspected for UI display
- A different assertion was sent to the backend
- Backend rejected with valid signature verification failure

## Why This Happens

Each call to `DCAppAttestService.generateAssertion()` produces a new signature over fresh authenticator data. Even with the same `keyID` and `clientDataHash`, the assertion bytes differ because:
- Sign count increments
- Authenticator data includes fresh timestamp
- Signature is computed over the new bytes

Logging or inspecting one assertion proves nothing about a different assertion generated later. Only the exact bytes sent to the backend matter for verification.

## How to Detect

Log SHA256 fingerprints immediately before sending:

```swift
let assertionFingerprint = Data(SHA256.hash(data: assertionObject)).map { String(format: "%02x", $0) }.joined()
print("assertionObject SHA256: \(assertionFingerprint)")
```

If the backend logs a different fingerprint, you're sending a different assertion than the one you generated.

## Resolution

Generate assertion exactly once, immediately before sending:

1. Compute `clientDataHash` once
2. Call `generateAssertion(keyID, clientDataHash)` once
3. Send the exact `Data` returned from that call
4. Do not regenerate for logging, inspection, or UI display

Treat inspection paths as read-only. If you need to inspect an assertion, inspect the one you're about to send, not a separately generated one.

## Common Mistake Pattern

```swift
// WRONG: Generate for inspection
service.generateAssertion(...) { assertion1 in
    self.assertionBlobB64 = assertion1.base64EncodedString() // For UI
}

// Later: Generate again for sending
service.generateAssertion(...) { assertion2 in
    sendToBackend(assertion2) // Different assertion!
}
```

The UI shows `assertion1`, but the backend receives `assertion2`. They are different signatures.

## Correct Pattern

```swift
// RIGHT: Generate once, use immediately
service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertionObject in
    // Log fingerprint
    let fingerprint = Data(SHA256.hash(data: assertionObject)).map { String(format: "%02x", $0) }.joined()
    
    // Send immediately
    sendToBackend(assertionObject, clientDataHash: clientDataHash)
    
    // Optionally store for UI (but don't regenerate)
    self.assertionBlobB64 = assertionObject.base64EncodedString()
}
```

## Detection Checklist

If backend rejects with "signature did not verify", check:

1. **Single generation:** Only one `generateAssertion` call per verification flow
2. **Fingerprint match:** SHA256 of sent assertion matches backend logs
3. **No regeneration:** Assertion used for UI is the same instance sent to backend
4. **Immediate send:** No storage/retrieval between generation and send

If fingerprints don't match, you're sending a different assertion than you generated.
