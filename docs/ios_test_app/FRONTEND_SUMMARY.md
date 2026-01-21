# Frontend Responsibilities Summary

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

This document provides a concise summary of what the frontend is responsible for and what it is not responsible for.

---

## Frontend Responsibilities

### 1. Generate Artifacts

- **Generates keys** via `DCAppAttestService.generateKey()`
- **Generates attestations** via `DCAppAttestService.attestKey()`
- **Generates assertions** via `DCAppAttestService.generateAssertion()`
- **Records timestamps** for each operation

### 2. Transport Data

- **Sends exact bytes** to backend unchanged
- **No modification** of artifact bytes
- **No interpretation** of data meaning
- **Handles network errors** (connection failures, timeouts, HTTP errors)

### 3. Display Backend Responses

- **Shows backend responses verbatim** (no modification)
- **Attributes status to backend** ("Backend response (status: ...)")
- **Records flow trace** with timestamps and flowID
- **Does not interpret** response meaning

### 4. Maintain State (UI Consistency Only)

- **Tracks flowID** from registration response
- **Tracks keyID** for UI state
- **Tracks verifyRunID** for log correlation
- **State checks ensure UI consistency**, not security

---

## Frontend Non-Responsibilities

### 1. Verification

- **Does NOT verify** cryptographic signatures
- **Does NOT validate** certificate chains
- **Does NOT check** certificate expiration or revocation
- **Does NOT verify** RP ID hashes or nonces
- **Backend performs all verification**

### 2. Security Decisions

- **Does NOT decide** whether artifacts are valid
- **Does NOT decide** whether keys should be trusted
- **Does NOT decide** whether assertions should be accepted
- **Does NOT decide** whether users should be authorized
- **Backend makes all security decisions**

### 3. Policy Enforcement

- **Does NOT enforce** bundle ID matching
- **Does NOT enforce** environment checks
- **Does NOT enforce** replay protection
- **Does NOT enforce** freshness requirements
- **Backend enforces all policy**

### 4. Blocking or Allowing

- **Does NOT block** operations based on backend responses
- **Does NOT disable** buttons after rejection
- **Does NOT prevent** generating new assertions
- **Does NOT clear** state based on verification status
- **Backend controls access**

---

## Consistent Wording

Throughout the codebase, these phrases are used consistently:

### Backend Attribution

- "Backend performs verification"
- "Backend response (status: ...)"
- "Backend returned status: ..."
- "Backend performs all cryptographic verification"
- "Backend enforces policy"

### Frontend Actions

- "Frontend generates artifacts"
- "Frontend sends data to backend"
- "Frontend displays backend responses"
- "Frontend records flow trace"
- "Frontend maintains state (UI consistency only)"

### Non-Actions

- "Frontend does NOT verify"
- "Frontend does NOT decide"
- "Frontend does NOT enforce"
- "Frontend does NOT block"
- "Frontend does NOT interpret"

---

## Key Principles

1. **Observational Only:** Frontend observes and records, does not decide
2. **Backend Authority:** All verification and security decisions are backend's responsibility
3. **State for UI:** State checks ensure UI consistency, not security
4. **Verbatim Display:** Backend responses shown exactly as received
5. **No Blocking:** Frontend never blocks operations based on backend status

---

## Examples

See `EXAMPLES.md` for concrete examples showing:
- Successful flow with complete data trace
- Backend rejection with no frontend blocking
- Repeated submission with no frontend replay protection

---

## Related Documentation

- **`ROLE_OF_FRONTEND.md`** - Detailed explanation of frontend role
- **`EXAMPLES.md`** - Concrete flow examples
- **`FRONTEND_NON_AUTHORITY_TEST.md`** - Test checklist
- **`WHAT_THIS_TEST_APP_MEASURES.md`** - Measurement vs security
- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Detailed contract
