# App Attest Decoder CLI

A Swift-based decoder and inspection tool for Apple App Attest attestation objects and assertions. Parses CBOR, ASN.1, X.509, and COSE structures to expose raw materials for downstream validation.

## If This Is Your First Time Here

1. Read `docs/WHAT_THIS_TOOL_IS.md` to understand scope and boundaries
2. Run `examples/single_attestation/inspect.sh` with a real attestation to see output
3. Read `examples/extension_vs_app/README.md` to understand execution context differences
4. Stop. Do not use this to gate requests.

This tool is for inspection and analysis only. All verification must be implemented separately on your server.

## What This Tool Does

- Decodes Apple App Attest attestation and assertion objects
- Parses CBOR, ASN.1, COSE, and X.509 certificate structures
- Exposes raw materials (signatures, certificates, authenticator data) for downstream validation
- Supports CLI usage and Swift library integration
- Provides multiple output modes: semantic (human-readable), forensic (evidence-preserving), lossless tree (complete dump)
- Handles malformed input gracefully with failsafe configuration

## What This Tool Does NOT Do

- **No cryptographic verification** - Signatures are parsed, not verified
- **No certificate chain validation** - Certificates are decoded, not validated against Apple's root CA
- **No trust or policy decisions** - This is inspection, not validation
- **No DeviceCheck / App Attest API calls** - This tool only decodes artifacts, it does not generate them
- **No production security guarantees** - Verification must be implemented separately on your server

**This is a decoder and inspection instrument, not a validator.**

## When You Would Use This

- Debugging App Attest integration failures
- Inspecting real device-generated attestation artifacts
- Building your own validator without re-implementing CBOR/ASN.1 parsing
- CI/CD pipelines for artifact analysis
- Research and corpus building
- Forensic investigation of trust artifacts

## Architecture Overview

```
Device
  ↓
Attestation Artifact
  ↓
[ THIS TOOL ]
  ↓
Parsed Evidence
  ↓
Your Validator
  ↓
Policy / Trust
```

**Separation of concerns:**
- **Inspection** (this tool): Structural parsing, field extraction, evidence preservation
- **Interpretation** (this tool): Semantic meaning with confidence levels, no false certainty
- **Verification** (your code): Cryptographic validation, certificate chain validation, policy enforcement

The decoder provides raw materials. You implement verification.

**Why this is inspection, not verification:**
- This tool parses structure and exposes evidence
- Your validator performs cryptographic checks and makes policy decisions
- Mixing these concerns creates false certainty and hidden failures

## CLI Usage

### Start Here

**If you only run one command, run this:**

```bash
pretty --forensic --file /path/to/attestation.b64
```

This provides the best balance of human-readable decoded fields and evidence-preserving raw data.

### Basic Inspection

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

**Note:** JSON output is best-effort and versioned. Do not build hard guarantees on unstable fields. See `docs/JSON_EXPORT_CONTRACT.md` for field stability details.

### Exit Codes

The CLI uses standard exit codes for scripting and CI:

- **0** - Decoded successfully
- **1** - Input malformed (invalid base64, missing file, etc.)
- **2** - Structurally valid but partial decode (reserved for future use)
- **3** - Internal error (unexpected exceptions, decoder failures)

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

For complete CLI reference, see `docs/COMMAND_REFERENCE.md`.

## Library Usage (Swift)

```swift
import AppAttestCore

// Decode attestation object
let decoder = AppAttestDecoder(teamID: nil)
let attestation = try decoder.decodeAttestationObject(data)

// Access parsed components
let format = attestation.format
let authData = attestation.authenticatorData
let x5c = attestation.attestationStatement.x5c  // Certificate chain
let signature = attestation.attestationStatement.signature

// Build semantic model for presentation
let model = try attestation.buildSemanticModel()
let printer = SemanticPrinter(colorized: false)
let output = printer.print(model)
```

**Important:** This library performs parsing only. All verification must be implemented separately.

## Project Structure

```
AppAttestCore/              # Core decoding library
├── CBOR/                   # CBOR decoder
├── ASN1/                   # ASN.1/DER parser
├── X509/                   # X.509 certificate parser
├── COSE/                   # COSE Sign1 decoder
└── Attestation/            # App Attest domain objects

AppAttestDecoderCLI/       # CLI tool
└── main.swift              # Command-line interface

AppAttestDecoderTestApp/    # iOS test app (generates artifacts)

docs/                       # Documentation
├── CLI_QUICK_START.md      # Quick reference
├── COMMAND_REFERENCE.md    # Complete CLI docs
├── VERIFICATION_GUIDE.md   # What to verify on server
├── IOS_ON_DEVICE_INSPECTION.md  # Using decoder in iOS app
└── DESIGN_PHILOSOPHY.md    # Design constraints and tradeoffs
```

## Limitations & Boundaries

- **Undocumented fields may change** - Apple-private fields are preserved and labeled, but semantics may drift
- **Decoder preserves data but does not interpret trust** - Unknown fields are marked as opaque, not discarded
- **Verification must happen server-side** - This tool provides raw materials, not security guarantees
- **Schema drift is expected** - The decoder handles unknown structures gracefully but cannot predict future changes

## Common Misinterpretations

**"The receipt being opaque does NOT mean it's invalid"**
- Opaque means the decoder cannot interpret the structure, not that it's broken
- Apple-signed receipts are valid even if their payload is not decodable
- Opaque fields are preserved for audit and future decoding

**"Diff showing change does NOT mean fraud"**
- Differences are normal (key rotation, OS upgrades, certificate rotation)
- Diff shows what changed, not whether change is acceptable
- Acceptability is a policy decision, not an inspection result

**"Extension ≠ app even with same bundle ID"**
- Extensions generate separate App Attest keys and attestations
- Same bundle ID prefix does not mean same identity
- Each execution context has its own cryptographic identity

**"Decoded ≠ stable"**
- Decoded fields are parsed from current structure
- Apple may change encoding or semantics in future iOS versions
- Do not hardcode expectations based on decoded output

**"Stable ≠ safe to rely on"**
- Even stable fields (RP ID hash, flags) require server-side verification
- This tool does not verify cryptographic signatures or certificate chains
- Inspection is separate from validation

## Common Failure Patterns

These patterns cause confusion and can be avoided with proper inspection:

- **OS upgrade changed receipt shape** - Receipt format may change across iOS versions. Use diff to see what changed, don't assume breakage.

- **Extension attestation ≠ app attestation** - Extensions generate separate keys. Same bundle ID does not mean same identity. Compare to see differences.

- **Key rotated but backend assumed static** - Credential IDs change on rotation. Index by credential ID, not device ID.

- **Receipt present but ignored** - Receipts provide additional evidence. Check for presence and structure, even if payload is opaque.

- **Assumed undocumented == invalid** - Undocumented fields are preserved and labeled opaque. They may be valid but not contractually stable.

## Stability Guarantees

**CLI flags:** Stable. Flags will not change in breaking ways.

**JSON field names:** Versioned. See `docs/JSON_EXPORT_CONTRACT.md` for stable vs best-effort fields.

**Semantics:** Best-effort. Decoded fields may change encoding or meaning across iOS versions.

**Apple-private fields:** No guarantees. Undocumented fields are explicitly unstable and may change at any time.

## Examples

Practical workflows for inspection and analysis:

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

**Quick example of what NOT to do:**

```swift
// WRONG: Using decoder output to make security decisions
if decoder.decode(attestation).looksValid {
    allowRequest()  // This is insecure!
}
```

**Why this is wrong:**
- No cryptographic verification
- No policy enforcement  
- No replay protection

The decoder is for **inspection only**. Implement a separate validator for security decisions.

## Documentation

- **Quick Start:** `docs/CLI_QUICK_START.md`
- **What This Tool Is:** `docs/WHAT_THIS_TOOL_IS.md` - Scope and boundaries
- **Enhancement Features:** `docs/ENHANCEMENTS_GUIDE.md` - Extension OIDs, receipt inspection, diffing
- **JSON Export Contract:** `docs/JSON_EXPORT_CONTRACT.md` - Stable fields and integration guidelines
- **Complete CLI Reference:** `docs/COMMAND_REFERENCE.md`
- **Server-Side Verification:** `docs/VERIFICATION_GUIDE.md`
- **iOS Integration:** `docs/IOS_ON_DEVICE_INSPECTION.md`
- **Design Philosophy:** `docs/DESIGN_PHILOSOPHY.md` - Tradeoffs and non-goals
- **Project Status:** `docs/PROJECT_STATUS.md`
- **Test App Guide:** `docs/TEST_APP_GUIDE.md`
- **Security Policy:** `SECURITY.md` - Security boundaries and reporting

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

# Run specific test suite
xcodebuild test -project AppAttestDecoderCLI.xcodeproj -scheme AppAttestDecoderCLI -only-testing:AppAttestCoreTests
```

## License

See `LICENSE` file.

## Contributing

This project accepts contributions. See `docs/CONTRIBUTING.md` for guidelines.

---

**Status:** Production-ready. See `docs/PROJECT_STATUS.md` for complete assessment.
