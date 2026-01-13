# AppAttestDecoder v1.0.0 Release Notes

## What It Is

AppAttestDecoder is a Swift library and command-line tool for decoding Apple App Attest attestation and assertion artifacts. It parses CBOR-encoded structures and extracts their components into readable formats (JSON, pretty-print, hex dump).

## What It Is NOT

- **A Validator**: Does NOT verify cryptographic signatures
- **A Security Tool**: Does NOT perform certificate chain validation
- **A Production Validator**: Does NOT verify RP ID hashes or nonces
- **A Complete Parser**: The internal ASN.1, CBOR, COSE, and X.509 parsers are purpose-built for App Attest artifacts only, not general-purpose use

This tool only decodes structure. For production use, you must implement complete server-side validation as described in Apple's [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations).

## Supported Inputs

- **Attestation Objects**: Full App Attest attestation objects
- **Assertion Objects**: App Attest assertion objects (COSE_Sign1 messages)
- **Input Methods**: Base64 string, file, or STDIN
- **Output Formats**: JSON, hex dump, raw base64, or pretty-print

## Features

- CBOR decoding with support for Apple's non-standard encoding patterns
- X.509 certificate extraction (parsing only, no validation)
- Authenticator data parsing
- Pretty-printing with optional colorization
- Swift Package Manager support
- Comprehensive test suite (28+ test methods)
- Complete documentation

## Documentation

- [README.md](README.md) - Project overview and usage
- [docs/HOW_TO_USE.md](docs/HOW_TO_USE.md) - Complete CLI usage guide
- [docs/TEST_APP_GUIDE.md](docs/TEST_APP_GUIDE.md) - Guide for using companion test apps
- [docs/QA_FLOW.md](docs/QA_FLOW.md) - Quality assurance procedures
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) - Contribution guidelines
- [SECURITY.md](SECURITY.md) - Security policy and vulnerability reporting

## Security Note

**Non-Official Parser Scope**: The ASN.1, CBOR, COSE, and X.509 parsing logic in this project is NOT a complete implementation of the respective standards, is NOT a reference parser, and is NOT intended for general-purpose use. These parsers exist solely to decode structures required for App Attest artifacts. They do not perform cryptographic verification or enforce trust decisions.

This project is not affiliated with or endorsed by Apple.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Mikedan37/AppAttestDecoder.git", from: "1.0.0")
]
```

### From Source

```bash
git clone https://github.com/Mikedan37/AppAttestDecoder.git
cd AppAttestDecoder
xcodebuild -scheme AppAttestDecoderCLI -configuration Release
```

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Release Date**: January 12, 2026  
**Version**: 1.0.0

