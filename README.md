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
- **Educational**: Helps understand the structure of App Attest artifacts  

### What This Tool Is NOT

- **A Validator**: Does NOT verify cryptographic signatures  
- **A Security Tool**: Does NOT perform certificate chain validation  
- **A Production Validator**: Does NOT verify RP ID hashes or nonces  
- **A DeviceCheck Client**: Does NOT call DeviceCheck APIs or generate attestations  

**Important**: This tool only decodes structure. For production use, you must implement complete server-side validation as described in the [Security Notes](#security-notes) section.

## Components

### AppAttestCore Framework

The core decoding library that provides:

- **CBOR Decoder**: Parses Concise Binary Object Representation (CBOR) data structures
- **Attestation Object Decoder**: Decodes full attestation objects containing format, authenticator data, and attestation statements
- **Authenticator Data Parser**: Extracts and parses authenticator data including flags, RP ID hash, and credential data
- **Attestation Statement Parser**: Extracts certificate chains (x5c) and signature data from attestation statements
- **X.509 Certificate Parser**: Parses DER-encoded X.509 certificates from the attestation chain (note: does not perform certificate chain validation)
- **COSE Sign1 Decoder**: Handles CBOR Object Signing and Encryption (COSE) structures

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

**Note**: The CLI `attest` command only parses and displays the structure of attestation objects. It does **not** validate signatures, certificates, or perform security checks. For production validation, see the [Security Notes](#security-notes) section.

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

**Note**: The CLI `assert` command only parses and displays the structure of assertion objects. It does **not** validate signatures, certificates, or perform security checks. For production validation, see the [Security Notes](#security-notes) section.

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

**Note**: The `decodeAttestationObject` and `decodeAssertion` methods only parse the CBOR structure and extract fields. They do **not** verify cryptographic signatures, validate certificate chains, or perform any security checks. See the [Security Notes](#security-notes) section for required validation steps.

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

- **This tool only decodes artifacts; it does not validate cryptographic signatures or certificate chains**
- **Certificate chain validation is not performed**: The decoder parses DER-encoded X.509 certificates from `attStmt.x5c`, but does not validate them against Apple's App Attest Root CA. For security in production, you must validate the certificate chain following Apple's [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations).
- The decoder does not call DeviceCheck APIs; it only parses already-generated artifacts

## Security Notes

**Critical**: This decoder only parses attestation objects. It does not perform any security validation. For production use, you must implement complete server-side validation as described below.

> **See also**: Apple's official [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations) for complete validation requirements and best practices.

### Quick Reference: Production Validation Checklist

| Step | Requirement | Security Impact |
|------|-------------|-----------------|
| Format validation | Verify `fmt == "apple-appattest"` | Prevents invalid format acceptance |
| RP ID hash verification | SHA256(bundle ID) must match `authData.rpIdHash` | Ensures attestation is for your app |
| Certificate chain validation | Validate `attStmt.x5c` against Apple's App Attest Root CA | Prevents forged attestations |
| Signature verification | Verify attestation signature using validated certificate | Ensures data integrity |
| Nonce/challenge verification | Compare SHA256(authData + clientDataHash) with certificate extension OID 1.2.840.113635.100.8.2 | **Prevents replay attacks** |
| Challenge uniqueness | Each challenge must be used only once | **Prevents replay attacks** |
| Team ID validation | Verify certificate chain corresponds to expected Team ID | Ensures attestation is from your team |

### Certificate Chain Validation

Certificate chain validation must be performed using **Apple's App Attest Root CA** as the trust anchor. The certificate chain in `attStmt.x5c` must be validated against Apple's trusted root certificate before any cryptographic verification. This is a fundamental security requirement - without proper certificate chain validation, an attacker could present a forged attestation.

Apple's App Attest Root CA certificate is publicly available and should be used as the sole trust anchor for validating App Attest certificate chains. Do not accept certificate chains that do not validate against this root.

### Replay Attack Prevention

The nonce/challenge validation step is **essential for preventing replay attacks**. Apple's validation process requires:

1. **Generate a unique server challenge** for each attestation request (never reuse challenges)
2. **Compute `clientDataHash`** as SHA256 of your server challenge
3. **Compute `nonce`** as SHA256(authData + clientDataHash)
4. **Extract the nonce** from the attestation certificate extension (OID 1.2.840.113635.100.8.2)
5. **Compare** the computed nonce with the extracted nonce - they must match exactly

This ensures that:
- The attestation was generated in response to your specific challenge
- The attestation cannot be replayed from a previous request
- The authenticator data corresponds to the challenge you issued

**Never skip nonce validation** - it is a critical security control that prevents attackers from reusing old attestations.

### Complete Validation Checklist

For production deployment, ensure your backend validation includes:

- [ ] Format validation: `fmt == "apple-appattest"`
- [ ] RP ID hash verification: SHA256(bundle identifier) matches `authData.rpIdHash`
- [ ] Certificate chain validation: Validate `attStmt.x5c` against Apple's App Attest Root CA
- [ ] Cryptographic signature verification: Verify attestation signature using the validated certificate chain
- [ ] Nonce/challenge verification: Compare SHA256(authData + clientDataHash) with certificate extension OID 1.2.840.113635.100.8.2
- [ ] Challenge uniqueness: Ensure each challenge is used only once (implement challenge tracking/expiration)
- [ ] Team ID validation: Verify the certificate chain corresponds to your expected Team ID

Refer to Apple's [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations) for complete validation requirements.

### Security Best Practices

**Logging Sensitive Data**: Attestation objects contain device-specific information and cryptographic material. Avoid logging raw attestation data, certificate contents, or authenticator data in production logs. If logging is necessary for debugging, use sanitized representations (e.g., hash values, certificate fingerprints) and ensure logs are properly secured and access-controlled.

## Use Cases

### Backend Validation

The decoder can be integrated into backend services to validate App Attest artifacts. After decoding, you must perform additional validation steps as outlined in Apple's documentation:

```swift
// In your backend service
let decoder = AppAttestDecoder(teamID: expectedTeamID)
let attestation = try decoder.decodeAttestationObject(attestationData)

// Step 1: Validate structure
guard attestation.format == "apple-appattest" else { throw ValidationError() }

// Step 2: Verify RP ID Hash
// The RP ID hash in authData must match SHA256 of your app's bundle identifier
let expectedRPIDHash = SHA256.hash(data: "com.yourcompany.yourapp".data(using: .utf8)!)
guard attestation.authenticatorData.rpIdHash == expectedRPIDHash else { 
    throw ValidationError("RP ID hash mismatch") 
}

// Step 3: Validate certificate chain
// CRITICAL: Validate certificate chain against Apple's App Attest Root CA as trust anchor
let certificates = attestation.attestationStatement.x5c
// ... perform X.509 certificate chain validation using Apple's App Attest Root CA
// ... verify signature using the validated leaf certificate

// Step 4: Verify nonce/challenge (CRITICAL for replay attack prevention)
// Construct: nonce = SHA256(authData + clientDataHash)
// where clientDataHash = SHA256 of your unique server challenge
// IMPORTANT: Each challenge must be unique and used only once
let clientDataHash = SHA256.hash(data: uniqueServerChallenge.data(using: .utf8)!)
let authData = attestation.authenticatorData.rawData
let computedNonce = SHA256.hash(data: authData + clientDataHash)

// Extract nonce from attestation certificate extension (OID 1.2.840.113635.100.8.2)
// Compare extracted nonce with computed nonce - they must match exactly
// ... extract nonce from certificate extension and compare
guard extractedNonce == computedNonce else {
    throw ValidationError("Nonce mismatch - possible replay attack")
}

// Step 5: Mark challenge as used (prevent replay)
// ... record that this challenge has been used and cannot be reused
```

**Important**: The decoder only handles parsing. Full server validation requires:
1. Certificate chain validation against Apple's App Attest Root CA (as the trust anchor)
2. Cryptographic signature verification using the validated certificate chain
3. RP ID hash verification (SHA256 of bundle identifier)
4. Nonce/challenge verification (comparing SHA256(authData + clientDataHash) with certificate extension) - **essential for replay attack prevention**
5. Challenge tracking to ensure each challenge is used only once

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

**Important**: The test app is a separate tool used to generate artifacts. This decoder CLI only parses the generated artifacts; it does not generate them or perform validation.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines on how to contribute, including:
- Project scope (what's in-scope vs out-of-scope)
- How to add tests
- Code style guidelines
- Development setup

**Important**: This project is a decoder only. It does not perform cryptographic validation. See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for details on what contributions are appropriate.

## Documentation

- [docs/HOW_TO_USE.md](docs/HOW_TO_USE.md) - Complete CLI usage guide
- [docs/TEST_APP_GUIDE.md](docs/TEST_APP_GUIDE.md) - Guide for using companion test apps
- [docs/QA_FLOW.md](docs/QA_FLOW.md) - Quality assurance procedures
- [docs/PROJECT_AUDIT.md](docs/PROJECT_AUDIT.md) - Complete project audit and status
- [CHANGELOG.md](CHANGELOG.md) - Version history and release notes

