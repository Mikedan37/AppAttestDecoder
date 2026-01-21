# What This Test App Can Observe

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

This document describes what the test app can observe and what it cannot prove.

---

## What This Test App Can Observe

### Artifact Generation

- **Key generation:** Observes keyID returned by App Attest API
- **Attestation generation:** Observes attestationObject bytes returned by App Attest API
- **Assertion generation:** Observes assertionObject bytes returned by App Attest API
- **Timing:** Records timestamps for each operation

### Data Flow

- **Request construction:** Observes exact bytes sent to backend
- **Response reception:** Observes exact bytes received from backend
- **State transitions:** Observes flowID, challenge_id, verifyRunID changes
- **Network behavior:** Observes HTTP status codes, response times, errors

### Byte-Level Evidence

- **Raw bytes:** Extracts authenticatorData, signature, certificates from artifacts
- **Hashes:** Computes SHA256 hashes for log correlation
- **Encoding:** Observes base64 encoding/decoding behavior
- **Structure:** Decodes CBOR, ASN.1 for logging purposes

### Backend Communication

- **Request payloads:** Observes exact JSON sent to backend
- **Response payloads:** Observes exact JSON received from backend
- **Status codes:** Observes HTTP status codes
- **Error messages:** Observes backend error messages verbatim

### Flow Trace

- **Complete flow:** Records registration → challenge → assertion submission
- **Timestamps:** Records when each step occurred
- **State consistency:** Observes flowID continuity across steps
- **Backend responses:** Records backend status (verified/rejected) without interpretation

---

## What This Test App Cannot Prove

### Cryptographic Validity

- **Cannot prove:** Signatures are valid
- **Cannot prove:** Certificate chains are valid
- **Cannot prove:** Nonces are correct
- **Cannot prove:** Public keys match private keys

**Reason:** Frontend does not perform cryptographic verification. All verification happens on the backend.

### Security Properties

- **Cannot prove:** Artifacts are authentic
- **Cannot prove:** Keys are secure
- **Cannot prove:** Replay attacks are prevented
- **Cannot prove:** Policy is enforced

**Reason:** Security properties are enforced by the backend, not the frontend.

### Trust Decisions

- **Cannot prove:** A key should be trusted
- **Cannot prove:** An assertion should be accepted
- **Cannot prove:** A user should be authorized
- **Cannot prove:** An operation should be allowed

**Reason:** Trust decisions are made by the backend based on policy, not by the frontend.

### Correctness Guarantees

- **Cannot prove:** Implementation is correct
- **Cannot prove:** Protocol is followed correctly
- **Cannot prove:** No bugs exist
- **Cannot prove:** Production readiness

**Reason:** This is a diagnostic test app, not a production client. It is for observation and learning only.

---

## Measurement vs Security

### This App Measures

- **What data is generated:** Artifact bytes, hashes, structure
- **What data is sent:** Request payloads, encoding
- **What data is received:** Response payloads, status codes
- **When operations occur:** Timestamps, flow sequence
- **How state changes:** flowID, challenge_id, verifyRunID transitions

### This App Does Not Measure

- **Whether data is valid:** Cryptographic validity is backend's responsibility
- **Whether operations are secure:** Security is backend's responsibility
- **Whether decisions are correct:** Decision correctness is backend's responsibility
- **Whether policy is enforced:** Policy enforcement is backend's responsibility

---

## Use Cases

### Appropriate Uses

- **Learning:** Understanding App Attest data flow
- **Debugging:** Identifying byte-level mismatches
- **Development:** Testing backend integration
- **Forensics:** Analyzing artifact structure

### Inappropriate Uses

- **Security decisions:** Do not use to make trust decisions
- **Production validation:** Do not use to validate production systems
- **Authorization:** Do not use to authorize users or operations
- **Compliance:** Do not use to prove compliance or security

---

## Related Documentation

- **`ROLE_OF_FRONTEND.md`** - What the frontend does and never does
- **`FRONTEND_NON_AUTHORITY_TEST.md`** - Test checklist for non-authority
- **`DATA_FLOW.md`** - What data flows through the app
- **`../VERIFICATION_GUIDE.md`** - Backend verification responsibilities
