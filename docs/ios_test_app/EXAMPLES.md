# Frontend Flow Examples

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

Concrete examples showing what the frontend produces, sends, displays, and what it does not decide.

---

## Example 1: Successful Flow

### Flow Sequence

1. **Generate Key**
   - Frontend calls: `DCAppAttestService.generateKey()`
   - Frontend receives: `keyID` (base64 string, 32 bytes decoded)
   - Frontend displays: "Key ID: [base64 string]"
   - Frontend does NOT decide: Whether key is valid or secure

2. **Attest Key**
   - Frontend calls: `DCAppAttestService.attestKey(keyID, clientDataHash:)`
   - Frontend receives: `attestationObject` (CBOR bytes)
   - Frontend displays: "Attestation Blob (base64): [base64 string]"
   - Frontend does NOT decide: Whether attestation is valid or trustworthy

3. **Register Attestation**
   - Frontend sends to backend:
     ```json
     {
       "keyID": "[base64]",
       "attestationObject": "[base64]",
       "challenge_base64": "[base64]"
     }
     ```
   - Backend responds:
     ```json
     {
       "status": "accepted",
       "flowID": "123e4567-e89b-12d3-a456-426614174000"
     }
     ```
   - Frontend displays: "Backend response (status: accepted): [full JSON]"
   - Frontend stores: `flowID` for subsequent requests
   - Frontend does NOT decide: Whether registration should succeed or fail

4. **Request Challenge**
   - Frontend sends to backend:
     ```
     GET /app-attest/challenge?flowID=[uuid]&keyID=[base64]
     ```
   - Backend responds:
     ```json
     {
       "challenge_b64": "[base64]",
       "challenge_id": "456e7890-e89b-12d3-a456-426614174001",
       "expiresAt": "2026-01-20T10:30:00Z"
     }
     ```
   - Frontend displays: Challenge received, expiresAt shown
   - Frontend stores: `challenge_id` for assertion submission
   - Frontend does NOT decide: Whether challenge is valid or expired

5. **Generate Assertion**
   - Frontend builds: Canonical `clientData` JSON with sorted keys
   - Frontend computes: `clientDataHash = SHA256(clientDataBytes)`
   - Frontend calls: `DCAppAttestService.generateAssertion(keyID, clientDataHash:)`
   - Frontend receives: `assertionObject` (CBOR bytes)
   - Frontend displays: "Assertion Blob (base64): [base64 string]"
   - Frontend does NOT decide: Whether assertion will verify or is correct

6. **Send Assertion to Backend**
   - Frontend sends to backend:
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
   - Backend responds:
     ```json
     {
       "status": "verified"
     }
     ```
   - Frontend displays: "Backend response (status: verified): [full JSON]"
   - Frontend does NOT decide: Whether verification should succeed or fail

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
  Details: challenge_id: 456e7890-e89b-12d3-a456-426614174001, expiresAt: 2026-01-20T10:30:00Z

Assertion Submission
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: sent
  Details: verifyRunID: 789e0123-e89b-12d3-a456-426614174002, assertionObject: 245 bytes

Backend Response
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: verified
  Details: Backend returned status: verified
```

### What Frontend Produced

- `keyID`: Base64 string (32 bytes decoded)
- `attestationObject`: CBOR bytes, base64-encoded
- `clientDataBytes`: Canonical JSON with sorted keys
- `clientDataHash`: SHA256(clientDataBytes), 32 bytes
- `assertionObject`: CBOR bytes, base64-encoded

### What Frontend Sent

- Registration: keyID, attestationObject, challenge_base64
- Challenge request: flowID, keyID (query parameters)
- Assertion submission: keyID, flowID, verifyRunID, challenge_id, clientData_base64, assertionObject_base64

### What Frontend Displayed

- Backend responses verbatim (no modification)
- State information (flowID, challenge_id, verifyRunID)
- Timestamps for flow trace
- Error messages describing state issues, not security

### What Frontend Did NOT Decide

- Whether key generation succeeded (API returned keyID)
- Whether attestation is valid (API returned bytes)
- Whether registration should succeed (backend decision)
- Whether challenge is valid (backend decision)
- Whether assertion will verify (backend decision)
- Whether verification should succeed (backend decision)

---

## Example 2: Failed Backend Response

### Flow Sequence

1. **Generate Key** → Success (keyID received)
2. **Attest Key** → Success (attestationObject received)
3. **Register Attestation** → Success (flowID received)
4. **Request Challenge** → Success (challenge received)
5. **Generate Assertion** → Success (assertionObject received)
6. **Send Assertion to Backend** → Backend responds:

```json
{
  "status": "rejected",
  "reason": "ECDSA_VERIFY_FAILED"
}
```

### Frontend Behavior

**What Frontend Does:**

- Displays: "Backend response (status: rejected): [full JSON]"
- Logs: Backend response verbatim to console
- Records: Flow trace entry with status "rejected"
- Maintains: All UI buttons remain enabled
- Preserves: State (flowID, keyID, assertion) remains available

**What Frontend Does NOT Do:**

- Does NOT disable buttons
- Does NOT clear state
- Does NOT prevent generating new assertions
- Does NOT block sending assertions again
- Does NOT interpret "rejected" as a security decision
- Does NOT make any trust or authorization decisions

### Flow Trace Output

```
Backend Response
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: rejected
  Details: Backend returned status: rejected
```

### User Can Still

- Generate new assertion with same keyID
- Send assertion again (if backend allows)
- Continue using the app
- View flow trace
- Copy evidence bundles
- Inspect artifacts

### What Frontend Displayed

- Backend response verbatim: `{"status": "rejected", "reason": "ECDSA_VERIFY_FAILED"}`
- Status clearly attributed to backend: "Backend response (status: rejected)"
- No frontend interpretation or modification

### What Frontend Did NOT Decide

- Whether rejection is correct (backend decision)
- Whether to block further operations (no blocking)
- Whether assertion is invalid (no local verification)
- Whether to clear state (state preserved)
- Whether user should be allowed to continue (no authorization)

---

## Example 3: Repeated Submission

### Flow Sequence

1. **Complete successful flow** (as in Example 1)
2. **Send same assertion again** (without generating new assertion)

### Frontend Behavior

**What Frontend Does:**

- Sends same assertionObject_base64 again
- Sends same clientData_base64 again
- Uses same flowID
- Generates new verifyRunID for this submission
- Displays backend response verbatim

**What Frontend Does NOT Do:**

- Does NOT prevent sending same assertion twice
- Does NOT check if assertion was already used
- Does NOT enforce replay protection
- Does NOT decide whether replay is allowed

### Backend Response (Replay Scenario)

```json
{
  "status": "rejected",
  "reason": "REPLAY_DETECTED"
}
```

### Frontend Behavior

**What Frontend Does:**

- Displays: "Backend response (status: rejected): [full JSON]"
- Records: Flow trace entry with status "rejected"
- Maintains: All functionality available

**What Frontend Does NOT Do:**

- Does NOT prevent replay (backend enforces)
- Does NOT interpret rejection reason
- Does NOT make security decisions about replay

### Flow Trace Output

```
Assertion Submission
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: sent
  Details: verifyRunID: 999e9999-e89b-12d3-a456-426614174999, assertionObject: 245 bytes

Backend Response
  flowID: 123e4567-e89b-12d3-a456-426614174000
  Status: rejected
  Details: Backend returned status: rejected
```

### What Frontend Produced

- Same assertionObject as previous submission
- Same clientData_base64 as previous submission
- New verifyRunID for this submission

### What Frontend Sent

- Same assertionObject_base64
- Same clientData_base64
- Same flowID
- New verifyRunID

### What Frontend Displayed

- Backend response verbatim
- Status attributed to backend
- No interpretation of replay rejection

### What Frontend Did NOT Decide

- Whether replay should be allowed (backend enforces)
- Whether to block repeated submissions (no blocking)
- Whether assertion reuse is valid (backend decides)
- Whether rejection is correct (backend decision)

---

## Summary

### Common Patterns

**What Frontend Always Does:**

- Produces artifacts via App Attest API
- Sends exact bytes to backend unchanged
- Displays backend responses verbatim
- Records flow trace entries
- Maintains state for UI consistency

**What Frontend Never Does:**

- Makes security decisions
- Interprets backend responses
- Blocks or allows operations
- Performs cryptographic verification
- Enforces policy or trust

### Key Observations

1. **Frontend is observational:** Records what happens, does not decide what should happen
2. **Backend is authoritative:** All security decisions made by backend
3. **State is for UI:** State checks ensure UI consistency, not security
4. **Responses are verbatim:** No modification or interpretation of backend responses
5. **No blocking:** Frontend never blocks operations based on backend status

---

## Related Documentation

- **`GUIDE.md`** - Complete guide (includes these examples in Chapter 5)
- **`DATA_FLOW.md`** - Detailed data flow documentation
- **`FRONTEND_NON_AUTHORITY_TEST.md`** - Test checklist for non-authority
- **`WHAT_THIS_TEST_APP_MEASURES.md`** - What can be observed vs cannot prove
