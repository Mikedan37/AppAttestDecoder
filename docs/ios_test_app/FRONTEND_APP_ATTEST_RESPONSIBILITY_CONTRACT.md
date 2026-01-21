# Frontend App Attest Responsibility Contract

**Version:** 1.0  
**Last Updated:** 2026-01-20  
**Status:** Mandatory  
**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

> **⚠️ This document applies to the diagnostic test app only.**  
> Production frontend implementations should follow similar principles but must be validated independently.

## Purpose

This document defines the **non-negotiable** responsibilities and boundaries for the iOS test app frontend in an App Attest implementation. The frontend is a **transport and evidence generator only**—it does not make security decisions, interpret validity, or assume trust.

**This is the authoritative contract.** Other documents reference this; nothing overrides it.

## Core Principle

**App Attest artifacts are opaque byte blobs.** The frontend's job is to:
1. Generate artifacts via Apple APIs
2. Transport them unchanged to the backend
3. Log evidence for debugging
4. Display backend responses

The frontend **never** interprets cryptographic validity, makes trust decisions, or infers security state.

---

## What the Frontend IS Allowed To Do

### ✅ Transport Operations
- Generate keys via `DCAppAttestService.generateKey()`
- Generate attestations via `DCAppAttestService.attestKey(keyID, clientDataHash:)`
- Generate assertions via `DCAppAttestService.generateAssertion(keyID, clientDataHash:)`
- Send raw attestation/assertion bytes to backend unchanged
- Handle network errors (connection failures, timeouts, HTTP errors)
- Display backend responses (success, rejection, errors)

### ✅ Evidence Generation (Observational Only)
- Decode artifacts for **logging and debugging only** (CBOR, ASN.1 parsing)
- Extract raw bytes (authenticatorData, signature, certificates) for forensic logging
- Compute hashes (SHA256) for log correlation and debugging
- Store evidence temporarily for UI display (Diff View, inspection)
- Export evidence bundles for independent verification (OpenSSL, backend debugging)

### ✅ State Management (Continuity Only)
- Track `keyID` for UI state (which key is active)
- Track `flowID` from backend REGISTER response
- Track `verifyRunID` for log correlation
- Store `challenge_id` for verify request construction
- Maintain UI state (pending assertions, registration status)

### ✅ Input Validation (Format Only)
- Validate base64 encoding (can decode)
- Validate UUID format (challenge_id, flowID)
- Validate byte lengths (clientDataHash is 32 bytes, challenge decodes to 32 bytes)
- Validate JSON structure (can parse responses)
- Validate URL encoding (query parameters properly encoded)

### ✅ Canonical Data Construction
- Build canonical `clientData` JSON with sorted keys
- Compute `SHA256(clientDataBytes)` for `clientDataHash`
- Ensure byte-level consistency (same `clientDataBytes` hashed and sent)

---

## What the Frontend MUST Never Do

### ❌ Security Decisions
- **Never** infer that an assertion "will not verify" or "will verify"
- **Never** block assertion generation based on security assumptions
- **Never** make trust decisions about artifacts
- **Never** reject artifacts based on cryptographic interpretation
- **Never** assume validity based on decoded structure

### ❌ Validity Interpretation
- **Never** claim artifacts are "valid" or "invalid"
- **Never** infer verification success/failure beyond HTTP status codes
- **Never** interpret certificate chain validity
- **Never** interpret signature validity
- **Never** make policy decisions (bundle ID matching, environment checks)

### ❌ Trust Assumptions
- **Never** assume backend acceptance means cryptographic validity
- **Never** cache trust state ("this key is trusted")
- **Never** reuse assertions across different challenges
- **Never** assume continuity implies security

### ❌ Cryptographic Verification
- **Never** verify ECDSA signatures locally (`CryptoKit.isValidSignature`)
- **Never** validate certificate chains
- **Never** check certificate expiration or revocation
- **Never** verify RP ID hashes or nonces
- **Never** perform any cryptographic validation

### ❌ Assertion Reuse
- **Never** reuse assertions for different challenges
- **Never** cache assertions for "efficiency"
- **Never** regenerate assertions from stored state
- **Never** send the same assertion twice (except retries of the same request)

---

## Exact Data Sent to Backend

### REGISTER Request
```json
{
  "keyID": "<base64 keyID>",
  "attestationObject": "<base64 attestation object>",
  "challenge_base64": "<base64 challenge bytes>",
  "clientDataHash_base64": "<base64 32-byte clientDataHash>"
}
```

**Source of truth:**
- `keyID`: From `DCAppAttestService.generateKey()`
- `attestationObject`: Raw bytes from `DCAppAttestService.attestKey()`
- `challenge_base64`: From `ClientDataContext.challenge` (created during attestation)
- `clientDataHash_base64`: From `ClientDataContext.clientDataHash` (SHA256 of clientData JSON)

### VERIFY Request
```json
{
  "keyID": "<base64 keyID>",
  "flowID": "<uuid from REGISTER>",
  "verifyRunID": "<uuid>",
  "challenge_id": "<uuid from challenge response>",
  "clientData_base64": "<base64 canonical clientData JSON>",
  "assertionObject_base64": "<base64 assertion object>"
}
```

**Source of truth:**
- `keyID`: From `DCAppAttestService.generateKey()`
- `flowID`: From REGISTER response (`status: "accepted"`)
- `verifyRunID`: Frontend-generated UUID for log correlation
- `challenge_id`: From challenge response (`GET /app-attest/challenge`)
- `clientData_base64`: Canonical JSON built from challenge response (sorted keys)
- `assertionObject_base64`: Raw bytes from `DCAppAttestService.generateAssertion()`

### CHALLENGE Request
```
GET /app-attest/challenge?flowID=<uuid>&keyID=<base64>
```

**Response:**
```json
{
  "challenge_b64": "<base64>",
  "challenge_id": "<uuid>",
  "expiresAt": "<ISO8601>"
}
```

---

## Canonical Request Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. GENERATE KEY                                                  │
│    DCAppAttestService.generateKey()                              │
│    → keyID (base64)                                              │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. ATTEST KEY                                                    │
│    Create ClientDataContext:                                     │
│      - challenge (random bytes, base64)                         │
│      - clientData JSON (sorted keys)                             │
│      - clientDataHash = SHA256(clientDataBytes)                  │
│    DCAppAttestService.attestKey(keyID, clientDataHash)          │
│    → attestationObject (raw bytes)                               │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. REGISTER                                                      │
│    POST /app-attest/register                                    │
│    Body: {                                                       │
│      keyID, attestationObject (base64),                          │
│      challenge_base64, clientDataHash_base64                    │
│    }                                                             │
│    Response: { status: "accepted", flowID: "<uuid>" }           │
│    → Store flowID                                                │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. REQUEST CHALLENGE                                             │
│    GET /app-attest/challenge?flowID=<uuid>&keyID=<base64>       │
│    Response: {                                                   │
│      challenge_b64, challenge_id, expiresAt                      │
│    }                                                             │
│    → Store challenge_id                                          │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. BUILD CLIENTDATA                                              │
│    Build ClientDataPayload (sorted keys):                        │
│      - challenge (from challenge_b64)                            │
│      - challenge_id                                              │
│      - flow_id (from REGISTER)                                   │
│      - key_id (base64 keyID)                                     │
│      - bundle_id                                                 │
│      - timestamp (ISO8601)                                       │
│    Encode with JSONEncoder(sortedKeys)                           │
│    → clientDataBytes                                             │
│    Compute: clientDataHash = SHA256(clientDataBytes)             │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. GENERATE ASSERTION                                            │
│    DCAppAttestService.generateAssertion(keyID, clientDataHash)  │
│    → assertionObject (raw bytes)                                 │
│    Store: CryptoEvidence (observational only)                   │
└─────────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. VERIFY                                                        │
│    POST /app-attest/verify                                       │
│    Body: {                                                       │
│      keyID, flowID, verifyRunID,                                 │
│      challenge_id, clientData_base64,                           │
│      assertionObject_base64                                     │
│    }                                                             │
│    Response: { status: "verified" | "rejected", ... }           │
│    → Display response (no interpretation)                        │
└─────────────────────────────────────────────────────────────────┘
```

**Key invariants:**
- Each step uses raw bytes from previous step (no re-encoding)
- `clientDataBytes` is built once, hashed once, sent once
- `assertionObject` is generated once, sent unchanged
- All state (flowID, challenge_id) comes from backend responses

---

## Frontend Invariants Checklist

### ✅ Transport Invariants
- [ ] Attestation/assertion bytes are never modified after generation
- [ ] Base64 encoding happens only at network boundary
- [ ] No re-encoding, re-hashing, or transformation of artifacts
- [ ] Network errors are handled without inferring security state

### ✅ State Invariants
- [ ] `flowID` comes only from REGISTER response
- [ ] `challenge_id` comes only from challenge response
- [ ] `keyID` comes only from `DCAppAttestService`
- [ ] No state is assumed or inferred

### ✅ Evidence Invariants
- [ ] Decoding is observational only (for logging)
- [ ] Evidence is never used for security decisions
- [ ] Hashes are computed for correlation, not validation
- [ ] Raw bytes are preserved alongside decoded values

### ✅ Request Construction Invariants
- [ ] `clientDataBytes` is built once with sorted keys
- [ ] `clientDataHash` is computed once from `clientDataBytes`
- [ ] Same `clientDataBytes` is hashed and sent (byte-for-byte)
- [ ] `assertionObject` is sent unchanged from `generateAssertion()`

### ✅ Response Handling Invariants
- [ ] Backend responses are displayed, not interpreted
- [ ] HTTP status codes are handled, not inferred
- [ ] No trust decisions based on response content
- [ ] Errors are surfaced to user, not hidden

---

## Violations Found in Current Implementation

### 🔴 Security Decision Violations

**File:** `ContentView.swift`

1. **Line 986:** `"keyID mismatch – assertion will not verify"`
   - **Issue:** Infers security state (assertion won't verify)
   - **Fix:** Change to: `"keyID mismatch – assertion generation blocked for state consistency"`
   - **Rationale:** Block for state consistency, not security

2. **Line 1010:** `"Bundle ID mismatch - assertion will NOT verify!"`
   - **Issue:** Infers verification failure
   - **Fix:** Change to: `"Bundle ID mismatch - may cause backend rejection"`
   - **Rationale:** Warn about potential backend rejection, don't infer crypto validity

3. **Line 209:** `"App Attest signatures will NOT verify if backend uses different bundle ID"`
   - **Issue:** Infers cryptographic validity
   - **Fix:** Change to: `"Bundle ID mismatch - backend may reject based on policy"`
   - **Rationale:** Policy concern, not cryptographic validity

### 🟡 State Consistency Checks (Acceptable, but wording needs fix)

**File:** `ContentView.swift`

1. **Lines 984-996:** KeyID matching checks
   - **Current:** Blocks with "will not verify" message
   - **Status:** Acceptable for state consistency, but wording implies security decision
   - **Fix:** Change error messages to focus on state consistency, not verification outcome
   - **Example:** `"keyID mismatch – cannot generate assertion: state inconsistency"`

### ✅ Correctly Implemented

- ✅ No local signature verification (`CryptoKit.isValidSignature` removed)
- ✅ Assertions treated as opaque (decoding for logging only)
- ✅ Backend responses displayed without interpretation
- ✅ Evidence generation is observational only
- ✅ No assertion caching across challenges
- ✅ Raw bytes preserved and sent unchanged

---

## Required Code Changes

### Change 1: Remove Security Inference from Error Messages

**File:** `ContentView.swift`

**Lines 984-996:** Update error messages to focus on state consistency:

```swift
// BEFORE:
backendError = "keyID mismatch – assertion will not verify"

// AFTER:
backendError = "keyID mismatch – cannot generate assertion: state inconsistency"
```

**Lines 1009-1010:** Update bundle ID warning:

```swift
// BEFORE:
print("[ContentView]   ✗ WARNING: Bundle ID mismatch - assertion will NOT verify!")

// AFTER:
print("[ContentView]   ⚠ WARNING: Bundle ID mismatch - backend may reject based on policy")
```

**Line 209:** Update init warning:

```swift
// BEFORE:
print("[ContentView] ✗ App Attest signatures will NOT verify if backend uses different bundle ID")

// AFTER:
print("[ContentView] ⚠ Bundle ID mismatch - backend may reject based on policy")
```

### Change 2: Clarify State Consistency vs Security

**File:** `ContentView.swift`

**Lines 984-996:** Add comment clarifying purpose:

```swift
// State consistency check: Ensure keyID matches registered keyID
// This prevents UI confusion, not a security decision
guard let registeredKeyID = registeredKeyID, registeredKeyID == keyID else {
    isGeneratingAssertion = false
    backendError = "keyID mismatch – cannot generate assertion: state inconsistency"
    print("[ContentView] ERROR: generateAssertion blocked – keyID does not match registered keyID (state consistency)")
    return
}
```

---

## Testing Checklist

After implementing changes, verify:

- [ ] No error messages infer verification success/failure
- [ ] No warnings claim cryptographic validity/invalidity
- [ ] State consistency checks are clearly labeled as such
- [ ] Backend responses are displayed without interpretation
- [ ] Evidence generation is clearly marked as observational
- [ ] Assertions are never reused across challenges
- [ ] All artifacts are sent unchanged to backend

---

## Summary

The frontend's role is **transport and evidence generation only**. It must:
- ✅ Generate artifacts via Apple APIs
- ✅ Transport them unchanged
- ✅ Log evidence for debugging
- ✅ Display backend responses

It must **never**:
- ❌ Infer cryptographic validity
- ❌ Make trust decisions
- ❌ Interpret security state
- ❌ Cache or reuse assertions improperly

All security decisions belong to the backend. The frontend is a byte transport layer with observational logging.

---

## Related Documentation

**Referenced by (this contract is authoritative):**
- **`FRONTEND_INVARIANTS_CHECKLIST.md`** - Quick reference checklist (this directory)
- **`FRONTEND_VIOLATIONS_AND_FIXES.md`** - Violations found and fixes applied (this directory)

**References (for context only):**
- **`../APP_ATTEST_E2E_CONTRACT.md`** - E2E protocol contract (test app + backend)
- **`../SIX_VALUES_PROCEDURE.md`** - Debugging procedure (frontend vs backend comparison)
- **`../VERIFICATION_GUIDE.md`** - Server-side verification guide (backend responsibilities)
- **`TEST_APP_GUIDE.md`** - Complete test app setup and usage guide (this directory)
- **`../../README.md`** - Project overview and cryptographic verification guidance
