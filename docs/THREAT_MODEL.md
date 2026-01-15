# Threat Model (Non-Goals)

This document explicitly states what this tool does **not** defend against and what assumptions it makes. This is not a security audit. It is a boundary statement.

## What This Tool Does Not Defend Against

### Replay Attacks

**This tool does not detect or prevent replay attacks.**

- Attestation objects can be replayed if your backend does not track sign counts
- This tool parses sign counts but does not validate them against a database
- You must implement replay protection in your validator

**What to do:** Track sign counts server-side. Reject attestations with non-increasing sign counts.

### Compromised Secure Enclave

**This tool does not detect compromised Secure Enclave hardware.**

- This tool assumes the Secure Enclave is functioning correctly
- It does not verify hardware integrity or detect tampering
- Apple's attestation chain is trusted by design

**What to do:** Rely on Apple's hardware security guarantees. This tool cannot verify hardware integrity.

### Certificate Chain Validation

**This tool does not validate certificate chains.**

- It parses certificates and displays their structure
- It does not verify signatures, expiration, or revocation
- It does not check against Apple's root certificates

**What to do:** Implement full certificate chain validation in your backend using standard X.509 validation libraries.

### Cryptographic Signature Verification

**This tool does not verify cryptographic signatures.**

- It displays signature algorithms and raw signature bytes
- It does not verify that signatures are valid
- It does not verify that signatures match the signed content

**What to do:** Use cryptographic libraries (e.g., `Security.framework`, OpenSSL) to verify signatures server-side.

### Policy Enforcement

**This tool does not enforce security policies.**

- It does not decide if an attestation is "valid" or "acceptable"
- It does not check bundle IDs, team IDs, or environment constraints
- It does not make trust decisions

**What to do:** Implement policy checks in your validator based on decoded fields.

## Assumptions

### Apple Signing Keys Are Trusted

**This tool assumes Apple's signing keys are trusted.**

- It does not verify Apple root certificates
- It assumes Apple's certificate authority is legitimate
- It does not check certificate revocation lists

**Rationale:** If Apple's root certificates are compromised, the entire App Attest system is compromised. This tool cannot defend against that scenario.

### Input Data Is Not Maliciously Crafted

**This tool assumes input data is from Apple's App Attest service.**

- It does not defend against maliciously crafted attestation objects
- It does not perform deep validation of all fields
- It may crash or produce incorrect output on hostile input

**Rationale:** This tool is for inspection of legitimate artifacts, not fuzzing or security testing. Use appropriate tools for that.

### Parsing Errors Indicate Invalid Input

**This tool assumes parsing errors indicate invalid or corrupted input.**

- It does not distinguish between malicious and corrupted input
- It does not attempt to recover from parsing errors
- It exits with error codes on any parsing failure

**Rationale:** This tool prioritizes correctness over resilience. Invalid input should be rejected, not interpreted.

## What This Tool Provides

This tool provides:

- **Structural parsing** of attestation objects
- **Field extraction** from CBOR, ASN.1, and X.509 structures
- **Evidence preservation** (raw bytes alongside decoded values)
- **Transparency** into Apple's trust artifacts

It does **not** provide:

- Cryptographic verification
- Trust decisions
- Security guarantees
- Policy enforcement

## Summary

This tool is an **inspection instrument**, not a **security validator**. Use it to understand what Apple's App Attest service produces. Do not use it to make security decisions without additional validation.

If you need security guarantees, implement a complete validator that:

1. Verifies cryptographic signatures
2. Validates certificate chains
3. Checks certificate expiration and revocation
4. Enforces policy constraints
5. Tracks sign counts to prevent replay
6. Validates all decoded fields against expected values

This tool provides the raw materials. Your validator provides the security.
