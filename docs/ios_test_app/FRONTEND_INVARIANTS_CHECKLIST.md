# Frontend App Attest Invariants Checklist

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

> **Reference:** This checklist ensures compliance with `FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md` (authoritative).

This checklist verifies the frontend complies with the Frontend App Attest Responsibility Contract.

---

## Transport Invariants

- [x] Attestation/assertion bytes are never modified after generation
- [x] Base64 encoding happens only at network boundary
- [x] No re-encoding, re-hashing, or transformation of artifacts
- [x] Network errors are handled without inferring security state
- [x] URL encoding is correct (base64 values properly encoded)

---

## State Invariants

- [x] `flowID` comes only from REGISTER response
- [x] `challenge_id` comes only from challenge response
- [x] `keyID` comes only from `DCAppAttestService`
- [x] No state is assumed or inferred
- [x] State consistency checks are clearly labeled (not security decisions)

---

## Evidence Invariants

- [x] Decoding is observational only (for logging)
- [x] Evidence is never used for security decisions
- [x] Hashes are computed for correlation, not validation
- [x] Raw bytes are preserved alongside decoded values
- [x] `CryptoEvidence` is used for logging/export only

---

## Request Construction Invariants

- [x] `clientDataBytes` is built once with sorted keys
- [x] `clientDataHash` is computed once from `clientDataBytes`
- [x] Same `clientDataBytes` is hashed and sent (byte-for-byte)
- [x] `assertionObject` is sent unchanged from `generateAssertion()`
- [x] No assertion reuse across different challenges

---

## Response Handling Invariants

- [x] Backend responses are displayed without interpretation
- [x] HTTP status codes are handled, not inferred
- [x] No trust decisions based on response content
- [x] Errors are surfaced to user, not hidden
- [x] Response status language is transport-level ("Backend returned: verified")

---

## Security Boundary Invariants

- [x] No local signature verification (`CryptoKit.isValidSignature` removed)
- [x] No certificate chain validation
- [x] No cryptographic verification of any kind
- [x] Assertions treated as opaque Secure Enclave artifacts
- [x] No security inference in error messages
- [x] No trust assumptions based on decoded structure

---

## Message Language Invariants

- [x] No messages claim assertions "will not verify"
- [x] No warnings infer cryptographic validity
- [x] State consistency checks clearly labeled as such
- [x] Backend responses displayed without security interpretation
- [x] All messages focus on transport/state, not security decisions

---

## Summary

The frontend treats App Attest artifacts as opaque byte blobs and makes no security decisions. All invariants are satisfied.

---

## Related Documentation

- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Authoritative contract
- **`FRONTEND_NON_AUTHORITY_TEST.md`** - Test checklist
- **`GUIDE.md`** - Complete guide
