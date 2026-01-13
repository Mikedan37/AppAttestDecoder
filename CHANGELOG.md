# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Raw Materials API**: All parsed data (signatures, certificates, authenticator data bytes) are now explicitly exposed with documentation for validator consumption
- `AttestationObject.rawData`: Original CBOR bytes for signature verification
- Comprehensive documentation on all exposed properties clarifying they are unvalidated
- Tests verifying raw materials are accessible (`testAttestationRawMaterialsExposed`, `testAssertionRawMaterialsStructure`)

### Changed
- Enhanced property documentation throughout `AppAttestCore` to clarify unvalidated status
- `AttestationObject.init` now accepts optional `rawData` parameter to preserve original bytes

## [1.0.0] - 2026-01-12

### Added

#### Core Framework
- **CBOR Decoder**: Complete CBOR (Concise Binary Object Representation) decoder with support for all major types
- **ASN.1/DER Parser**: Parser for ASN.1 structures encoded in DER format
- **X.509 Certificate Parser**: Extracts certificate fields, extensions, and OIDs from DER-encoded certificates
- **COSE Sign1 Decoder**: Decodes COSE_Sign1 messages (CBOR Object Signing and Encryption)
- **Attestation Object Decoder**: Decodes App Attest attestation objects with support for Apple's non-standard CBOR encoding
- **Assertion Object Decoder**: Decodes App Attest assertion objects (COSE_Sign1 messages)
- **Authenticator Data Parser**: Parses authenticator data including flags, RP ID hash, and credential data
- **Attestation Statement Parser**: Extracts certificate chains (x5c) and signature data

#### CLI Tool
- `attest` command: Decode attestation objects with hex, raw, and JSON output options
- `assert` command: Decode assertion objects with hex, raw, and JSON output options
- `pretty` command: Pretty-print attestation objects with hierarchical formatting and colorization
- `selftest` command: Verify CLI functionality
- `--version` flag: Display version information
- Multiple input methods: `--base64`, `--file`, or STDIN
- TTY detection for automatic colorization
- `--no-color` flag to disable colorization

#### Pretty Printing
- Hierarchical formatting with 2-space indentation
- Hex formatting for byte arrays (spaces every 4 bytes)
- Flag interpretation (raw value + boolean fields)
- Recursive CBOR structure printing
- ANSI colorization support (auto-detected, can be disabled)
- Pretty-print support for both attestation and assertion objects

#### Testing
- Comprehensive unit test suite (25+ test methods)
- Tests for valid attestation decoding
- Tests for error handling (truncated CBOR, missing fields, invalid CBOR)
- Tests for Apple's CBOR quirks (negative integer keys, array-wrapped byte strings)
- Tests for certificate chain extraction
- Tests for authenticator data flags
- Tests for assertion decoding
- Tests for pretty-print functionality

#### Documentation
- Comprehensive README with usage examples, architecture, and security notes
- Detailed HOW_TO_USE.md guide
- Complete QA_FLOW.md checklist
- CONTRIBUTING.md with project scope and contribution guidelines
- LICENSE file (MIT)

#### Distribution
- Swift Package Manager support (Package.swift)
- Xcode project for framework and CLI targets

### Known Limitations

- **No Cryptographic Validation**: This decoder only parses structure. It does NOT:
  - Verify cryptographic signatures
  - Validate certificate chains
  - Verify RP ID hashes
  - Validate nonces/challenges
  - Perform any security checks
  
  Users must implement complete server-side validation following Apple's [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations).

- **Assertion Testing**: Full assertion decoding tests require real device-generated assertion objects. Current tests verify error handling and structure validation.

- **CI/CD**: GitHub Actions workflow is configured but may require code signing setup for test execution.

### Security Notes

**Critical**: This decoder is a parsing tool only. It makes no security guarantees and does not perform validation. For production use, you must:

1. Validate certificate chains against Apple's App Attest Root CA
2. Verify cryptographic signatures using validated certificates
3. Verify RP ID hashes match your bundle identifier
4. Validate nonces/challenges to prevent replay attacks
5. Track challenge uniqueness to prevent reuse

See the [Security Notes](README.md#security-notes) section in README.md for complete validation requirements.

---

[1.0.0]: https://github.com/yourusername/AppAttestDecoderCLI/releases/tag/v1.0.0

