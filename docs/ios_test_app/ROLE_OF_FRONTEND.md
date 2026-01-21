# Role of the Frontend

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

This document explains what the frontend does, what it never does, and why this distinction matters.

---

## What the Frontend Does

The frontend is a **diagnostic tool** that:

1. **Generates artifacts** via the App Attest API
   - Creates keys using `DCAppAttestService.generateKey()`
   - Creates attestations using `DCAppAttestService.attestKey()`
   - Creates assertions using `DCAppAttestService.generateAssertion()`

2. **Transports data** to the backend unchanged
   - Sends raw bytes exactly as provided by the App Attest API
   - No modification, no interpretation, no transformation
   - Handles network errors (connection failures, timeouts, HTTP errors)

3. **Logs evidence** for debugging
   - Decodes artifacts for logging only (CBOR, ASN.1 parsing)
   - Extracts raw bytes for forensic logging
   - Computes hashes for log correlation
   - Stores evidence temporarily for UI display

4. **Displays backend responses**
   - Shows backend HTTP responses without interpretation
   - Does not infer meaning from response status
   - Does not make security assessments

---

## What the Frontend Never Does

The frontend **never**:

1. **Verifies cryptographic signatures**
   - Does not call `CryptoKit.isValidSignature`
   - Does not validate certificate chains
   - Does not check certificate expiration or revocation
   - Does not verify RP ID hashes or nonces

2. **Makes security decisions**
   - Does not infer that assertions "will verify" or "will not verify"
   - Does not block assertion generation based on security assumptions
   - Does not make trust decisions about artifacts
   - Does not reject artifacts based on cryptographic interpretation

3. **Interprets validity**
   - Does not claim artifacts are "valid" or "invalid"
   - Does not infer verification success/failure beyond HTTP status codes
   - Does not interpret certificate chain validity
   - Does not interpret signature validity
   - Does not make policy decisions (bundle ID matching, environment checks)

4. **Assumes trust**
   - Does not assume backend acceptance means cryptographic validity
   - Does not cache trust state ("this key is trusted")
   - Does not reuse assertions across different challenges
   - Does not assume continuity implies security

---

## Why This Distinction Matters

### Security Boundary

The frontend operates on the **client side** of a security boundary. The backend operates on the **server side** where all cryptographic verification happens.

**Frontend responsibility:** Generate and transport artifacts correctly.

**Backend responsibility:** Verify cryptographic signatures, validate certificate chains, enforce policies, prevent replay attacks.

### Diagnostic vs Production

This is a **diagnostic test app**, not a production client. It is:
- Verbose and forensic (for debugging)
- Non-optimized (for clarity)
- Explicitly non-authoritative (for learning)

Production frontend implementations should follow similar principles but must be validated independently.

### Learning vs Security

The frontend helps you **learn** how App Attest works by:
- Showing what data is generated
- Showing what data is sent
- Showing backend responses

The frontend does **not** help you make security decisions. All security decisions happen on the backend.

---

## Related Documentation

- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Detailed contract and invariants
- **`DATA_FLOW.md`** - What data is produced and sent
- **`../APP_ATTEST_E2E_CONTRACT.md`** - End-to-end protocol contract
- **`../VERIFICATION_GUIDE.md`** - Backend verification responsibilities
