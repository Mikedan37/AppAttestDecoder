# Frontend Terminology Hardening - Summary

## Changes Applied

### CRITICAL Terminology Fixes

1. **"Ground truth" → "Evidence"**
   - Function comments, error messages, UI buttons
   - Rationale: "Ground truth" implies authoritative correctness

2. **"guaranteed" → "determined"**
   - Comments about validity
   - Rationale: "Guaranteed" is a warranty claim; "determined" is factual

3. **"confirmed" → "check passed (state consistency)"**
   - Log messages about key continuity
   - Rationale: "Confirmed" implies validation; clarified as state check

4. **"BLOCKED" → "SKIPPED" or "cannot proceed"**
   - Error messages and logs
   - Rationale: "BLOCKED" suggests security enforcement

5. **"ENABLED" / "HARD BLOCKED" → State consistency language**
   - Registration success/failure messages
   - Rationale: Frontend doesn't enable/block verification

6. **"VERIFIED" / "REJECTED" → "Backend response (status: verified/rejected)"**
   - UI display strings
   - Rationale: Explicit backend attribution

### HIGH Priority Fixes

7. **"ensure" → "check" or "log for"**
   - Comments about state checks
   - Rationale: "Ensure" implies responsibility

8. **"must match" → "backend expects" or "should match"**
   - Bundle ID and keyID checks
   - Rationale: "Must" implies frontend enforcement

9. **"HARD GUARD" → "State check"**
   - Guard comments
   - Rationale: Remove enforcement implication

10. **"CRITICAL" (non-security) → "IMPORTANT"**
    - Comments about flow consistency
    - Rationale: Reserve CRITICAL for actual security boundaries

11. **"verification" → "backend verification"**
    - Comments, variable names, function docs
    - Rationale: Clarify backend-only responsibility

12. **"Verified cryptographically" (UI) → "Backend verification status"**
    - TrustBoundaryView label
    - Rationale: Clarify backend performs verification

### MEDIUM Priority Fixes

13. **"independent verification" → "backend verification"**
    - Function documentation
    - Rationale: Remove ambiguity

14. **"for verification" → "for backend verification"**
    - Comments and help text
    - Rationale: Explicit backend attribution

## Files Modified

1. `AppAttestDecoderTestApp/ContentView.swift` - 30+ changes
2. `AppAttestDecoderTestApp/TrustBoundaryView.swift` - 1 change

## Remaining Terminology

The following terms are **acceptable** as they are:
- "Secure Enclave" - Apple's official term
- "verification request" - Refers to HTTP request, not frontend verification
- "verify" (as verb for HTTP endpoint) - Clear it's a backend endpoint
- Checkmarks (✓) - Used for state consistency, not security validation

## Compliance Status

✅ **Frontend is now clearly diagnostic and non-authoritative**

All language now:
- Explicitly attributes verification to backend
- Uses observational/state consistency language
- Avoids warranty claims or security guarantees
- Clarifies frontend role as transport/evidence generator only

## Out-of-Context Safety

The frontend is now safe even if:
- Screenshots are taken without context
- Logs are quoted in bug reports
- UI text is copied into documentation
- Code comments are extracted

All language explicitly states backend responsibility and frontend limitations.
