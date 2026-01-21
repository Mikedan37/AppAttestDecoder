# Frontend Flow Examples

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

Concrete examples showing what the frontend produces, sends, displays, and records.

---

## Example 1: Complete Flow

### User Actions

1. Tap "Generate Key"
2. Tap "Attest Key"
3. Tap "Register"
4. Tap "Get Challenge"
5. Tap "Assert Key"
6. Tap "Send to Backend for Verification"

### Data Produced

- keyID: Base64 string (32 bytes decoded)
- attestationObject: CBOR bytes, base64-encoded
- clientDataBytes: Canonical JSON with sorted keys
- clientDataHash: SHA256(clientDataBytes), 32 bytes
- assertionObject: CBOR bytes, base64-encoded

### Data Sent

**Registration:**
```json
{
  "keyID": "[base64]",
  "attestationObject": "[base64]",
  "challenge_base64": "[base64]"
}
```

**Challenge Request:**
```
GET /app-attest/challenge?flowID=[uuid]&keyID=[base64]
```

**Assertion Submission:**
```json
{
  "keyID": "[base64]",
  "flowID": "[uuid]",
  "verifyRunID": "[uuid]",
  "challenge_id": "[uuid]",
  "clientData_base64": "[base64]",
  "assertionObject_base64": "[base64]"
}
```

### Backend Response

```json
{
  "status": "verified"
}
```

### Displayed

- "Backend response (status: verified): [full JSON]"
- Flow trace entry with status "verified"
- State information (flowID, challenge_id, verifyRunID)
- Timestamps for flow trace

### Flow Trace Output

```
Diagnostic Flow Trace (no local verification performed)

Registration
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: completed
  Details: keyID registered, flowID received

Challenge Request
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: sent
  Details: verifyRunID: 789e0123-e89b-12d3-a456-426614174002

Challenge Received
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: completed
  Details: challenge_id: 456e7890-e89b-12d3-a456-426614174001

Assertion Submission
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: sent
  Details: verifyRunID: 789e0123-e89b-12d3-a456-426614174002

Backend Response
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: verified
  Details: Backend returned status: verified
```

---

## Example 2: Backend Rejection

### User Actions

Same as Example 1, through step 6

### Backend Response

```json
{
  "status": "rejected",
  "reason": "ECDSA_VERIFY_FAILED"
}
```

### Displayed

- "Backend response (status: rejected): [full JSON]"
- Flow trace entry with status "rejected"
- All UI buttons remain enabled
- State (flowID, keyID, assertion) remains available

### UI State

- User can generate new assertion with same keyID
- User can send assertion again
- User can continue using the app
- User can view flow trace
- User can copy evidence bundles
- User can inspect artifacts

### Flow Trace Output

```
Backend Response
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: rejected
  Details: Backend returned status: rejected
```

---

## Example 3: Repeated Submission

### User Actions

1. Complete flow as in Example 1
2. Tap "Send to Backend for Verification" again (without generating new assertion)

### Data Sent

- Same assertionObject_base64 as previous submission
- Same clientData_base64 as previous submission
- Same flowID
- New verifyRunID for this submission

### Backend Response

```json
{
  "status": "rejected",
  "reason": "REPLAY_DETECTED"
}
```

### Displayed

- "Backend response (status: rejected): [full JSON]"
- Flow trace entry with status "rejected"
- All functionality remains available

### Flow Trace Output

```
Assertion Submission
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: sent
  Details: verifyRunID: 999e9999-e89b-12d3-a456-426614174999

Backend Response
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: rejected
  Details: Backend returned status: rejected
```

---

## Common Patterns

### What Frontend Always Does

- Produces artifacts via App Attest API
- Forwards exact bytes to backend unchanged
- Displays backend responses verbatim
- Records flow trace entries
- Maintains state for UI consistency

### What Frontend Never Does

- Makes security decisions
- Interprets backend responses
- Blocks or allows operations
- Performs cryptographic verification
- Enforces policy or trust

---

## Related Documentation

- **`GUIDE.md`** - Complete guide (includes these examples in Chapter 5)
- **`DATA_FLOW.md`** - Detailed data flow documentation
- **`FRONTEND_NON_AUTHORITY_TEST.md`** - Test checklist for non-authority
- **`WHAT_THIS_TEST_APP_MEASURES.md`** - What can be observed vs cannot prove
