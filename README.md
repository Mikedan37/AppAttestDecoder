# App Attest Decoder CLI

A Swift-based command-line tool and library for decoding Apple App Attest attestation objects and assertions. This project provides a complete decoder implementation that can parse CBOR-encoded App Attest artifacts without requiring DeviceCheck framework dependencies.

## Overview

Apple App Attest is a framework that allows iOS apps to cryptographically attest to the authenticity of their app and device. This decoder tool can parse the attestation objects and assertions produced by App Attest, making it useful for:

- Backend validation of App Attest artifacts
- Debugging and inspection of attestation data
- Integration into CI/CD pipelines for automated validation
- Educational purposes to understand App Attest structure

### What This Tool Is

- **A Decoder**: Parses CBOR-encoded App Attest structures and extracts their components  
- **A CLI Tool**: Command-line interface for inspecting attestation objects and assertions  
- **A Library**: Swift framework that can be integrated into other projects  
- **Raw Materials Provider**: Exposes all parsed data needed for validator consumption without duplicate parsing  
- **Educational**: Helps understand the structure of App Attest artifacts  

### What This Tool Is NOT

- **A Validator**: Does NOT verify cryptographic signatures  
- **A Security Tool**: Does NOT perform certificate chain validation  
- **A Production Validator**: Does NOT verify RP ID hashes or nonces  
- **A DeviceCheck Client**: Does NOT call DeviceCheck APIs or generate attestations  

This tool only decodes structure. For production validation, see [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md).

## Components

### AppAttestCore Framework

The core decoding library that provides:

- **CBOR Decoder**: Parses Concise Binary Object Representation (CBOR) data structures
- **Attestation Object Decoder**: Decodes full attestation objects containing format, authenticator data, and attestation statements
- **Authenticator Data Parser**: Extracts and parses authenticator data including flags, RP ID hash, and credential data
- **Attestation Statement Parser**: Extracts certificate chains (x5c) and signature data from attestation statements
- **X.509 Certificate Parser**: Parses DER-encoded X.509 certificates from the attestation chain (note: does not perform certificate chain validation)
- **COSE Sign1 Decoder**: Handles CBOR Object Signing and Encryption (COSE) structures
- **Raw Materials API**: Exposes all parsed data (signatures, certificates, authenticator data bytes) for validator consumption without duplicate parsing

### Command-Line Interface

A minimal CLI tool (`AppAttestDecoderCLI`) that provides:

- Decoding of attestation objects from base64 input
- Decoding of assertion objects
- Multiple input methods (STDIN, file, command-line argument)
- Output formats (hex dump, raw base64, JSON)

### Test Suite

Comprehensive unit tests covering:

- Valid attestation object decoding
- Error handling for truncated data
- Missing required field detection
- Integer key fallback logic (Apple's non-standard CBOR encoding)
- Certificate chain extraction
- Authenticator data flag validation
- Invalid CBOR error handling

## Usage

### Command-Line Interface

The CLI supports three modes:

#### Decode Attestation Object

```bash
# From STDIN
echo "BASE64_ATTESTATION_STRING" | ./AppAttestDecoderCLI attest

# From command-line argument
./AppAttestDecoderCLI attest --base64 "BASE64_ATTESTATION_STRING"

# From file
./AppAttestDecoderCLI attest --file attestation.txt

# With hex dump output
./AppAttestDecoderCLI attest --hex --base64 "BASE64_STRING"

# With JSON output
./AppAttestDecoderCLI attest --json --base64 "BASE64_STRING"
```

**Note**: The CLI `attest` command only parses structure. For production validation, see [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md).

#### Decode Assertion

```bash
# From command-line argument
./AppAttestDecoderCLI assert --base64 "BASE64_ASSERTION_STRING"

# From file
./AppAttestDecoderCLI assert --file assertion.txt

# With hex dump output
./AppAttestDecoderCLI assert --hex --base64 "BASE64_STRING"

# With JSON output
./AppAttestDecoderCLI assert --json --base64 "BASE64_STRING"

# Pretty-print assertion (default)
./AppAttestDecoderCLI assert --base64 "BASE64_STRING"
```

**Note**: The CLI `assert` command only parses structure. For production validation, see [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md).

#### Self-Test

```bash
./AppAttestDecoderCLI selftest
```

#### Version

```bash
./AppAttestDecoderCLI --version
# or
./AppAttestDecoderCLI -V
```

## Installation

### Swift Package Manager

The `AppAttestCore` framework can be used as a library via Swift Package Manager.

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AppAttestDecoderCLI.git", from: "1.0.0")
]
```

Or add via Xcode: File → Add Packages → Enter the repository URL.

#### Usage Example

```swift
import AppAttestCore

let decoder = AppAttestDecoder(teamID: "YOUR_TEAM_ID")

// Decode attestation object (parsing only - does not validate signatures or certificates)
let attestationData = Data(base64Encoded: base64String)!
let attestation = try decoder.decodeAttestationObject(attestationData)

// Access parsed data
print("Format: \(attestation.format)")
print("RP ID Hash: \(attestation.authenticatorData.rpIdHash)")
print("Certificate Count: \(attestation.attestationStatement.x5c.count)")

// Decode assertion object
let assertionData = Data(base64Encoded: assertionBase64String)!
let assertion = try decoder.decodeAssertion(assertionData)
print("Algorithm: \(assertion.algorithm ?? -1)")
print("Signature: \(assertion.signature.count) bytes")
```

**Note**: The `decodeAttestationObject` and `decodeAssertion` methods only parse structure. All raw materials (signatures, certificates, authenticator data) are exposed for validator consumption. For production validation, see [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md).

## Testing

### Running Tests

Tests are located in `AppAttestCoreTests` and can be run via Xcode:

1. Open `AppAttestDecoderCLI.xcodeproj` in Xcode
2. Select the `AppAttestCoreTests` scheme
3. Press Command+U to run all tests

Or via command line:

```bash
xcodebuild test -scheme AppAttestCore -destination 'platform=macOS'
```

### Test Coverage

The test suite includes the following test methods:

#### testDecodeAttestationObject

Validates decoding of a complete, device-generated attestation object. This test:
- Verifies base64 decoding
- Validates data completeness (typically 800-1500+ bytes)
- Checks for CBOR truncation errors
- Asserts structural correctness (format, authenticator data, certificate chain)

#### testDecodeTruncatedCBOR

Tests error handling when CBOR data is incomplete. This test:
- Truncates valid attestation data
- Verifies `CBORDecodingError.truncated` is thrown
- Validates error contains diagnostic information (expected bytes, remaining bytes, offset)

#### testDecodeMissingRequiredFields

Tests error handling when required fields are missing. This test:
- Constructs minimal CBOR maps missing `authData` or `fmt` fields
- Verifies `AttestationError.missingRequiredField` is thrown
- Validates error message includes available keys for debugging

#### testDecodeIntegerKeyFallback

Tests fallback logic for Apple's non-standard CBOR encoding. This test:
- Manually constructs CBOR with `authData` under a negative integer key (-791634803)
- Verifies decoder correctly extracts authenticator data from integer keys
- Validates the decoder handles Apple's encoding quirks where fields may appear under integer keys instead of text string keys

#### testAttStmtX5cExtraction

Tests certificate chain extraction from attestation statements. This test:
- Verifies x5c array is non-empty
- Validates certificate sizes are reasonable (100-10000 bytes)
- Checks leaf certificate is substantial (typically 1000+ bytes)

#### testAuthenticatorDataFlags

Tests authenticator data flag semantics. This test:
- Verifies flags are not all zero
- Asserts `attestedCredentialData` flag is set (required for attestations)
- Validates flag properties are readable (userPresent, userVerified, extensionsIncluded)

#### testDecodeInvalidCBOR

Tests error handling for malformed CBOR data. This test:
- Tests invalid initial bytes
- Tests random garbage data
- Tests empty data
- Verifies errors are properly typed (CBORDecodingError or AttestationError)

#### testDecodeKeyIDBase64

Validates base64 decoding of key IDs used in App Attest.

### Test Data

The test suite uses real device-generated attestation objects captured from `AppAttestDecoderTestApp`. To update test data:

1. Run `AppAttestDecoderTestApp` on a real iOS device (iOS 14+)
2. Generate a key and tap "Attest Key"
3. Copy the complete base64 attestation blob
4. Replace `attestationObjectBase64` in `AppAttestCoreTests.swift`

## Architecture

### Decoding Pipeline

1. **Input**: Base64-encoded attestation object or assertion
2. **CBOR Decoding**: Parse CBOR structure into `CBORValue` tree
3. **Structure Extraction**: Extract map pairs and identify keys
4. **Field Resolution**: 
   - Try standard text string keys first ("fmt", "authData", "attStmt")
   - Fallback to integer keys for Apple's non-standard encoding
   - Search recursively for byte strings that could be authenticator data
5. **Domain Parsing**: Parse extracted fields into domain objects:
   - AuthenticatorData (flags, RP ID hash, credential data)
   - AttestationStatement (certificate chain, signature)
   - X.509 certificates (DER-encoded)
6. **Raw Materials Exposure**: All parsed data is exposed via public API for validator consumption

### Architecture Pattern

This decoder implements a clean separation between parsing and validation:

```
Device
  ↓
Test App (artifact generator)
  ↓
Decoder (structure, raw materials) ← This project
  ↓
Validator (policy, trust, lifecycle) ← Future work
  ↓
Application logic
```

**Design Principles:**
- **Separation of Concerns**: Decoder only parses structure; validation is separate
- **Raw Materials API**: All parsed data exposed for validator consumption without duplicate parsing
- **No Policy Decisions**: Decoder makes no trust, security, or lifecycle decisions
- **Explicit Boundaries**: Clear documentation of what is and isn't validated
- **Reproducible**: Deterministic parsing with stable error semantics

This pattern enables:
- Shared validation logic without re-implementing parsing
- Consistent error handling and observability
- Clear separation between structure and policy
- Standardized failure semantics across implementations

### Error Handling

The decoder provides detailed error messages:

- **CBORDecodingError.truncated**: Includes expected bytes, remaining bytes, and offset
- **AttestationError.missingRequiredField**: Lists all available keys for debugging
- **CBORDecodingError.invalidInitialByte**: Indicates malformed CBOR structure

### Apple-Specific Encoding Quirks

Apple's App Attest implementation uses some non-standard CBOR encodings that differ from standard WebAuthn CBOR:

- **Negative Integer Keys**: `authData` may appear under a negative integer key (e.g., `-791634803`) instead of the standard text string key "authData". This is observed in real Apple attestation objects and is not part of the standard WebAuthn specification.
- **Nested Arrays**: Byte strings may be wrapped in arrays rather than appearing as direct values
- **Tagged Values**: CBOR tags may wrap the entire structure

The decoder handles these cases through:
1. Primary lookup using standard text string keys ("fmt", "authData", "attStmt")
2. Fallback search through all map pairs for integer keys when text keys are not found
3. Recursive byte string extraction from nested structures (arrays, tagged values)
4. Selection of largest valid byte string candidate (>= 37 bytes) when multiple candidates exist

This fallback logic is necessary because Apple's implementation sometimes encodes fields using integer keys rather than text keys, which requires the decoder to go beyond "text keys only" parsing.

## Version

Current version: **1.0.0**

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

### Generating Test Attestations (Companion Test App)

To generate real App Attest attestation and assertion objects for testing, you need a companion test app running on a physical Apple device. This decoder CLI can then parse the artifacts generated by such an app.

For detailed instructions on setting up and using a test app to generate attestations and assertions, see [docs/TEST_APP_GUIDE.md](docs/TEST_APP_GUIDE.md).

**Note**: The test app is a separate tool used to generate artifacts. This decoder CLI only parses the generated artifacts; it does not generate them.

### Building the CLI

To build the command-line tool from source:

1. Clone this repository
2. Open `AppAttestDecoderCLI.xcodeproj` in Xcode
3. Select the `AppAttestDecoderCLI` scheme
4. Build (Command+B) or Run (Command+R)

Or build from the command line:

```bash
xcodebuild -scheme AppAttestDecoderCLI -configuration Release
```

The binary will be created at `build/Release/AppAttestDecoderCLI`.

## Requirements

- macOS 10.15+ or iOS 14+
- Xcode 14+ (Swift 5.7+)
- No external dependencies (pure Swift implementation)

## Project Structure

```
AppAttestDecoderCLI/
├── AppAttestCore/              # Core decoding framework
│   ├── ASN1/                   # ASN.1/DER parsing
│   ├── CBOR/                   # CBOR decoding
│   ├── COSE/                   # COSE Sign1 parsing
│   ├── Attestation/            # App Attest domain objects
│   └── X509/                   # X.509 certificate parsing
├── AppAttestCoreTests/         # Unit tests
├── AppAttestDecoderCLI/        # Command-line interface
└── AppAttestDecoderTestApp/    # iOS test app for generating artifacts
```

## Limitations

This tool only decodes structure. It does not validate cryptographic signatures, certificate chains, or perform security checks. The decoder does not call DeviceCheck APIs; it only parses already-generated artifacts.

For production validation requirements, see [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md).

## Security Notes

This decoder only parses structure. It does not perform cryptographic validation, certificate chain verification, or security checks.

All raw materials needed for validation (signatures, certificate chains, authenticator data bytes, RP ID hashes) are exposed via the public API. A validator can consume these without re-parsing the original bytes.

For production use, implement complete server-side validation. See [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md) for the full validation checklist and Apple's [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations) for official requirements.

## Use Cases

### Backend Validation

The decoder can be integrated into backend services to parse App Attest artifacts. After decoding, implement complete server-side validation.

See [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md) for the full validation checklist and example implementation.

### CI/CD Integration

The decoder can be used in automated pipelines to validate test artifacts:

```bash
# In your CI script
ATTESTATION=$(cat test_attestation.txt)
./AppAttestDecoderCLI attest --base64 "$ATTESTATION" || exit 1
```

### Debugging

The CLI provides hex dump and JSON output for inspecting attestation structure:

```bash
./AppAttestDecoderCLI attest --hex --json --base64 "$ATTESTATION"
```

### End-to-End Testing with a Test App

To test the decoder with real App Attest artifacts, you need a companion test app running on a physical Apple device. The test app generates attestation and assertion objects that can then be decoded using this CLI tool.

For complete instructions on:
- Setting up a test app with App Attest capability
- Generating attestation and assertion objects
- Using the CLI to decode and inspect the generated artifacts

See [docs/TEST_APP_GUIDE.md](docs/TEST_APP_GUIDE.md).

The test app is a separate tool used to generate artifacts. This decoder CLI only parses the generated artifacts.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines on how to contribute, including:
- Project scope (what's in-scope vs out-of-scope)
- How to add tests
- Code style guidelines
- Development setup

This project is a decoder only. It does not perform cryptographic validation. See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for details.

## Documentation

- [docs/HOW_TO_USE.md](docs/HOW_TO_USE.md) - Complete CLI usage guide
- [docs/TEST_APP_GUIDE.md](docs/TEST_APP_GUIDE.md) - Guide for using companion test apps
- [docs/RESEARCH.md](docs/RESEARCH.md) - Research methodology and observables
- [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md) - Production validation checklist
- [docs/QA_FLOW.md](docs/QA_FLOW.md) - Quality assurance procedures
- [docs/PROJECT_AUDIT.md](docs/PROJECT_AUDIT.md) - Complete project audit and status
- [CHANGELOG.md](CHANGELOG.md) - Version history and release notes

## Research Context

This project is part of an ongoing research effort to understand how Apple App Attest behaves across different execution contexts. The goal is observability, not validation or policy enforcement. For detailed methodology and findings, see [docs/RESEARCH.md](docs/RESEARCH.md).

**This project includes a research module for studying how App Attest artifacts differ when generated from non-primary execution contexts such as Action Extensions and App SSO flows.** See [docs/EXTENSION_SETUP.md](docs/EXTENSION_SETUP.md) for setup instructions.

## Studying App Attest Across iOS Execution Contexts

This project supports annotation and provenance tracking of App Attest artifacts generated from different iOS execution contexts, including:

- Main application
- Action extensions
- UI extensions
- App SSO extensions

### Important Research Context

**Apple App Attest uses the exact same attestation format and flow regardless of execution context.** Extensions share the same App ID prefix and Team ID as the container app. The attestation object structure is identical across all contexts - it's just gated differently.

This research capability enables:
- **Execution context annotation**: Tracking where artifacts originate (context metadata)
- **Provenance tracking**: Associating artifacts with their generation context
- **Structural verification**: Confirming artifacts are structurally identical across contexts
- **Comparative analysis**: Studying consistency rather than differences

**Note**: This is about context annotation and provenance, not finding structural differences. The artifacts themselves are identical.

### Research Architecture

The project models each execution context as a distinct trust surface with its own cryptographic identity. This aligns with how Apple treats execution contexts as distinct security principals.

**Trust Surface Model**:
- Each target (main app, action extension, App SSO extension) generates its own App Attest key
- Each target produces its own attestations/assertions independently
- No keys are shared. No identity is unified. This is trust-surface mapping, not identity merging.

The project provides:

1. **Context Annotation Layer** (`AttestationContext`, `AttestationSample`):
   - Wraps decoded attestations with execution context metadata
   - Enables provenance tracking while maintaining research-grade isolation
   - Context is metadata only; attestation structure is unchanged

2. **Analysis Mode** (CLI `analyze` command):
   - Compares multiple `AttestationSample` entries
   - Highlights RP ID hash consistency, certificate chain patterns, and flag differences
   - Outputs human-readable or JSON analysis results

3. **Research Framing**:
   - Uses research language: "execution context", "trust envelope", "observed behavior"
   - Explicitly states: no validation, no security claims, contextual differences only
   - Focuses on where trust signals originate, not enforcing them

### Usage

```bash
# Analyze multiple samples across execution contexts
./AppAttestDecoderCLI analyze --file samples.json

# Output as JSON for programmatic analysis
./AppAttestDecoderCLI analyze --file samples.json --json
```

The samples JSON file should contain an array of `AttestationSample` objects with context, bundle ID, team ID, key ID, and base64 attestation data.

**Note**: This is a research tool. It does not validate trust or make security claims. All validation must be implemented separately.

## Related Work

This decoder is designed to be consumed by separate validator implementations. The architecture separates parsing (this project) from validation (future work), enabling:

- Shared parsing logic without re-implementation
- Consistent error semantics across validators
- Clear boundaries between structure and policy
- Standardized failure handling

For validator implementations, see the [Raw Materials API](#architecture) section and [docs/SECURITY_VALIDATION.md](docs/SECURITY_VALIDATION.md).

