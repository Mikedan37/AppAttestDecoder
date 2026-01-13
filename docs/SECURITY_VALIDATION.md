# Production Validation Checklist

This document provides a complete checklist for implementing server-side validation of App Attest artifacts. The decoder in this project only parses structure; all security validation must be implemented separately.

**Important**: The decoder exposes all raw materials needed for validation (signatures, certificate chains, authenticator data bytes, RP ID hashes) via its public API. A validator can consume these without re-parsing the original bytes. All exposed properties are documented as unvalidated.

> **See also**: Apple's official [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations) for complete validation requirements and best practices.

## Quick Reference: Production Validation Checklist

| Step | Requirement | Security Impact |
|------|-------------|-----------------|
| Format validation | Verify `fmt == "apple-appattest"` | Prevents invalid format acceptance |
| RP ID hash verification | SHA256(bundle ID) must match `authData.rpIdHash` | Ensures attestation is for your app |
| Certificate chain validation | Validate `attStmt.x5c` against Apple's App Attest Root CA | Prevents forged attestations |
| Signature verification | Verify attestation signature using validated certificate | Ensures data integrity |
| Nonce/challenge verification | Compare SHA256(authData + clientDataHash) with certificate extension OID 1.2.840.113635.100.8.2 | **Prevents replay attacks** |
| Challenge uniqueness | Each challenge must be used only once | **Prevents replay attacks** |
| Team ID validation | Verify certificate chain corresponds to expected Team ID | Ensures attestation is from your team |

## Complete Validation Checklist

For production deployment, ensure your backend validation includes:

- [ ] Format validation: `fmt == "apple-appattest"`
- [ ] RP ID hash verification: SHA256(bundle identifier) matches `authData.rpIdHash`
- [ ] Certificate chain validation: Validate `attStmt.x5c` against Apple's App Attest Root CA
- [ ] Cryptographic signature verification: Verify attestation signature using the validated certificate chain
- [ ] Nonce/challenge verification: Compare SHA256(authData + clientDataHash) with certificate extension OID 1.2.840.113635.100.8.2
- [ ] Challenge uniqueness: Ensure each challenge is used only once (implement challenge tracking/expiration)
- [ ] Team ID validation: Verify the certificate chain corresponds to your expected Team ID

## Certificate Chain Validation

Certificate chain validation must be performed using **Apple's App Attest Root CA** as the trust anchor. The certificate chain in `attStmt.x5c` must be validated against Apple's trusted root certificate before any cryptographic verification. This is a fundamental security requirement - without proper certificate chain validation, an attacker could present a forged attestation.

Apple's App Attest Root CA certificate is publicly available and should be used as the sole trust anchor for validating App Attest certificate chains. Do not accept certificate chains that do not validate against this root.

## Replay Attack Prevention

The nonce/challenge validation step is **essential for preventing replay attacks**. Apple's validation process requires:

1. **Generate a unique server challenge** for each attestation request (never reuse challenges)
2. **Compute `clientDataHash`** as SHA256 of your server challenge
3. **Compute `nonce`** as SHA256(authData + clientDataHash)
4. **Extract the nonce** from the attestation certificate extension (OID 1.2.840.113635.100.8.2)
5. **Compare** the computed nonce with the extracted nonce - they must match exactly

This ensures that:
- The attestation was generated in response to your specific challenge
- The attestation cannot be replayed from a previous request
- The authenticator data corresponds to the challenge you issued

**Never skip nonce validation** - it is a critical security control that prevents attackers from reusing old attestations.

## Security Best Practices

**Logging Sensitive Data**: Attestation objects contain device-specific information and cryptographic material. Avoid logging raw attestation data, certificate contents, or authenticator data in production logs. If logging is necessary for debugging, use sanitized representations (e.g., hash values, certificate fingerprints) and ensure logs are properly secured and access-controlled.

## Example Implementation

```swift
// In your backend service
let decoder = AppAttestDecoder(teamID: expectedTeamID)
let attestation = try decoder.decodeAttestationObject(attestationData)

// All raw materials are exposed via the decoder API:
// - attestation.rawData: Original CBOR bytes for signature verification
// - attestation.authenticatorData.rpIdHash: RP ID hash (32 bytes)
// - attestation.authenticatorData.rawData: Authenticator data bytes
// - attestation.attestationStatement.signature: Signature bytes
// - attestation.attestationStatement.x5c: Certificate chain (DER-encoded)
// - attestation.attestationStatement.alg: Algorithm identifier

// Step 1: Validate structure
guard attestation.format == "apple-appattest" else { throw ValidationError() }

// Step 2: Verify RP ID Hash
// The RP ID hash in authData must match SHA256 of your app's bundle identifier
let expectedRPIDHash = SHA256.hash(data: "com.yourcompany.yourapp".data(using: .utf8)!)
guard attestation.authenticatorData.rpIdHash == expectedRPIDHash else { 
    throw ValidationError("RP ID hash mismatch") 
}

// Step 3: Validate certificate chain
// CRITICAL: Validate certificate chain against Apple's App Attest Root CA as trust anchor
let certificates = attestation.attestationStatement.x5c
// ... perform X.509 certificate chain validation using Apple's App Attest Root CA
// ... verify signature using the validated leaf certificate

// Step 4: Verify nonce/challenge (CRITICAL for replay attack prevention)
// Construct: nonce = SHA256(authData + clientDataHash)
// where clientDataHash = SHA256 of your unique server challenge
// IMPORTANT: Each challenge must be unique and used only once
let clientDataHash = SHA256.hash(data: uniqueServerChallenge.data(using: .utf8)!)
let authData = attestation.authenticatorData.rawData
let computedNonce = SHA256.hash(data: authData + clientDataHash)

// Extract nonce from attestation certificate extension (OID 1.2.840.113635.100.8.2)
// Compare extracted nonce with computed nonce - they must match exactly
// ... extract nonce from certificate extension and compare
guard extractedNonce == computedNonce else {
    throw ValidationError("Nonce mismatch - possible replay attack")
}

// Step 5: Mark challenge as used (prevent replay)
// ... record that this challenge has been used and cannot be reused
```

## Important Notes

The decoder only handles parsing. Full server validation requires:

1. Certificate chain validation against Apple's App Attest Root CA (as the trust anchor)
2. Cryptographic signature verification using the validated certificate chain
3. RP ID hash verification (SHA256 of bundle identifier)
4. Nonce/challenge verification (comparing SHA256(authData + clientDataHash) with certificate extension) - **essential for replay attack prevention**
5. Challenge tracking to ensure each challenge is used only once

Refer to Apple's [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations) for complete validation requirements.

