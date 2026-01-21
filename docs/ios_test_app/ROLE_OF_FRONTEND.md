# Role of the Frontend

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

This document describes what the frontend displays, forwards, and records.

---

## What the Frontend Displays

The frontend is a diagnostic instrument that:

1. **Displays artifact generation**
   - Shows keyID returned by `DCAppAttestService.generateKey()`
   - Shows attestationObject bytes returned by `DCAppAttestService.attestKey()`
   - Shows assertionObject bytes returned by `DCAppAttestService.generateAssertion()`

2. **Forwards data unchanged**
   - Sends raw bytes exactly as provided by the App Attest API
   - No modification, no interpretation, no transformation
   - Handles network errors (connection failures, timeouts, HTTP errors)

3. **Records evidence for debugging**
   - Decodes artifacts for logging only (CBOR, ASN.1 parsing)
   - Extracts raw bytes for forensic logging
   - Computes hashes for log correlation
   - Stores evidence temporarily for UI display

4. **Displays backend responses**
   - Shows backend HTTP responses verbatim
   - Does not infer meaning from response status
   - Attributes status to backend ("Backend response (status: verified)")

---

## What the Frontend Never Does

The frontend never:
- Verifies cryptographic signatures
- Validates certificate chains
- Checks certificate expiration or revocation
- Makes trust decisions
- Enforces policies
- Blocks operations based on backend status
- Interprets validity
- Assumes trust

---

## Frontend Authority Boundaries

The frontend performs no cryptographic verification, makes no security decisions, treats responses as non-authoritative, and does not block operations based on backend status.

**No cryptographic verification:**
- No signature verification
- No certificate chain validation
- No certificate expiration checks
- No nonce verification

**No security decisions:**
- No trust decisions
- No authorization decisions
- No policy enforcement
- No validity interpretation

**Non-authoritative responses:**
- Backend responses are displayed verbatim
- Status values are literal strings, not interpreted
- No meaning is inferred from response codes

**No blocking:**
- Operations are not blocked based on backend status
- Buttons remain enabled regardless of response
- State is preserved regardless of response

---

## Related Documentation

- **`GUIDE.md`** - Complete guide (includes this content in Chapters 1-2)
- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Detailed contract and invariants
- **`DATA_FLOW.md`** - Detailed data flow documentation
- **`../APP_ATTEST_E2E_CONTRACT.md`** - End-to-end protocol contract
- **`../VERIFICATION_GUIDE.md`** - Backend verification responsibilities
