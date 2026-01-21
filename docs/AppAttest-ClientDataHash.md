# App Attest clientDataHash Authority (Canonical Model)

**Status**: Implementation verified. This document describes the canonical backend-owned clientDataHash model.

## Model Summary

The **backend** is the sole authority for `clientDataHash` generation, storage, and lifecycle management. The frontend requests a server-issued hash, uses it exactly once with Apple's `generateAssertion()` API, and forwards the assertion unchanged. The backend verifies the signature using the stored hash. This model enforces server authority over challenge lifecycle and prevents replay attacks through one-time hash consumption.

## Message Sequence

```
Frontend                    Backend
   |                           |
   |-- POST /client-data-hash->|
   |   { keyID }               |
   |                           |-- Generate 32-byte challenge
   |                           |-- Build clientDataJSON
   |                           |-- Hash: SHA256(clientDataJSON)
   |                           |-- Store hash (keyed by keyID)
   |<-- { clientDataHash,      |
   |     expiresAt }           |
   |                           |
   |-- generateAssertion()     |
   |   (uses server hash)      |
   |                           |
   |-- POST /verify ---------->|
   |   { keyID,                |
   |     assertionObject }     |
   |                           |-- Load stored hash
   |                           |-- Extract authenticatorData
   |                           |-- signedBytes = authData || hash
   |                           |-- Verify signature
   |                           |-- Mark hash consumed
   |<-- { status }             |
   |                           |
```

## Authority Boundary Table

| Component | Owns |
|-----------|------|
| Backend | Challenge generation, clientDataJSON construction, clientDataHash computation, storage, replay protection (one-time use), expiry management |
| Frontend | Signs provided clientDataHash verbatim, transports assertion unchanged |
| Apple | Signs `authenticatorData \|\| clientDataHash` |
| Backend | Verifies signature over exact same bytes using stored hash |

**Frontend never invents challenges.**  
**Backend never guesses hashes.**  
**clientDataHash is server-issued, client-used, server-verified.**

## What Bytes Are Signed by Apple

Apple signs exactly:
```
signedBytes = authenticatorData || clientDataHash
```

Where:
- `authenticatorData` is extracted from the assertion CBOR map (key: `"authenticatorData"`)
- `clientDataHash` is the 32-byte SHA256 hash issued by the backend

**Important**: There is no COSE Sig_structure wrapper. Apple signs the raw concatenation directly.

## Backend Responsibilities

### Challenge + Hash Generation

The backend generates challenges, constructs `clientDataJSON`, and hashes it to `clientDataHash`:

1. Generate 32 bytes of cryptographically secure random data (challenge)
2. Construct canonical `clientDataJSON`:
   ```json
   {
     "type": "apple-appattest",
     "challenge": "<base64 challenge>",
     "origin": "<bundle identifier>"
   }
   ```
   - Keys must be in stable order
   - UTF-8 encoded
   - No whitespace variance

3. Compute: `clientDataHash = SHA256(clientDataJSON)`

4. Store in `ClientDataHashStore` keyed by `(keyID, clientDataHash)` with:
   - Creation time
   - Expiry (e.g., 5 minutes)
   - Unused flag

### Endpoint: POST /app-attest/client-data-hash

**Request:**
```json
{
  "keyID": "<base64>"
}
```

**Response:**
```json
{
  "clientDataHash": "<base64>",
  "expiresAt": "<ISO8601>"
}
```

### Verification Endpoint: POST /app-attest/verify

**Request:**
```json
{
  "keyID": "<base64>",
  "assertionObject": "<base64>"
}
```

**Verification Steps:**
1. Look up the latest unconsumed `clientDataHash` for this `keyID`
2. Decode assertion CBOR map (0xa2)
3. Extract:
   - `authenticatorData` (bstr)
   - `signature` (DER)
4. Construct: `signedBytes = authenticatorData || clientDataHash`
5. Verify ECDSA P-256 signature using stored public key
6. On success: Mark `clientDataHash` as consumed
7. On failure: Do NOT consume

### Guards
- Reject if no unconsumed hash exists
- Reject if hash is expired
- Reject if assertion missing fields
- **Never recompute clientDataHash during verify**

### Fingerprint Logging (MANDATORY)

Log this block during verify:
```
BACKEND VERIFICATION FINGERPRINTS
keyID_sha256
clientDataHash_hex
clientDataHash_sha256
authenticatorData_sha256
signedBytes_sha256
assertionObject_sha256
storedPublicKey_sha256
```

## Frontend Responsibilities

### Request Hash, Sign Once, Forward Blindly

The frontend must **never** generate challenges or hashes. It:
1. Requests `clientDataHash` from backend: `POST /app-attest/client-data-hash`
2. Receives `clientDataHash` (base64)
3. Decodes to bytes
4. Calls: `generateAssertion(keyID, clientDataHash)`
5. Immediately sends: `{ "keyID": "<base64>", "assertionObject": "<base64>" }`

### Hard Rules
- One request → one assertion
- Never reuse a hash
- Never store hash across app launches
- No retries that regenerate assertions

### Fingerprint Logging (must match backend)

Before sending assertion:
```
FRONTEND VERIFICATION FINGERPRINTS
keyID_sha256
clientDataHash_hex
clientDataHash_sha256
assertionObject_sha256
signedBytes_sha256
```

### UI Guardrails
- Disable verify button while request in flight
- No "manual assertion" buttons

## One-Time Use and Expiry Rules

### Hash Lifecycle
- **TTL**: Hash expires after configured duration (e.g., 5 minutes)
- **Consumed on success**: Hash is marked consumed after successful verification
- **Reject on reuse**: Second verify attempt with same hash returns "hash already consumed"
- **Reject on expiry**: Verify attempt after TTL returns "hash expired"

### Storage Requirements
- Hash stored keyed by `(keyID, clientDataHash)` with:
  - Creation timestamp
  - Expiry timestamp
  - Consumed flag (boolean)
- Thread-safe storage (concurrent access protection)

## Fingerprint Parity Checklist

The frontend logs these fingerprints **after** assertion generation and **before** network send. The backend must log the **exact same** fingerprints for byte-for-byte comparison:

| Fingerprint | Frontend Logs | Backend Logs | Must Match |
|-------------|---------------|--------------|------------|
| `keyID_sha256` | SHA256 of decoded keyID bytes | SHA256 of decoded keyID bytes | Yes |
| `clientDataHash_hex` | 32-byte hex string | 32-byte hex string (from stored hash) | Yes |
| `clientDataHash_sha256` | SHA256 of hash | SHA256 of stored hash | Yes |
| `clientDataHash_length` | 32 | 32 | Yes |
| `assertionObject_sha256` | SHA256 of raw assertion bytes | SHA256 of received assertion bytes | Yes |
| `assertionObject_length` | Byte count | Byte count | Yes |
| `authenticatorData_sha256` | SHA256 of extracted authData | SHA256 of extracted authData | Yes |
| `authenticatorData_length` | Byte count (typically 37) | Byte count | Yes |
| `signedBytes_sha256` | SHA256 of `authData \|\| hash` | SHA256 of `authData \|\| hash` | Yes |
| `signedBytes_length` | Byte count (typically 69) | Byte count | Yes |
| `storedPublicKey_sha256` | N/A (frontend doesn't have) | SHA256 of stored public key | N/A |

**Critical**: If any fingerprint differs between frontend and backend logs, byte-for-byte integrity is broken.

## Enforcement

### Backend Guards
- `clientDataHash.length == 32` (reject request if violated)
- `clientDataHash` is present in store (reject if missing)
- Assertion CBOR contains `authenticatorData` and `signature` (reject if missing)
- Fatal assertion if any code attempts to recompute `clientDataHash`

### Frontend Guards
- `clientDataHash.length == 32` (fatal error if violated)
- Assertion CBOR starts with `0xa2` (warning if not)
- One request → one assertion (button disabled during in-flight request)

## Failure Triage

When verification fails, compare frontend and backend fingerprints to identify the root cause:

### If `assertionObject_sha256` mismatches
- **Root cause**: Transport/encoding bug
- **Check**: Base64 encoding/decoding, network corruption, JSON serialization
- **Fix**: Ensure assertion bytes are sent byte-for-byte (no decode/re-encode)

### If `clientDataHash_sha256` mismatches
- **Root cause**: Authority violation (frontend generated hash or backend recomputed)
- **Check**: 
  - Frontend requested hash from backend (did not generate locally)
  - Backend used stored hash (did not recompute during verify)
- **Fix**: Ensure backend is sole authority for hash generation

### If `signedBytes_sha256` mismatches
- **Root cause**: Backend concatenation/parsing bug
- **Check**:
  - Backend extracts `authenticatorData` correctly from CBOR map
  - Backend concatenates `authenticatorData || clientDataHash` (not reversed)
  - No extra bytes, no missing bytes
- **Fix**: Verify backend CBOR parsing and byte concatenation logic

### If all fingerprints match but verify fails
- **Root cause**: Public key extraction/storage bug OR signature API misuse
- **Check**:
  - Public key extracted correctly from attestation certificate
  - Public key stored correctly (X9.63 format, 65 bytes: 0x04 || X || Y)
  - Signature verification API matches what Apple uses (ECDSA P-256, message-based not digest-based)
  - No double-hashing in verification library
- **Fix**: Verify public key extraction, storage, and signature verification API usage

## Cryptographic Invariant

Apple signs exactly:
```
signedBytes = authenticatorData || clientDataHash
```

Where:
- `authenticatorData` is extracted from assertion CBOR map (key: `"authenticatorData"`, bstr)
- `clientDataHash` is the 32-byte SHA256 hash issued by backend
- `||` is byte concatenation (no separator, no padding)
- Signature is ECDSA P-256 over SHA256(signedBytes)

**Explicitly forbidden:**
- COSE Sig_structure wrapper (Apple doesn't use it)
- Double-hashing signedBytes (verification library hashes internally)
- Reversing concatenation order (`clientDataHash || authenticatorData` is wrong)

## Anti-Patterns (What NOT to Do)

### Frontend
- DO NOT: Generate challenges locally
- DO NOT: Build clientDataJSON locally
- DO NOT: Hash JSON to create clientDataHash
- DO NOT: Store clientDataHash across app launches
- DO NOT: Reuse clientDataHash for multiple assertions
- DO NOT: Decode assertion CBOR for verification purposes
- DO NOT: Retry loops that generate multiple assertions per hash
- DO NOT: Send clientDataHash in verify request (backend uses stored one)

### Backend
- DO NOT: Recompute clientDataHash during verify (use stored hash)
- DO NOT: Accept clientDataHash from verify request (frontend doesn't send it)
- DO NOT: Reconstruct clientDataJSON at verify time based on a challenge
- DO NOT: Hash clientDataHash again before verification
- DO NOT: Derive clientDataHash from other inputs
- DO NOT: Construct COSE Sig_structure (Apple doesn't use it)
- DO NOT: Allow hash reuse (one hash → one assertion → one verification)
- DO NOT: Hash signedBytes twice (verification library hashes internally)

## Example Log Output

### Frontend
```
[ContentView] CANONICAL MODEL: Requesting clientDataHash from backend...
[ContentView] ========================================
[ContentView] FRONTEND VERIFICATION FINGERPRINTS
[ContentView] (AFTER generation, BEFORE send)
[ContentView] ========================================
[ContentView]   keyID_sha256: 143073b6e7e2ab15e081ca2977eb4d6130c3ecda9c06d474b681ec8aeace4fb3
[ContentView]   clientDataHash_hex: 7de308ee5f3fe288246203dcb058983890eff878f7a24bab403f20bdae260dc0
[ContentView]   clientDataHash_sha256: a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
[ContentView]   clientDataHash_length: 32
[ContentView]   assertionObject_sha256: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
[ContentView]   assertionObject_length: 141
[ContentView]   authenticatorData_sha256: f6e5d4c3b2a1987654321098765432109876543210fedcba9876543210fedcba98
[ContentView]   authenticatorData_length: 37
[ContentView]   signedBytes_sha256: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
[ContentView]   signedBytes_length: 69
[ContentView] ========================================
[ContentView] WARNING: Backend MUST log these EXACT same fingerprints
[ContentView] Sending assertion to backend (POST /app-attest/verify):
[ContentView]   CANONICAL MODEL: Backend uses stored clientDataHash from /client-data-hash request
```

### Backend
```
[Backend] ========================================
[Backend] BACKEND VERIFICATION FINGERPRINTS
[Backend] ========================================
[Backend]   keyID_sha256: 143073b6e7e2ab15e081ca2977eb4d6130c3ecda9c06d474b681ec8aeace4fb3
[Backend]   clientDataHash_hex: 7de308ee5f3fe288246203dcb058983890eff878f7a24bab403f20bdae260dc0
[Backend]   clientDataHash_sha256: a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
[Backend]   clientDataHash_length: 32
[Backend]   assertionObject_sha256: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
[Backend]   assertionObject_length: 141
[Backend]   authenticatorData_sha256: f6e5d4c3b2a1987654321098765432109876543210fedcba9876543210fedcba98
[Backend]   authenticatorData_length: 37
[Backend]   signedBytes_sha256: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
[Backend]   signedBytes_length: 69
[Backend]   storedPublicKey_sha256: fedcba654321098765432109876543210987654321098765432109876543210
[Backend] ========================================
[Backend] All fingerprints match frontend - byte-for-byte integrity confirmed
[Backend] CONSUMED clientDataHash (keyID_sha256_prefix: 143073b6, hash_sha256_prefix: a1b2c3d4)
```

## What "Success" Looks Like

1. Frontend requests `clientDataHash` from backend
2. Frontend logs exact fingerprints
3. Backend logs match frontend fingerprints 1:1
4. No ambiguity about who owns `clientDataHash`
5. Verification succeeds with zero COSE structures
6. One hash → one assertion → one verification (hash consumed after use)

## Acceptance Criteria

- Backend is the only place `clientDataHash` is created
- Frontend cannot influence challenge content
- One hash → one assertion → one verification
- Frontend never computes hashes
- Hash used in assertion == hash issued by backend
- Assertion bytes are transported verbatim

## Summary

The **backend owns `clientDataHash`**. The frontend requests it, uses it once, and forwards the assertion unchanged. The backend verifies signatures using the stored hash. This is not a suggestion—it's a cryptographic invariant that prevents silent verification failures and enforces server authority over challenge lifecycle.

**Key invariants:**
- Backend is the only place `clientDataHash` is created
- Frontend cannot influence challenge content
- One hash → one assertion → one verification (hash consumed after use)
- Frontend never computes hashes
- Hash used in assertion == hash issued by backend
- Assertion bytes are transported verbatim

Breaking this boundary causes signature verification to fail because Apple signs `authenticatorData || clientDataHash`, and if the backend verifies different bytes than what Apple signed, the signature will never match.

## Verification Procedure

To verify the implementation works end-to-end:

1. **iOS**: Generate keyID, attestKey, register
2. **iOS**: Tap Verify:
   - App calls `/app-attest/client-data-hash`
   - App generates assertion using received hash
   - App sends `/app-attest/verify` with only `keyID + assertionObject`
3. **Backend**: Verify uses stored hash and consumes it

**Acceptance criteria (must be logged):**
- Frontend and backend show SAME:
  - `keyID_sha256`
  - `assertionObject_sha256`
  - `clientDataHash_hex` and `clientDataHash_sha256` (backend stored vs frontend received)
  - `signedBytes_sha256`
- Backend returns status "accepted" or "verified"
- Repeat verify without requesting a new hash returns "rejected" with reason "hash already consumed"
- Requesting a new hash then verifying again succeeds
