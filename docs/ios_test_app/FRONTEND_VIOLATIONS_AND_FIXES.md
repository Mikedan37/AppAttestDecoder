# Frontend App Attest Violations and Required Fixes

**Date:** 2026-01-20  
**Status:**  All Fixes Applied  
**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

> **Reference:** Violations are defined relative to `FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md` (authoritative).

## Summary

The frontend implementation is **mostly correct** but contains **3 violations** where it infers security state or makes trust assumptions. These must be fixed to comply with the Frontend App Attest Responsibility Contract.

---

## Violations Found

### Violation 1: Security State Inference in Error Messages

**File:** `ContentView.swift`  
**Lines:** 984-996, 1010, 209

**Issue:** Error messages and warnings infer that assertions "will not verify" or "will NOT verify", implying cryptographic validity interpretation.

**Examples:**
```swift
// Line 986
backendError = "keyID mismatch – assertion will not verify"

// Line 1010
print("[ContentView]    WARNING: Bundle ID mismatch - assertion will NOT verify!")

// Line 209
print("[ContentView]  App Attest signatures will NOT verify if backend uses different bundle ID")
```

**Problem:** The frontend is inferring cryptographic verification outcomes, which violates the contract. The frontend should only report state inconsistencies or potential backend policy rejections.

**Fix Required:** Change all messages to focus on state consistency or backend policy, not cryptographic validity.

---

### Violation 2: Response Status Interpretation

**File:** `ContentView.swift`  
**Lines:** 1415-1426

**Issue:** Response handling uses phrases like "VERIFY succeeded – assertion verified" and "VERIFY rejected – assertion did not verify", which implies interpretation of security state.

**Current Code:**
```swift
if status == "verified" || status == "accepted" {
    self.backendResponse = "VERIFIED: \(jsonString)"
    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY succeeded – assertion verified")
} else if status == "rejected" {
    self.backendResponse = "REJECTED: \(jsonString)"
    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY rejected – assertion did not verify")
}
```

**Problem:** The frontend is interpreting backend responses as security verdicts. While displaying the status is correct, the wording implies the frontend is making a security decision.

**Fix Required:** Change to transport-level language: "Backend returned verified" vs "Backend returned rejected".

---

###  Acceptable: State Consistency Checks

**File:** `ContentView.swift`  
**Lines:** 984-996, 1294-1318

**Status:** These checks are **acceptable** for state consistency (preventing UI confusion), but the error messages need clarification.

**Current:** Blocks assertion generation if keyID doesn't match registered keyID.

**Rationale:** This prevents UI state confusion (user tries to verify with wrong key). However, the error message implies a security decision.

**Fix Required:** Keep the checks, but clarify in comments and error messages that this is state consistency, not security.

---

## Required Code Changes

### Change 1: Fix Security Inference Messages

**File:** `ContentView.swift`

#### Fix 1.1: KeyID Mismatch Error (Line 986)

```swift
// BEFORE:
guard let registeredKeyID = registeredKeyID, registeredKeyID == keyID else {
    isGeneratingAssertion = false
    backendError = "keyID mismatch – assertion will not verify"
    print("[ContentView] ERROR: generateAssertion rejected – keyID does not match registered keyID")
    return
}

// AFTER:
// State consistency check: Ensure keyID matches registered keyID
// This prevents UI confusion, not a security decision
guard let registeredKeyID = registeredKeyID, registeredKeyID == keyID else {
    isGeneratingAssertion = false
    backendError = "keyID mismatch – cannot generate assertion: state inconsistency"
    print("[ContentView] ERROR: generateAssertion blocked – keyID does not match registered keyID (state consistency check)")
    return
}
```

#### Fix 1.2: Bundle ID Warning (Line 1010)

```swift
// BEFORE:
if bundleID != "DanylchukStudios.AppAttestDecoderTestApp" {
    print("[ContentView]    WARNING: Bundle ID mismatch - assertion will NOT verify!")
}

// AFTER:
if bundleID != "DanylchukStudios.AppAttestDecoderTestApp" {
    print("[ContentView] WARNING: Bundle ID mismatch - backend may reject based on policy")
}
```

#### Fix 1.3: Init Bundle ID Warning (Line 209)

```swift
// BEFORE:
print("[ContentView]  App Attest signatures will NOT verify if backend uses different bundle ID")

// AFTER:
print("[ContentView] WARNING: Bundle ID mismatch - backend may reject based on policy")
```

### Change 2: Fix Response Status Language

**File:** `ContentView.swift`  
**Lines:** 1415-1426

```swift
// BEFORE:
if status == "verified" || status == "accepted" {
    self.backendResponse = "VERIFIED: \(jsonString)"
    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY succeeded – assertion verified")
} else if status == "rejected" {
    self.backendResponse = "REJECTED: \(jsonString)"
    print("[ContentView] RESULT verifyRunID=\(runID) | VERIFY rejected – assertion did not verify")
}

// AFTER:
if status == "verified" || status == "accepted" {
    self.backendResponse = "Backend returned: VERIFIED - \(jsonString)"
    print("[ContentView] RESULT verifyRunID=\(runID) | Backend returned status: verified")
} else if status == "rejected" {
    self.backendResponse = "Backend returned: REJECTED - \(jsonString)"
    print("[ContentView] RESULT verifyRunID=\(runID) | Backend returned status: rejected")
}
```

### Change 3: Add Clarifying Comments

**File:** `ContentView.swift`  
**Line 1253**

```swift
// BEFORE:
/// Frontend assumes: if the backend accepts, the assertion is valid.

// AFTER:
/// Frontend displays backend responses without interpretation.
/// Backend performs all cryptographic verification and policy enforcement.
/// Frontend does not infer validity from response status.
```

---

## Verification Checklist

After applying fixes, verify:

- [ ] No error messages claim assertions "will not verify"
- [ ] No warnings infer cryptographic validity
- [ ] State consistency checks are clearly labeled as such
- [ ] Backend responses are displayed without security interpretation
- [ ] All messages focus on transport/state, not security decisions
- [ ] Comments clarify observational vs security boundaries

---

## Files Requiring Changes

1. **`AppAttestDecoderTestApp/ContentView.swift`**
   - Lines 209, 986, 1010: Fix security inference messages
   - Lines 1415-1426: Fix response status language
   - Line 1253: Clarify comment about backend responses

**Total changes:** 5 locations, all message/comment updates (no logic changes)

---

## Impact Assessment

**Risk Level:** Low  
**Breaking Changes:** None  
**User Impact:** Error messages become more accurate (state consistency vs security)

These are **cosmetic fixes** that clarify intent. No functional changes required. The implementation already correctly treats artifacts as opaque and does not perform cryptographic verification.
