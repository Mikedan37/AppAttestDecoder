# App Attest Decoder CLI

A Swift library and command-line tool for **inspecting Apple App Attest attestation and assertion artifacts**.

This project provides a **decoder-only** implementation that parses CBOR, ASN.1, COSE, and X.509 structures and exposes raw materials for downstream validation.  
It performs **no cryptographic verification, certificate validation, or trust decisions**.

## When to Use This

- Inspect real device-generated App Attest artifacts
- Debug App Attest integration issues
- Build your own validator without reimplementing parsers
- Compare attestations across devices, OS versions, or execution contexts
- Archive and analyze artifacts in CI or research workflows

## What This Tool Does

- Decodes App Attest attestation objects and assertions
- Parses CBOR, ASN.1, COSE, and X.509 structures
- Preserves undocumented and Apple-private fields
- Produces human-readable, forensic, and JSON outputs
- Exposes raw materials (certificates, signatures, authenticator data)

## What This Tool Does Not Do

- ❌ No cryptographic verification
- ❌ No certificate chain validation
- ❌ No policy or trust decisions
- ❌ No DeviceCheck or App Attest API calls

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

# Forensic view (evidence-preserving) - RECOMMENDED
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
- **2** - Structurally valid but partial decode (reserved)
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

**Note:** The CLI must be run from Xcode (via scheme arguments) due to framework rpath requirements. See `docs/SCHEME_ARGUMENTS.md` for setup.

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

## Examples

- **End-to-End Workflow:** `examples/end_to_end_inspection_workflow/` - Complete flow from generation to validator handoff
- **Single Attestation:** `examples/single_attestation/` - Inspect one attestation using all output modes
- **Multiple Attestations:** `examples/multiple_attestations/` - Store and index attestations for lifecycle tracking
- **Diffing:** `examples/diffing/` - Compare attestations and interpret differences
- **iOS Test App:** `examples/ios_test_app/` - On-device inspection integration (debugging only)
- **CI Pipeline:** `examples/ci_pipeline/` - Safe CI integration patterns
- **Extension vs App:** `examples/extension_vs_app/` - Compare main app vs extension attestations

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

## Common Misinterpretations

**"Opaque ≠ invalid"** - Opaque means the decoder cannot interpret the structure, not that it's broken. Apple-signed receipts are valid even if their payload is not decodable.

**"Diff showing change ≠ fraud"** - Differences are normal (key rotation, OS upgrades, certificate rotation). Diff shows what changed, not whether change is acceptable.

**"Extension ≠ app even with same bundle ID"** - Extensions generate separate App Attest keys. Same bundle ID prefix does not mean same identity.

**"Decoded ≠ stable"** - Decoded fields are parsed from current structure. Apple may change encoding or semantics in future iOS versions.

**"Stable ≠ safe to rely on"** - Even stable fields require server-side verification. This tool does not verify cryptographic signatures or certificate chains.

## License

See `LICENSE` file.

---

**Status:** Production-ready. See `docs/PROJECT_STATUS.md` for complete assessment.
