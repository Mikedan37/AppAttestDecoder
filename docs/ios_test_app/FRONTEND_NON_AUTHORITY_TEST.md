# Frontend Non-Authority Test Checklist

**Purpose:** Verify that the frontend does not make security decisions or block/allow operations based on backend responses.

**Scope:** Manual test checklist for the iOS test app.

**Review Method:** This checklist can be reviewed by examining code and documentation without running the app. Each test includes code references and expected behaviors.

---

## Quick Review (Without Running App)

### Code Examination

**Search for these patterns in `ContentView.swift`:**

1. **No verification calls:**
   - Search: `isValidSignature` → Should find 0 results
   - Search: `verifySignature` → Should find 0 results
   - Search: `CryptoKit.*verify` → Should find 0 results

2. **Backend attribution:**
   - Search: `Backend response` → Should find all response displays
   - Search: `Backend returned status` → Should find status attribution
   - Search: `backend performs` → Should find verification attribution

3. **State-based errors:**
   - Search: `flowID missing` → Should find state errors, not security errors
   - Search: `keyID mismatch` → Should find state consistency checks
   - Search: `state error` → Should find state-based language

4. **No blocking logic:**
   - Search: `disabled.*backend` → Should find 0 results
   - Search: `if.*rejected.*disabled` → Should find 0 results
   - Search: `if.*verified.*enabled` → Should find 0 results

**Expected Results:**

- [ ] No cryptographic verification calls found
- [ ] All backend responses attributed to backend
- [ ] All errors describe state, not security
- [ ] No blocking logic based on backend status

---

## Test Procedure

### Prerequisites

1. Backend server running and accessible
2. Test app configured with backend URL
3. Physical iOS device with App Attest capability enabled

---

## Test 1: Backend Response Display

**Objective:** Verify backend responses are displayed verbatim without interpretation.

**Steps:**

1. Complete full flow: Generate Key → Attest Key → Register → Assert Key → Send to Backend
2. Observe backend response display
3. Check console logs for exact backend response text

**Expected Results:**

- Backend response text matches exactly what backend sent
- UI shows "Backend response (status: verified)" or "Backend response (status: rejected)"
- No frontend interpretation or modification of response text
- Console logs show raw backend response JSON

**Code Reference:**

- `ContentView.swift` line ~1423: `self.backendResponse = "Backend response (status: verified): \(jsonString)"`
- `ContentView.swift` line ~1429: `self.backendResponse = "Backend response (status: rejected): \(jsonString)"`

**Pass Criteria:**

- [ ] Response text is verbatim from backend
- [ ] No frontend-added security language
- [ ] Status clearly attributed to backend
- [ ] Code shows backend attribution in response display

---

## Test 2: No Blocking Based on Backend Response

**Objective:** Verify frontend does not block operations based on backend verification status.

**Steps:**

1. Complete registration successfully
2. Generate assertion
3. Send assertion to backend
4. If backend returns "rejected", attempt to:
   - Generate new assertion with same keyID
   - Send assertion again
   - Continue using the app

**Expected Results:**

- Frontend does not disable buttons based on backend rejection status
- Frontend does not prevent generating new assertions
- Frontend does not clear state or block operations
- UI remains functional regardless of backend response

**Code Reference:**

- `ContentView.swift` line ~2116: Button disabled state based on `isSendingToBackend`, not backend response status
- `ContentView.swift` line ~1420-1431: Backend response handling does not modify button states
- No code found that disables buttons based on `status == "rejected"`

**Pass Criteria:**

- [ ] Buttons remain enabled regardless of backend response status
- [ ] New assertions can be generated
- [ ] Assertions can be sent multiple times
- [ ] No UI blocking or disabling based on backend status
- [ ] Code review confirms no blocking logic

---

## Test 3: No Local Security Decisions

**Objective:** Verify frontend does not make security decisions locally.

**Steps:**

1. Generate key
2. Attest key
3. Register attestation
4. Generate assertion
5. Check console logs for any security-related decisions

**Expected Results:**

- No local signature verification
- No certificate chain validation
- No policy enforcement (bundle ID, environment)
- No trust decisions
- Only state consistency checks (keyID matches, flowID exists)

**Code Reference:**

- `ContentView.swift` line ~7-8: Comments state "no on-device ECDSA verification"
- `ContentView.swift` line ~15: Comments state "We do NOT re-verify them locally"
- `ContentView.swift` line ~1294: State consistency check comment: "for UI consistency, not security"
- Search `isValidSignature` → 0 results
- Search `certificate.*valid` → 0 results

**Pass Criteria:**

- [ ] No CryptoKit.isValidSignature calls
- [ ] No certificate validation
- [ ] No policy checks
- [ ] Only state consistency checks in logs
- [ ] Code review confirms no verification logic

---

## Test 4: Flow Trace Observability

**Objective:** Verify flow trace shows complete flow without security interpretation.

**Steps:**

1. Complete full flow: Registration → Challenge → Assertion → Backend Response
2. Open Flow Trace view
3. Review entries

**Expected Results:**

- Flow trace shows all steps with timestamps
- flowID displayed for each step
- Status shows "completed", "sent", "verified", or "rejected"
- No security language or interpretation
- Labeled as "Diagnostic Flow Trace. No local verification performed"

**Code Reference:**

- `FlowTraceView.swift` line ~27-30: Label shows "Diagnostic Flow Trace" with "No local verification performed"
- `ContentView.swift` line ~412-416: Flow trace entry added on registration
- `ContentView.swift` line ~1420-1431: Flow trace entry added on backend response
- Status values: "completed", "sent", "verified", "rejected" (from backend)

**Pass Criteria:**

- [ ] All steps recorded
- [ ] Timestamps accurate
- [ ] flowID consistent across steps
- [ ] Status reflects backend response, not frontend decision
- [ ] No security claims or guarantees
- [ ] Code review confirms label and status attribution

---

## Test 5: Error Messages Are State-Based

**Objective:** Verify error messages describe state, not security.

**Steps:**

1. Attempt operations out of order (e.g., send assertion without completing registration)
2. Observe error messages
3. Check for security language

**Expected Results:**

- Error messages describe state issues ("flowID missing", "keyID mismatch")
- No security language ("invalid", "unauthorized", "blocked")
- Messages clarify what state is needed, not why it's needed

**Code Reference:**

- `ContentView.swift` line ~1276: `"State error: flowID is missing"`
- `ContentView.swift` line ~1296: `"KeyID mismatch! The key used for verify request does not match the registered key"`
- `ContentView.swift` line ~1008: `"clientDataHash length incorrect: expected 32 bytes"`
- Search `"invalid"` → Should find format validation, not security
- Search `"unauthorized"` → Should find 0 results
- Search `"blocked"` → Should find 0 results

**Pass Criteria:**

- [ ] Errors describe state, not security
- [ ] No "invalid" or "unauthorized" language
- [ ] No "blocked" or "allowed" language
- [ ] Messages are descriptive, not prescriptive
- [ ] Code review confirms state-based error language

---

## Summary

**All tests expected to pass** to confirm frontend non-authority.

**If any test fails:**

- Document the failure
- Identify where frontend makes security decisions
- Fix to remove security decision-making
- Re-run tests

---

## Related Documentation

- **`ROLE_OF_FRONTEND.md`** - What the frontend does and never does
- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Detailed contract
- **`WHAT_THIS_TEST_APP_MEASURES.md`** - What can be observed vs cannot prove
