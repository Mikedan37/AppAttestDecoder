# Frontend App Attest Verification Checklist

## Purpose

This checklist verifies that the frontend implementation is a pure signer and transport, and does not violate cryptographic authority boundaries in the backend-owned clientDataHash model.

## Required Flow Verification

### 1. Request clientDataHash

- [ ] Frontend calls `POST /app-attest/client-data-hash`
- [ ] Request body contains `{ "keyID": "<base64>" }`
- [ ] Response is parsed: `{ "clientDataHash": "<base64>", "expiresAt": "<ISO8601>" }`
- [ ] `clientDataHash` is base64-decoded to bytes
- [ ] Length validation: `clientDataHash.count == 32` (fatal error if violated)
- [ ] `expiresAt` is stored for UI display (optional, for debugging)

### 2. Use hash verbatim

- [ ] Hash is used directly from response (no modification)
- [ ] **DO NOT**: rebuild clientDataJSON
- [ ] **DO NOT**: recompute SHA256
- [ ] **DO NOT**: store the hash beyond this request
- [ ] **DO NOT**: modify bytes in any way

### 3. Generate assertion

- [ ] Calls `DCAppAttestService.generateAssertion(keyID, clientDataHash:)` exactly once
- [ ] No retries that regenerate assertions
- [ ] No previews or "inspection assertions"
- [ ] Assertion is generated immediately after receiving hash
- [ ] No storage of assertion before sending

### 4. Send verification request

- [ ] POST to `/app-attest/verify`
- [ ] Request body contains:
  ```json
  {
    "keyID": "<base64>",
    "assertionObject": "<base64>"
  }
  ```
- [ ] **DO NOT** send `clientDataHash` back
- [ ] Assertion bytes sent byte-for-byte (no decode/re-encode)

## Required Frontend Fingerprint Logging

Immediately after assertion generation and before network send, verify these are logged:

- [ ] `keyID_sha256` (SHA256 of decoded keyID bytes, NOT string)
- [ ] `clientDataHash_hex` (32-byte hex string)
- [ ] `clientDataHash_sha256` (SHA256 of the hash)
- [ ] `clientDataHash_length` (must be 32)
- [ ] `assertionObject_sha256` (SHA256 of raw assertion bytes)
- [ ] `assertionObject_length` (byte count)
- [ ] `authenticatorData_sha256` (extracted from CBOR)
- [ ] `authenticatorData_length` (byte count, typically 37)
- [ ] `signedBytes_sha256` (where `signedBytes = authenticatorData || clientDataHash`)
- [ ] `signedBytes_length` (byte count, typically 69)

**Rules:**
- Hash raw bytes only
- Never hash strings
- These fingerprints must match backend logs exactly

## Forbidden Frontend Behavior

Verify the frontend does NOT:

- [ ] Generate challenges locally
- [ ] Construct clientDataJSON locally
- [ ] Compute SHA256 of client data
- [ ] Store hashes across app launches
- [ ] Retry assertion generation
- [ ] Decode and re-encode assertion CBOR
- [ ] Use COSE Sig_structure
- [ ] Send clientDataHash in verify request

If any of these occur, the implementation is invalid.

## UI Guardrails

- [ ] Verify button disabled while requesting hash (`isRequestingClientDataHash`)
- [ ] Verify button disabled while sending verify (`isSendingToBackend`)
- [ ] Verify button disabled during registration (`isRegistering`)
- [ ] Prevents double-tap from generating multiple assertions
- [ ] No "manual assertion" buttons for inspection

## Code Inspection Checklist

### Request Flow
- [ ] `requestClientDataHashAndVerify()` function exists
- [ ] Makes POST to `/app-attest/client-data-hash`
- [ ] Sends only `{ "keyID": "<base64>" }`
- [ ] Parses `clientDataHash` and `expiresAt` from response
- [ ] Validates hash length == 32 bytes

### Assertion Generation
- [ ] `generateAndSendAssertion()` function exists
- [ ] Calls `generateAssertion()` exactly once
- [ ] Uses hash verbatim (no modification)
- [ ] Logs fingerprints before sending
- [ ] Sends assertion immediately (no storage)

### Verification Request
- [ ] `sendAssertionToBackend()` function exists
- [ ] Sends only `{ "keyID": "<base64>", "assertionObject": "<base64>" }`
- [ ] Does NOT send `clientDataHash`
- [ ] Assertion bytes sent byte-for-byte

### Fingerprint Logging
- [ ] `logVerificationFingerprints()` function exists
- [ ] Logs all required fingerprints
- [ ] Logs lengths for all byte arrays
- [ ] Uses `sha256Hex()` helper (hashes Data, not strings)
- [ ] Extracts `authenticatorData` from CBOR correctly
- [ ] Constructs `signedBytes = authenticatorData || clientDataHash`

## Verification Test Procedure

1. **Generate key and attest**
   - Generate App Attest key
   - Attest key (uses client-side hash for attestation only)
   - Register attestation with backend

2. **Request hash and verify**
   - Tap "Send Assertion" button
   - Verify logs show: `POST /app-attest/client-data-hash`
   - Verify logs show: `clientDataHash` received and validated
   - Verify logs show: `generateAssertion()` called once
   - Verify logs show: Fingerprint block logged
   - Verify logs show: `POST /app-attest/verify` with only `keyID` and `assertionObject`
   - Verify backend returns success

3. **Verify one-time use**
   - Tap "Send Assertion" again without requesting new hash
   - Verify backend rejects with "hash already consumed" or similar
   - Request new hash
   - Verify succeeds again

4. **Fingerprint parity**
   - Compare frontend and backend logs
   - Verify all fingerprints match exactly:
     - `keyID_sha256` matches
     - `clientDataHash_sha256` matches
     - `assertionObject_sha256` matches
     - `signedBytes_sha256` matches

## Success Criteria

All checks must pass:
- [ ] Frontend never generates hashes
- [ ] Frontend never stores hashes across requests
- [ ] Frontend sends only `keyID` and `assertionObject` to verify
- [ ] All fingerprints match backend logs exactly
- [ ] One hash → one assertion → one verification
- [ ] Hash reuse is rejected by backend

## Failure Modes

If verification fails:

1. **Fingerprints match but verify fails**
   - Bug is in: key registration mismatch OR Apple API misuse
   - NOT a frontend authority violation

2. **Fingerprints do not match**
   - Bug is in: your code (transport, encoding, or hash handling)
   - NOT a crypto problem

This distinction is critical for debugging.
