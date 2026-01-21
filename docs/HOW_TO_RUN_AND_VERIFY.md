# How to Run and Verify the Canonical App Attest Flow

## Required Flow Sequence

The UI enforces this exact sequence. Users cannot skip steps:

1. **Generate Key** → Creates App Attest keyID
2. **Attest Key** → Attests the key (uses client-side hash for attestation only)
3. **Register Attestation** → Backend extracts and stores public key
4. **Verify Assertion** → Requests hash from backend, generates assertion, sends verify

## Step-by-Step Procedure

### Step 1: Generate Key
- Tap "Generate Key" button
- **Expected**: keyID displayed in UI
- **Logs**: `[ContentView] GENERATE KEY - keyID: <base64>`

### Step 2: Attest Key
- Tap "Attest Key" button
- **Expected**: Attestation blob displayed
- **Logs**: 
  - `[ContentView] ATTEST - keyID_sha256: <hash>`
  - `[ContentView] ATTEST - clientDataHash_hex: <hex>`
  - `AttestKey success: <bytes> bytes`

**Note**: This uses a client-side hash for attestation only. Verification uses backend-issued hash.

### Step 3: Register Attestation
- Tap "Register Attestation" button
- **Expected**: Button changes to "Registered ✓" and becomes disabled
- **Logs**:
  - `[ContentView] REGISTER - keyID: <base64>`
  - `[ContentView] REGISTER response status: 200`
  - `[ContentView] REGISTER succeeded - assertion verification now ENABLED`

**Critical**: Verification button is disabled until registration succeeds.

### Step 4: Verify Assertion
- Tap "Verify Assertion" button
- **Expected flow**:
  1. Button shows "Requesting hash..." → `POST /app-attest/client-data-hash`
  2. Button shows "Verifying..." → `generateAssertion()` → `POST /app-attest/verify`
  3. Backend response displayed

**Logs** (in order):

```
[ContentView] CANONICAL MODEL: Requesting clientDataHash from backend...
[ContentView] ========================================
[ContentView] FRONTEND VERIFICATION FINGERPRINTS
[ContentView] (AFTER generation, BEFORE send)
[ContentView] ========================================
[ContentView]   keyID_sha256: <hash>
[ContentView]   clientDataHash_hex: <hex>
[ContentView]   clientDataHash_sha256: <hash>
[ContentView]   clientDataHash_length: 32
[ContentView]   assertionObject_sha256: <hash>
[ContentView]   assertionObject_length: <bytes>
[ContentView]   authenticatorData_sha256: <hash>
[ContentView]   authenticatorData_length: <bytes>
[ContentView]   signedBytes_sha256: <hash>
[ContentView]   signedBytes_length: <bytes>
[ContentView] ========================================
[ContentView] WARNING: Backend MUST log these EXACT same fingerprints
[ContentView] Sending assertion to backend (POST /app-attest/verify):
[ContentView]   CANONICAL MODEL: Backend uses stored clientDataHash from /client-data-hash request
[ContentView] VERIFY response status: 200
[ContentView] VERIFY response body: {"status":"verified"}
[ContentView] VERIFY succeeded - assertion verified
```

## Expected Log Lines (Happy Path)

### Frontend Logs
1. `CANONICAL MODEL: Requesting clientDataHash from backend...`
2. `FRONTEND VERIFICATION FINGERPRINTS` block with all required fields
3. `Sending assertion to backend (POST /app-attest/verify)`
4. `VERIFY response status: 200`
5. `VERIFY succeeded - assertion verified`

### Backend Logs (must match)
1. `BACKEND VERIFICATION FINGERPRINTS` block
2. All fingerprints match frontend exactly:
   - `keyID_sha256` matches
   - `clientDataHash_sha256` matches
   - `assertionObject_sha256` matches
   - `signedBytes_sha256` matches
3. `CONSUMED clientDataHash` (after successful verification)

## Negative Tests

### Test A: Verify without requesting hash
**Action**: Modify code to skip `/client-data-hash` request, go directly to verify  
**Expected**: Backend rejects with `missing_clientDataHash`

### Test B: Expired hash
**Action**: Request hash, wait past TTL (5 minutes), then verify  
**Expected**: Backend rejects with `expired_clientDataHash`

### Test C: Reused hash
**Action**: 
1. Request hash → verify successfully
2. Tap "Verify Assertion" again immediately (without requesting new hash)
**Expected**: Backend rejects with `reused_clientDataHash` or `hash already consumed`

### Test D: Double-tap protection
**Action**: Rapidly tap "Verify Assertion" button twice  
**Expected**: Only ONE request fires, button disabled during in-flight request

## Fingerprint Parity Verification

After a successful verify, compare frontend and backend logs:

| Fingerprint | Frontend Value | Backend Value | Match? |
|-------------|----------------|---------------|--------|
| `keyID_sha256` | `<hash>` | `<hash>` | ✓ |
| `clientDataHash_sha256` | `<hash>` | `<hash>` | ✓ |
| `assertionObject_sha256` | `<hash>` | `<hash>` | ✓ |
| `signedBytes_sha256` | `<hash>` | `<hash>` | ✓ |

**If all match and verify fails**: Bug is in key registration or signature API usage  
**If any mismatch**: Bug is in transport/encoding/hash handling

## UI State Verification

### Button States
- **"Register Attestation"**:
  - Enabled when: attestation exists, not already registered, not in-flight
  - Disabled when: `isRegistering || isSendingToBackend || isRequestingClientDataHash || registrationSucceeded`
  - Shows: "Registering..." during request, "Registered ✓" after success

- **"Verify Assertion"**:
  - Enabled when: `registrationSucceeded && keyID exists && attestation exists && not in-flight`
  - Disabled when: `isSendingToBackend || isRegistering || isRequestingClientDataHash || !registrationSucceeded`
  - Shows: "Requesting hash..." → "Verifying..." → "Verify Assertion"
  - Hidden when: `!registrationSucceeded` (shows helper text instead)

### Flow Enforcement
- Cannot verify without registration (button hidden, helper text shown)
- Cannot register twice (button disabled after success)
- Cannot double-tap verify (button disabled during request)
- Clear visual feedback at each step

## Success Criteria

All of these must be true:
- [ ] Frontend requests hash from backend
- [ ] Frontend generates exactly one assertion per verify
- [ ] Frontend sends only `keyID` and `assertionObject` (no `clientDataHash`)
- [ ] All fingerprints match between frontend and backend logs
- [ ] Backend returns `{"status":"verified"}` or `{"status":"accepted"}`
- [ ] Second verify without new hash is rejected
- [ ] UI clearly shows current step and prevents skipping

## Troubleshooting

**If "Verify Assertion" button is disabled:**
- Check: Is registration successful? (`registrationSucceeded == true`)
- Check: Does keyID exist?
- Check: Does attestation exist?
- Check: Is a request already in flight?

**If verification fails:**
1. Compare fingerprints between frontend and backend logs
2. If fingerprints match → check key registration and signature API
3. If fingerprints differ → check transport/encoding

**If "Requesting hash..." never completes:**
- Check: Backend URL is correct
- Check: Backend `/app-attest/client-data-hash` endpoint exists
- Check: Network permissions (local network, ATS settings)
