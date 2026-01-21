# Frontend Operations Summary

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

This document summarizes what the frontend displays, forwards, and records.

---

## Frontend Operations

### 1. Artifact Generation

- Displays keyID returned by `DCAppAttestService.generateKey()`
- Displays attestationObject bytes returned by `DCAppAttestService.attestKey()`
- Displays assertionObject bytes returned by `DCAppAttestService.generateAssertion()`
- Records timestamps for each operation

### 2. Data Transport

- Forwards exact bytes to backend unchanged
- No modification of artifact bytes
- No interpretation of data meaning
- Handles network errors (connection failures, timeouts, HTTP errors)

### 3. Backend Response Display

- Shows backend responses verbatim (no modification)
- Attributes status to backend ("Backend response (status: ...)")
- Records flow trace with timestamps and flowID
- Does not interpret response meaning

### 4. State Management

- Tracks flowID from registration response
- Tracks keyID for UI state
- Tracks verifyRunID for log correlation
- State checks maintain UI consistency

---

## Frontend Authority Boundaries

The frontend performs no cryptographic verification, makes no security decisions, treats responses as non-authoritative, and does not block operations based on backend status.

**No cryptographic verification:**
- No signature verification
- No certificate chain validation
- No certificate expiration checks
- No nonce verification

**No security decisions:**
- No trust decisions
- No authorization decisions
- No policy enforcement
- No validity interpretation

**Non-authoritative responses:**
- Backend responses are displayed verbatim
- Status values are literal strings, not interpreted
- No meaning is inferred from response codes

**No blocking:**
- Operations are not blocked based on backend status
- Buttons remain enabled regardless of response
- State is preserved regardless of response

---

## Consistent Wording

Throughout the codebase, these phrases are used consistently:

### Backend Attribution

- "Backend response (status: ...)"
- "Backend returned status: ..."

### Frontend Actions

- "Frontend displays..."
- "Frontend forwards..."
- "Frontend records..."

### Non-Actions

- "Frontend does not verify"
- "Frontend does not decide"
- "Frontend does not enforce"
- "Frontend does not block"
- "Frontend does not interpret"

---

## Key Principles

1. **Observational Only:** Frontend observes and records, does not decide
2. **Backend Authority:** All verification and security decisions are backend's responsibility
3. **State for UI:** State checks maintain UI consistency
4. **Verbatim Display:** Backend responses shown exactly as received
5. **No Blocking:** Frontend never blocks operations based on backend status

---

## Examples

See `GUIDE.md` Chapter 5 for concrete examples showing:
- Complete flow with data trace
- Backend rejection display
- Repeated submission display

---

## Related Documentation

- **`GUIDE.md`** - Complete guide to understanding and using the test app
- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Detailed contract
- **`FRONTEND_NON_AUTHORITY_TEST.md`** - Test checklist
