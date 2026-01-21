# Data Flow

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

This document describes what data is produced and sent by the frontend. The frontend does not validate the meaning of this data.

---

## Flow Overview

The test app follows this sequence:

1. **Generate Key** → `keyID` (base64)
2. **Attest Key** → `attestationObject` (CBOR, base64)
3. **Register** → Sends `keyID`, `attestationObject`, `challenge_base64` → Receives `flowID`
4. **Assert Key** → Requests challenge → Receives `challenge_b64`, `challenge_id` → Generates `assertionObject` (CBOR, base64)
5. **Send to Backend** → Sends `keyID`, `flowID`, `verifyRunID`, `challenge_id`, `clientData_base64`, `assertionObject_base64` → Receives backend response

---

## Data Produced

### Key Generation

- **`keyID`**: Base64-encoded 32-byte identifier returned by `DCAppAttestService.generateKey()`
- Stored in app state for subsequent operations

### Attestation

- **`attestationObject`**: CBOR-encoded attestation returned by `DCAppAttestService.attestKey(keyID, clientDataHash:)`
- Contains:
  - `authenticatorData` (raw bytes)
  - `attStmt` (attestation statement with certificate chain)
- Base64-encoded for transport

### Challenge Request

- **Request**: `GET /app-attest/challenge?flowID=<uuid>&keyID=<base64>`
- **Response**: `{ "challenge_b64": "...", "challenge_id": "...", "expiresAt": "..." }`
- Frontend stores `challenge_id` and `challenge_b64` for assertion generation

### Client Data Construction

- **`clientDataBytes`**: Canonical JSON with sorted keys:
  ```json
  {
    "challenge_b64": "...",
    "challenge_id": "...",
    "flow_id": "...",
    "key_id_b64": "...",
    "bundle_id": "...",
    "timestamp_iso8601": "..."
  }
  ```
- **`clientDataHash`**: `SHA256(clientDataBytes)` (32 bytes)
- Used as input to `generateAssertion(keyID, clientDataHash:)`

### Assertion

- **`assertionObject`**: CBOR-encoded assertion returned by `DCAppAttestService.generateAssertion(keyID, clientDataHash:)`
- Contains:
  - `authenticatorData` (raw bytes)
  - `signature` (DER-encoded ECDSA signature)
- Base64-encoded for transport

---

## Data Sent to Backend

### Register Request

**POST** `/app-attest/register`

```json
{
  "keyID": "<base64>",
  "attestationObject": "<base64>",
  "challenge_base64": "<base64>"
}
```

### Verify Request

**POST** `/app-attest/verify`

```json
{
  "keyID": "<base64>",
  "flowID": "<uuid>",
  "verifyRunID": "<uuid>",
  "challenge_id": "<uuid>",
  "clientData_base64": "<base64>",
  "assertionObject_base64": "<base64>"
}
```

---

## Important Notes

### Frontend Does Not Validate Meaning

The frontend:
- Does not verify cryptographic signatures
- Does not validate certificate chains
- Does not check certificate expiration
- Does not enforce policy (bundle ID, environment)
- Does not prevent replay attacks
- Does not interpret validity

### Backend Responsibilities

The backend:
- Verifies cryptographic signatures
- Validates certificate chains
- Checks certificate expiration and revocation
- Enforces policy (bundle ID, environment)
- Prevents replay attacks
- Makes all security decisions

### Data Integrity

The frontend maintains:
- Raw bytes are sent unchanged (no modification of App Attest API output)
- Base64 encoding is standard (not URL-safe)
- JSON keys are sorted (canonical format)
- State consistency (flowID matches registration, keyID matches attestation)

---

## Related Documentation

- **`GUIDE.md`** - Complete guide to understanding and using the test app
- **`../APP_ATTEST_E2E_CONTRACT.md`** - End-to-end protocol contract
- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Detailed frontend contract
