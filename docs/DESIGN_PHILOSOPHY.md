# Design Philosophy

## Constraints and Tradeoffs

This tool was designed with the following constraints:

**Separation of Concerns:**
- Inspection, interpretation, and verification are separate layers
- Each layer has clear boundaries and responsibilities
- No mixing of concerns that could lead to accidental trust decisions

**Defensive Assumptions:**
- Inputs may be hostile, corrupted, or malformed
- Schema drift is expected over time
- Partial failures should not crash the tool
- Recursion limits, size thresholds, and graceful degradation are built-in

**Evidence Preservation:**
- Raw bytes are always preserved alongside decoded values
- Unknown fields are decoded when possible and labeled explicitly as unstable
- Nothing is discarded for readability
- Undocumented fields are not over-interpreted

**Explicit Uncertainty:**
- Confidence levels are stated, not implied
- Unknown fields are labeled as opaque, not hidden
- Apple-private fields are marked as such
- No false certainty about undocumented structures

**Future Drift Awareness:**
- Handles schema changes gracefully
- Preserves evidence even when interpretation fails
- Best-effort parsing with clear failure modes
- No assumptions about stable field semantics

## Tradeoffs and Non-Goals

### Why Verification Is Not Implemented

Verification requires:
- Server-side certificate chain validation against Apple's root CA
- Cryptographic signature verification using platform keys
- RP ID hash validation against expected values
- Nonce validation against challenge values
- Policy decisions about acceptability

This tool focuses on structural parsing only. Verification is a separate concern that belongs in your server-side validation logic. Keeping them separate enables:
- Shared parsing logic without re-implementation
- Clear boundaries between structure and policy
- Flexible validation strategies without tool constraints

### Why Private Apple Fields Are Preserved

Apple-private fields (undocumented OIDs, opaque receipts, etc.) are preserved and labeled as opaque rather than discarded because:
- They may become decodable in the future
- They provide audit trails for incident response
- Discarding data creates false certainty
- Preserving unknowns is more honest than claiming completeness

The tradeoff: Output includes fields you cannot interpret. The benefit: Nothing is hidden or discarded.

### Why Extension vs App Are Not Normalized

Extensions and main apps generate separate App Attest keys and attestations. This tool does not normalize them because:
- They are separate trust surfaces by design
- Normalizing would hide important security boundaries
- The difference is structural, not a parsing artifact
- Hiding this difference would be misleading

The tradeoff: Users must understand execution context differences. The benefit: Truthful representation of Apple's trust model.

### Why Output Is Not Collapsed Into Booleans

The decoder exposes full structure (certificates, extensions, flags, etc.) rather than collapsing into boolean verdicts because:
- Different use cases need different fields
- Collapsing loses information needed for debugging
- Policy decisions require context, not just yes/no
- Raw materials enable flexible validation strategies

The tradeoff: Output is verbose. The benefit: Complete information for downstream use.

### Why Unknown Structures Are Not Rejected

Unknown or malformed structures are parsed best-effort and labeled as opaque rather than rejected because:
- Rejection creates false negatives (valid but unrecognized structures)
- Best-effort parsing provides partial information
- Opaque labeling is honest about uncertainty
- Future decoding may become possible

The tradeoff: Some output may be uninterpretable. The benefit: Nothing is lost, nothing is falsely rejected.

## Design Decisions

### Why So Verbose?

This tool prioritizes incident response and forensic clarity over simplicity.

The verbosity is intentional:
- Every field is visible, not collapsed
- Raw evidence is preserved alongside interpretation
- Multiple output modes serve different use cases
- Nothing is hidden for the sake of "clean" output

This makes the tool more verbose and less "simple," but significantly safer for debugging, auditing, and incident response.

### Why No Verification?

The goal is not to replace server-side verification or Apple's trust model.

The goal is to make attestation artifacts observable and diagnosable.

Verification requires:
- Cryptographic signature validation
- Certificate chain validation against Apple's root CA
- RP ID hash validation
- Replay protection
- Policy enforcement

These are server-side concerns. This tool provides the raw materials for verification, not verification itself.

### Why Preserve Unknown Fields?

Undocumented fields are decoded when possible and labeled explicitly as unstable, rather than discarded or over-interpreted.

This approach:
- Preserves evidence for future analysis
- Allows detection of schema drift
- Enables forensic investigation
- Avoids false certainty

Unknown does not mean meaningless. It means "not contractually stable."

### Why Multiple Output Modes?

Different use cases require different levels of detail:

- **Semantic:** Human-readable, scannable in <10 seconds
- **Forensic:** Semantic + raw evidence, auditable
- **Lossless Tree:** Every byte, every node, complete ground truth

No single view can be both readable and complete. The separation is intentional.

## Common Failure Modes This Tool Avoids

**Treating attestation as a boolean:**
- This tool shows structure, not just "valid/invalid"
- Evidence is preserved, not collapsed

**Hiding uncertainty:**
- Unknown fields are labeled, not hidden
- Confidence levels are explicit

**Mixing concerns:**
- Inspection, interpretation, and verification are separate
- No accidental trust decisions in the decoder

**Assuming happy paths:**
- Hostile inputs are expected
- Schema drift is handled gracefully
- Partial failures don't crash

**Over-interpreting undocumented fields:**
- Apple-private fields are marked as such
- No false claims about meaning
- Evidence is preserved for future analysis

## Tradeoffs

This tool makes explicit tradeoffs:

**Verbosity over simplicity:**
- More output, but complete transparency
- Harder to scan, but nothing hidden

**Evidence over interpretation:**
- Raw bytes preserved alongside decoded values
- Unknown fields preserved, not discarded

**Safety over convenience:**
- Failsafes add complexity
- Defensive checks add overhead
- But prevent crashes and data loss

**Observability over simplicity:**
- Multiple output modes add complexity
- But serve different use cases
- No single view can be both readable and complete

## Who This Tool Is For

This tool is designed for:
- Developers debugging App Attest integration issues
- Security engineers investigating fraud or incidents
- Platform engineers building server-side validation
- Auditors reviewing trust artifacts
- Researchers studying App Attest behavior

It prioritizes incident response and forensic clarity over simplicity.

## What This Tool Is Not

This tool is not:
- A replacement for server-side verification
- A trust authority or security validator
- A simple "valid/invalid" checker
- A replacement for Apple's trust model

It is instrumentation for understanding trust artifacts, not a trust decision maker.

---

## See Also

- `docs/WHAT_THIS_TOOL_IS.md` - What it is and isn't
- `docs/PROJECT_STATUS.md` - Current state and maturity
- `docs/VERIFICATION_GUIDE.md` - What to verify on the server
