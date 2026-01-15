# Anti-Patterns: What NOT To Do

This document shows common misuse patterns and explains why they are wrong. These patterns will cause security failures.

## Do NOT Do This

```swift
// WRONG: Using decoder output to make trust decisions
let output = decoder.decode(attestation)
if output.looksValid {
    allowRequest()
}
```

**Why this is wrong:**

1. **No cryptographic verification** - The decoder only parses structure. It does not verify signatures, certificate chains, or cryptographic integrity. A malicious attacker could craft a structurally valid but cryptographically invalid attestation.

2. **No policy enforcement** - The decoder does not check if the bundle ID, team ID, or environment match your expectations. It only shows what is present. You must validate these fields separately.

3. **No replay protection** - The decoder shows sign counts but does not track them. An attacker could replay an old attestation if you don't verify sign counts server-side.

**What to do instead:**

```swift
// CORRECT: Use decoder for inspection, validator for decisions
let model = decoder.decode(attestation)

// Inspect what was decoded
print("Bundle ID: \(model.identity.bundleID)")
print("Team ID: \(model.identity.teamID)")

// Then validate separately
let validator = AttestationValidator()
let result = validator.verify(
    attestation: attestation,
    expectedBundleID: "com.example.app",
    expectedTeamID: "ABC123XYZ",
    signCount: getStoredSignCount(for: model.identity.credentialID)
)

if result.isValid {
    allowRequest()
}
```

## Do NOT Do This

```swift
// WRONG: Assuming decoded fields are always correct
let bundleID = decoder.decode(attestation).bundleID
if bundleID == expectedBundleID {
    // Trust this attestation
}
```

**Why this is wrong:**

1. **No signature verification** - The decoder extracts fields without verifying they are authentic. An attacker could modify the attestation object to change the bundle ID without invalidating the structure.

2. **No certificate validation** - The decoder does not verify that certificates are valid, not expired, or not revoked. It only parses their structure.

**What to do instead:**

```swift
// CORRECT: Verify signatures first, then check fields
let validator = AttestationValidator()
let verificationResult = validator.verifySignature(attestation)

if !verificationResult.isValid {
    rejectRequest()
    return
}

// Now safe to check decoded fields
let model = decoder.decode(attestation)
if model.identity.bundleID != expectedBundleID {
    rejectRequest()
    return
}
```

## Do NOT Do This

```bash
# WRONG: Using exit codes to make security decisions
if ./decoder --file attestation.b64; then
    echo "Attestation is valid"
    allowRequest
fi
```

**Why this is wrong:**

1. **Exit codes indicate parsing success, not validity** - Exit code 0 means the attestation was successfully parsed, not that it is cryptographically valid or trustworthy.

2. **No security checks** - The decoder does not perform any security checks. A malicious attestation could parse successfully but be completely invalid.

**What to do instead:**

```bash
# CORRECT: Use decoder for inspection, validator for decisions
./decoder --file attestation.b64 > decoded.json

# Then validate separately
./validator --attestation attestation.b64 \
           --decoded decoded.json \
           --expected-bundle-id "com.example.app"

if [ $? -eq 0 ]; then
    allowRequest
fi
```

## Do NOT Do This

```swift
// WRONG: Ignoring sign counts
let model = decoder.decode(attestation)
// Use attestation without checking sign count
allowRequest()
```

**Why this is wrong:**

1. **Replay attacks** - Sign counts prevent replay attacks. If you don't check them, an attacker can replay old attestations.

2. **No state tracking** - The decoder shows sign counts but does not track them. You must track sign counts server-side.

**What to do instead:**

```swift
// CORRECT: Track and verify sign counts
let model = decoder.decode(attestation)
let credentialID = model.identity.credentialID
let currentSignCount = model.identity.signCount.value

let storedSignCount = getStoredSignCount(for: credentialID)

if currentSignCount <= storedSignCount {
    // Replay attack detected
    rejectRequest()
    return
}

// Update stored sign count
storeSignCount(for: credentialID, value: currentSignCount)
allowRequest()
```

## Do NOT Do This

```swift
// WRONG: Using decoder output in production without validation
let model = decoder.decode(attestation)
database.store(model.identity.bundleID) // No verification!
```

**Why this is wrong:**

1. **No authenticity guarantee** - The decoder does not verify that the attestation is authentic. An attacker could craft a fake attestation that parses correctly.

2. **No integrity check** - The decoder does not verify that the attestation has not been tampered with. Fields could be modified without detection.

**What to do instead:**

```swift
// CORRECT: Verify first, then use
let validator = AttestationValidator()
let verificationResult = validator.verify(attestation)

if !verificationResult.isValid {
    rejectRequest()
    return
}

// Now safe to use decoded fields
let model = decoder.decode(attestation)
database.store(model.identity.bundleID)
```

## Summary

**The decoder is for inspection, not validation.**

- Use it to understand what Apple's App Attest service produces
- Use it to debug attestation issues
- Use it to build your own validator

**Do not use it to:**

- Make trust decisions
- Verify cryptographic signatures
- Enforce security policies
- Prevent replay attacks

**Always implement a separate validator that:**

1. Verifies cryptographic signatures
2. Validates certificate chains
3. Checks policy constraints
4. Tracks sign counts
5. Validates all fields

The decoder provides the raw materials. Your validator provides the security.
