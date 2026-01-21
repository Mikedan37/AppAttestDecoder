# App Attest Key Continuity Failure: SwiftUI State Is Not Identity

## Symptom

During App Attest assertion verification, the backend correctly rejected assertions with:

```
"Signature did not verify under supplied public key"
```

Registration succeeded. The public key was stored. The assertion format was correct. The `clientDataHash` bytes matched. But signature verification failed.

## Why This Failure Is Non-Obvious

The failure appears as a cryptographic verification error, which suggests:
- Backend validator bug
- Signature encoding issue
- Public key extraction problem
- Protocol misunderstanding

In reality, the backend was correct. The assertion was signed by a different private key than the one whose public key was registered.

The non-obvious part:
- KeyID values appeared identical (same base64 string)
- Operations happened in sequence (attest, then assert)
- No explicit key regeneration in the code
- SwiftUI view lifecycle silently replaced the key reference

## Why App Attest Requires Strict Key Continuity

App Attest signature verification requires:

```
ECDSA_verify(
    publicKey,  // Extracted from attestation certificate
    SHA256(Sig_structure),
    signature   // From assertion
)
```

For this to succeed, the private key that signed the assertion must be the same key whose public key was extracted during attestation. This is an identity requirement, not a timing requirement.

If:
- Attestation uses Key A → backend stores pub(A)
- Assertion uses Key B → backend verifies with pub(A)

Then verification must fail, even if Key A and Key B have identical keyID strings. Secure Enclave keys are not interchangeable by string equality.

## The Specific Mistake

The iOS test app stored `keyID` in SwiftUI `@State`:

```swift
@State private var keyID: String?
```

SwiftUI view lifecycle can:
- Recreate views
- Reset state
- Re-run initialization
- Invalidate references

When this happens:
1. `generateKey()` may be called again (implicitly or explicitly)
2. A new Secure Enclave key is created
3. The `keyID` string may look identical (base64 encoding)
4. But it references a different underlying key

Sequence does not guarantee identity. The same code path can use different keys if state is not preserved.

## The Fix

Introduce a persistent key manager that survives SwiftUI lifecycle:

```swift
class AppAttestKeyManager {
    static let shared = AppAttestKeyManager()
    private(set) var currentKeyID: String?
    
    func setKeyID(_ keyID: String) {
        if let existing = currentKeyID, existing != keyID {
            // Fail early if key changes
        }
        currentKeyID = keyID
    }
}
```

Enforce keyID continuity at critical points:
- Before attestation: verify keyID matches stored keyID
- Before assertion: verify keyID matches stored keyID
- Before verification: verify keyID matches stored keyID

Fail early if keyID ever changes between operations.

## Warning: If Backend Rejects Valid-Looking Assertion

If your backend rejects an assertion with "signature did not verify under supplied public key", assume key mismatch first:

1. **Check keyID continuity:**
   - Log keyID (hex) at generateKey, attest, and assert
   - Verify they match byte-for-byte
   - Not just base64 strings—actual Secure Enclave key identity

2. **Check backend state:**
   - If using RAM-backed storage, verify service didn't restart
   - Verify public key lookup uses the exact keyID from the request

3. **Check clientDataHash:**
   - Verify the exact same bytes used in `generateAssertion` are sent to backend
   - No recomputation, no regeneration

The backend is doing its job. The failure is in key continuity, not validation logic.

## Lessons

- SwiftUI `@State` is not process-level identity
- Sequence does not guarantee key continuity
- Base64 string equality does not guarantee Secure Enclave key identity
- Fail early on keyID changes, not at verification time

This is a real App Attest footgun that Apple's documentation does not address.
