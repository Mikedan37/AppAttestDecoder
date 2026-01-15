# Project Status

## Current State

**Functionally:** Complete  
**Maturely:** Production-ready (only polish or productization remains)

## What It Is

A professional-grade security tool for decoding Apple App Attest artifacts. It provides:

- **Lossless inspection** - Every byte visible, nothing hidden
- **Dual-view output** - Raw bytes + decoded values side-by-side
- **Full transparency** - Unknown fields preserved, not guessed
- **Research-grade export** - JSON for diffing, corpus building, audits
- **Robust error handling** - Survives malformed input and future drift
- **Failsafe configuration** - Recursion limits, size thresholds, strict/best-effort modes

## Why It's Good

**It never lies about certainty.**
- Unknown fields are labeled as opaque
- Confidence levels are explicit
- No false interpretation of undocumented Apple internals

**It preserves evidence instead of collapsing it.**
- Raw bytes always available
- Nothing discarded for readability
- Full ASN.1 and CBOR trees accessible

**It survives malformed input and future drift.**
- Defensive bounds checking
- Graceful error handling
- Best-effort parsing with clear failure modes
- Schema validation without breaking on unknowns

**It treats undocumented Apple fields like a professional auditor would.**
- Preserves structure
- Labels uncertainty
- Provides best-effort interpretation with confidence levels
- Refuses to claim authority over private fields

## Technical Validation

### iOS Compatibility

**Yes. Cleanly.**

- Pure Swift implementation
- No macOS-only frameworks
- No Security.framework verification shortcuts
- No filesystem assumptions
- Respects the line between inspection and verification

Your iOS test app can:
1. Call `generateKey`
2. Call `attestKey`
3. Take the Base64 attestation blob
4. Immediately feed it into the decoder
5. Render semantic / forensic / lossless views

This is completely legitimate and aligns with Apple's model. You're looking, not judging.

### Architecture Quality

**Separation of concerns:**
- Decoding (structural parsing)
- Interpretation (semantic meaning with confidence)
- Presentation (multiple output formats)
- Verification (explicitly not included)

**Failure modes, not happy paths:**
- Recursion depth limits
- Max byte thresholds
- Container size limits
- Strict vs best-effort modes
- Graceful degradation

**Instrumentation, not demo:**
- Lossless preservation
- Evidence-first design
- Audit trail completeness
- Research-grade export

## Architecture Decisions

The tool's architecture reflects these design constraints:

- Separation of decoding, interpretation, and verification
- Failure-mode thinking, not happy-path assumptions
- Instrumentation-first design, not demo code
- Platform/security/infrastructure-level concerns

## Optional Enhancements

These are multipliers, not fixes. The tool is complete without them.

### 1. SwiftUI Inspector UI

**What:** A simple iOS view for on-device inspection
- Paste Base64 attestation
- Mode selector (semantic / forensic / lossless)
- Render output
- Copy / export

**Value:** Immediate visual feedback during development

**Effort:** Low (see `docs/IOS_ON_DEVICE_INSPECTION.md` for example)

### 2. Golden Fixtures Across iOS Versions

**What:** Curated attestation samples from multiple iOS versions
- iOS 14.x, 15.x, 16.x, 17.x, 18.x
- Documented schema changes
- Regression test suite

**Value:** Detect Apple drift early, validate decoder across versions

**Effort:** Medium (requires device access, curation)

### 3. Data-Driven OID Registry File

**What:** External JSON/plist mapping OIDs to names, decoders, confidence levels
- Easy to extend without code changes
- Community-contributed OIDs
- Versioned registry

**Value:** Extensibility, community contribution, easier maintenance

**Effort:** Medium (refactor current hardcoded OIDs)

### 4. Environment Diffing

**What:** Compare attestations across contexts
- Dev vs prod
- Different bundle IDs
- Different OS versions
- Side-by-side diff view

**Value:** Spot configuration issues, validate environment binding

**Effort:** Medium (diff algorithm, UI)

### 5. JSON Export → Diff Tooling

**What:** Structured diff utilities for attestation JSON
- Semantic diff (ignore formatting)
- Field-level changes
- Certificate chain comparison
- Extension delta analysis

**Value:** Automated drift detection, corpus analysis

**Effort:** High (requires diff algorithm, analysis logic)

## What's Not Included (By Design)

- **Signature verification** - Out of scope (server-side concern)
- **Certificate chain validation** - Out of scope (server-side concern)
- **RP ID hash validation** - Out of scope (server-side concern)
- **Trust decisions** - Out of scope (server-side concern)

The tool is inspection-only. Verification is explicitly separate.

## Documentation

Complete documentation available:

- `README.md` - Project overview
- `WHAT_THIS_TOOL_IS.md` - Philosophy and scope
- `CLI_QUICK_START.md` - Quick reference
- `COMMAND_REFERENCE.md` - Full CLI reference
- `VERIFICATION_GUIDE.md` - What to verify on server
- `IOS_ON_DEVICE_INSPECTION.md` - Using decoder in iOS app
- `MODES_AND_LAYERS.md` - Architecture explanation
- `PROJECT_AUDIT_COMPLETE.md` - Complete audit

## Test Coverage

- 7 test files
- 75+ test methods
- Real device-generated attestations
- Edge cases and error handling
- Robustness tests for hostile input

## Final Assessment

The tool is:
- Functionally complete
- Maturely production-ready
- Built for fuzziness, not just happy paths
- Designed for incident response and forensic clarity

**Status:** Ready for use. Optional enhancements are multipliers, not requirements.

---

*Last updated: January 2026*
