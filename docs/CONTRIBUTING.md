# Contributing to AppAttestDecoderCLI

Thank you for your interest in contributing to AppAttestDecoderCLI!

## Project Scope

This project is a **decoder** for Apple App Attest attestation objects and assertions. It parses CBOR-encoded structures and extracts their components, but does **not** perform cryptographic validation.

### In-Scope

- Parsing and decoding CBOR structures
- Extracting fields from attestation objects and assertions
- Pretty-printing decoded structures
- Error handling and diagnostics
- CLI tools for inspection and debugging
- Documentation improvements
- Test coverage improvements
- Performance optimizations (parsing only)

### Out-of-Scope

- **Cryptographic signature verification** - This is intentionally excluded. Users must implement validation separately.
- **Certificate chain validation** - This is intentionally excluded. Users must validate certificates against Apple's Root CA.
- **RP ID hash verification** - This is intentionally excluded. Users must verify RP ID hashes match their bundle IDs.
- **Nonce/challenge validation** - This is intentionally excluded. Users must implement replay attack prevention.
- **Security claims or validation logic** - This decoder makes no security guarantees. It only parses structure.

**Why?** This project is designed to be a **parsing library**, not a validation framework. Security validation requires server-side implementation with proper certificate chain validation, signature verification, and challenge tracking. These responsibilities are explicitly out of scope to keep the decoder focused and avoid security liability.

## How to Contribute

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Provide clear reproduction steps
3. Include relevant error messages and stack traces
4. Specify your environment (macOS version, Xcode version, Swift version)

### Submitting Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**:
   - Follow existing code style
   - Add tests for new functionality
   - Update documentation as needed
4. **Run tests**: Ensure all tests pass
   ```bash
   xcodebuild test -scheme AppAttestCore -destination 'platform=macOS'
   ```
5. **Commit your changes**: Use clear, descriptive commit messages
6. **Push to your fork**: `git push origin feature/your-feature-name`
7. **Open a Pull Request**: Provide a clear description of changes

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small
- Prefer clarity over cleverness

### Testing

All contributions must include tests:

- **Unit tests** for new parsing logic
- **Error handling tests** for edge cases
- **Integration tests** for CLI commands (if applicable)

To run tests:
```bash
# Run all tests
xcodebuild test -scheme AppAttestCore -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme AppAttestCore -destination 'platform=macOS' -only-testing:AppAttestCoreTests/testName
```

### Adding New Tests

1. Add test methods to `AppAttestCoreTests/AppAttestCoreTests.swift`
2. Use descriptive test names: `testDecodeSomethingSpecific()`
3. Include clear `XCTAssert` messages explaining what is being validated
4. Test both success and failure cases
5. Test edge cases (empty data, malformed CBOR, missing fields)

### Documentation

- Update `README.md` for user-facing changes
- Update `docs/HOW_TO_USE.md` for CLI changes
- Add inline documentation for public APIs
- Update `CHANGELOG.md` for significant changes

## Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd AppAttestDecoderCLI
   ```

2. **Open in Xcode**
   ```bash
   open AppAttestDecoderCLI.xcodeproj
   ```

3. **Build the project**
   - Select the `AppAttestCore` scheme
   - Press `Command+B` to build

4. **Run tests**
   - Press `Command+U` to run all tests

## Adding Validation Logic

**Important**: If you want to add validation logic (signature verification, certificate validation, etc.), please **discuss it first** by opening an issue. 

The project intentionally excludes validation to:
- Keep the decoder focused on parsing
- Avoid security liability
- Allow users to implement validation according to their security requirements

If you have a strong use case for validation utilities, we can discuss adding them as **optional helper functions** that are clearly marked as non-authoritative and require explicit opt-in.

## Questions?

- Open an issue for questions about project scope
- Check `README.md` and `docs/HOW_TO_USE.md` for usage questions
- Review existing code for implementation patterns

Thank you for contributing!

