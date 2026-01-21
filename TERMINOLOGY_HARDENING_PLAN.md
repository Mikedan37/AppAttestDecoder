# Frontend Terminology Hardening Plan

## Terminology Replacements

### CRITICAL: Remove Authoritative Language

| Current | Replacement | Rationale |
|---------|------------|-----------|
| "Ground truth" | "Evidence" or "Observational data" | "Ground truth" implies authority |
| "guaranteed by" | "determined by" | Already fixed most, check remaining |
| "confirmed" | "check passed" or "state consistent" | "Confirmed" implies validation |
| "ensure" | "check" or "log for" | "Ensure" implies responsibility |
| "BLOCKED" | "SKIPPED" or "cannot proceed" | "BLOCKED" suggests enforcement |
| "rejected" / "accepted" | "Backend reported: rejected/accepted" | Ensure backend attribution |
| "Verified cryptographically" (UI) | "Backend verification status" | Clarify backend performs verification |

### HIGH: Clarify Backend Attribution

| Current | Replacement | Rationale |
|---------|------------|-----------|
| "verified" (status) | "Backend verification result: verified" | Clear backend attribution |
| "verification" (general) | "backend verification" | Clarify backend-only |
| "independent verification" | "backend verification" | Remove "independent" ambiguity |

### MEDIUM: Soften Enforcement Language

| Current | Replacement | Rationale |
|---------|------------|-----------|
| "must match" | "backend expects" or "should match" | "Must" implies frontend enforcement |
| "HARD GUARD" | "State check" | Remove enforcement implication |
| "CRITICAL" (non-security) | "IMPORTANT" | Reserve CRITICAL for actual security |

## Files to Update

1. ContentView.swift - Multiple instances
2. TrustBoundaryView.swift - "Verified cryptographically" label
3. CryptoEvidence.swift - Check for "ground truth"
4. Documentation files - Ensure consistency
