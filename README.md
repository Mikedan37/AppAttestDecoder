# App Attest Decoder CLI

**This is a structural inspection tool for App Attest artifacts, not a security decision engine.**

A Swift library and CLI for inspecting Apple App Attest attestation and assertion artifacts.

> **Decoder-only.** No verification. No trust decisions.

Parses CBOR, ASN.1, COSE, and X.509 into semantic, forensic, diffable, and JSON representations. Performs no cryptographic verification, validation, or execution-context interpretation.

## When to Use This

- Inspect real device-generated App Attest artifacts
- Debug App Attest integration issues
- Build your own validator without reimplementing parsers
- Compare attestations generated at different times or under different app behaviors
- Archive and analyze artifacts in CI or research workflows

## What This Tool Does

- Decodes App Attest attestation objects and assertions
- Parses CBOR, ASN.1, COSE, and X.509 structures
- Preserves undocumented and Apple-private fields
- Preserves additional identity material (e.g. entitlement-dependent fields) without interpretation
- Produces human-readable, forensic, and JSON outputs
- Exposes raw materials (certificates, signatures, authenticator data)

## What This Tool Does Not Do

- No cryptographic verification
- No certificate chain validation
- No policy or trust decisions
- No DeviceCheck or App Attest API calls

This is an **inspection tool**, not a validator.

## CLI Usage

**If you only run one command, run this:**

```bash
pretty --forensic --file /path/to/attestation.b64
```

### Basic Commands

```bash
# Semantic view (default, human-readable)
pretty --file /path/to/attestation.b64

# Forensic view (evidence-preserving) - RECOMMENDED for audit workflows
pretty --forensic --file /path/to/attestation.b64

# Lossless tree (complete dump)
pretty --lossless-tree --file /path/to/attestation.b64 --no-color

# JSON output (for tooling/CI)
pretty --json --file /path/to/attestation.b64 > attestation.json
```

**Note:** JSON output is best-effort and versioned. See `docs/JSON_EXPORT_CONTRACT.md` for field stability.

### Exit Codes

- **0** - Decoded successfully
- **1** - Input malformed (invalid base64, missing file, etc.)
- **2** - Structurally valid but partial decode (e.g. unknown or future COSE/X.509 structure)
- **3** - Internal error

### Input Methods

```bash
# From file
pretty --file /path/to/attestation.b64

# From base64 string
pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."

# From stdin
cat attestation.b64 | pretty
```

**Note:** The CLI currently requires Xcode execution (via scheme arguments) due to dynamic framework rpath constraints. See `docs/SCHEME_ARGUMENTS.md` for setup.

## Library Usage (Swift)

```swift
import AppAttestCore

let decoder = AppAttestDecoder(teamID: nil)
let attestation = try decoder.decodeAttestationObject(data)

// Build semantic model
let model = try attestation.buildSemanticModel()
let printer = SemanticPrinter(colorized: false)
let output = printer.print(model)
```

**Important:** This library performs parsing only. All verification must be implemented separately.

## Architecture

```
Device → Attestation Artifact → [ THIS TOOL ] → Parsed Evidence → Your Validator → Policy / Trust
```

**Separation of concerns:**
- **Inspection** (this tool): Structural parsing, field extraction, evidence preservation
- **Verification** (your code): Cryptographic validation, certificate chain validation, policy enforcement

## iOS Test App (AppAttestDecoderTestApp)

The in-repo iOS target is a **diagnostic test application**—not a production client. It is intentionally verbose, forensic, and non-optimized for clarity and debugging.

**Documentation:** See `docs/ios_test_app/README.md` for complete documentation including setup, data flow, and troubleshooting.

**Key documents:**
- `docs/ios_test_app/ROLE_OF_FRONTEND.md` - What the frontend does and never does
- `docs/ios_test_app/SETUP.md` - How to set up and run the app
- `docs/ios_test_app/DATA_FLOW.md` - What data is produced and sent
- `docs/ios_test_app/TROUBLESHOOTING.md` - Common issues and solutions

Flow, protocol, bindings, and ownership: **docs/APP_ATTEST_E2E_CONTRACT.md** (source of truth; this README does not restate them).

## Examples

- **End-to-End Workflow:** `examples/end_to_end_inspection_workflow/` - Complete flow from generation to validator handoff
- **Single Attestation:** `examples/single_attestation/` - Inspect one attestation using all output modes
- **Multiple Attestations:** `examples/multiple_attestations/` - Store and index attestations for lifecycle tracking
- **Diffing:** `examples/diffing/` - Compare attestations and interpret differences
- **On-device inspection (example):** `examples/ios_test_app/` — decoder integration pattern (debugging only). Distinct from the in-repo iOS reference app above.
- **CI Pipeline:** `examples/ci_pipeline/` - Safe CI integration patterns
- **Different Artifacts:** `examples/app_vs_extension_attestation/` - Compare attestations generated under different conditions

See `examples/README.md` for overview and boundaries.

## Anti-Patterns

**Do NOT use decoder output to make trust decisions.**

See `docs/ANTI_PATTERNS.md` for common misuse patterns and why they fail.

```swift
// WRONG: Using decoder output to make security decisions
if decoder.decode(attestation).looksValid {
    allowRequest()  // This is insecure!
}
```

The decoder is for **inspection only**. Implement a separate validator for security decisions.

## Documentation

- **Quick Start:** `docs/CLI_QUICK_START.md`
- **What This Tool Is:** `docs/WHAT_THIS_TOOL_IS.md` - Scope and boundaries
- **Threat Model:** `docs/THREAT_MODEL.md` - Explicit non-goals and assumptions
- **Anti-Patterns:** `docs/ANTI_PATTERNS.md` - Common misuse patterns
- **JSON Export Contract:** `docs/JSON_EXPORT_CONTRACT.md` - Stable fields and integration guidelines
- **Complete CLI Reference:** `docs/COMMAND_REFERENCE.md`
- **Server-Side Verification:** `docs/VERIFICATION_GUIDE.md`
- **Design Philosophy:** `docs/DESIGN_PHILOSOPHY.md` - Tradeoffs and non-goals
- **E2E Contract (test app + backend):** `docs/APP_ATTEST_E2E_CONTRACT.md` — **source of truth** for flow, bindings, request/response
- **iOS Test App Documentation:** `docs/ios_test_app/README.md` — complete documentation for the diagnostic test app
  - `docs/ios_test_app/ROLE_OF_FRONTEND.md` — what the frontend does and never does
  - `docs/ios_test_app/SETUP.md` — setup and configuration
  - `docs/ios_test_app/DATA_FLOW.md` — data flow and protocol
  - `docs/ios_test_app/TROUBLESHOOTING.md` — common issues and solutions
- **Frontend Responsibility Contract:** `docs/ios_test_app/FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md` — detailed frontend boundaries and invariants
- **SIX_VALUES Procedure:** `docs/SIX_VALUES_PROCEDURE.md` - Compare frontend vs backend when verify fails

## Requirements

- **macOS 10.15+** or **iOS 14.0+**
- **Xcode 14.0+**
- **Swift 5.7+**
- **Physical iOS device** (for test app - App Attest does not work in simulator)

## Building

```bash
# Build from Xcode
open AppAttestDecoderCLI.xcodeproj

# Or from command line
xcodebuild -project AppAttestDecoderCLI.xcodeproj -scheme AppAttestDecoderCLI build
```

## Testing

```bash
# Run all tests
xcodebuild test -project AppAttestDecoderCLI.xcodeproj -scheme AppAttestDecoderCLI
```

See `docs/PROJECT_STATUS.md` for complete test coverage details.

## Stability Guarantees

**CLI flags:** Stable. Flags will not change in breaking ways.

**JSON field names:** Versioned. See `docs/JSON_EXPORT_CONTRACT.md` for stable vs best-effort fields.

**Semantics:** Best-effort. Decoded fields may change encoding or meaning across iOS versions.

**Apple-private fields:** No guarantees. Undocumented fields are explicitly unstable and may change at any time.

## Protocol Edge Cases

**Flag Inconsistencies**: In some App Attest assertions, the AT (attested credential data) flag may be set even though no attested credential data is present in the authenticatorData structure. This inspector treats authenticatorData length as authoritative and reports flag inconsistencies when they occur. Flags are advisory; structure is authoritative.

## Common Misinterpretations

**"Opaque ≠ invalid"** - Opaque means the decoder cannot interpret the structure, not that it's broken. Apple-signed receipts are valid even if their payload is not decodable.

**"Diff showing change ≠ fraud"** - Differences are normal (key rotation, OS upgrades, certificate rotation). Diff shows what changed, not whether change is acceptable.

**"Same bundle ID ≠ same identity"** - Different artifacts may reference different App Attest keys, depending on how the app chose to generate them. Same bundle ID prefix does not mean same cryptographic identity.

**"Decoded ≠ stable or semantically complete"** - Decoding reflects current structure, not full identity semantics. Apple may add entitlement-dependent fields or change encodings across iOS versions.

**"Stable ≠ safe to rely on"** - Even stable fields require server-side verification. This tool does not verify cryptographic signatures or certificate chains.

## License

See `LICENSE` file.

---

**Status:** Stable for inspection and analysis workflows. See `docs/PROJECT_STATUS.md` for complete assessment.

**Important:** "Stable" refers to API stability and parsing correctness, not security guarantees. This tool performs inspection only and must not be used to make authorization decisions.
