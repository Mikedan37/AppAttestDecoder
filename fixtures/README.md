# Fixtures: Known Good and Known Bad Attestation Samples

This directory contains sample attestation objects for testing and regression purposes. These are **not** test cases—they are reference artifacts.

## Purpose

These fixtures serve as:

- **Reference artifacts** for understanding structure
- **Regression samples** for ensuring decoder stability
- **Documentation** of real-world attestation formats
- **Corpus** for diffing and comparison

They are **not** for:

- Security testing (use proper fuzzing tools)
- Production validation (these are samples only)
- Cryptographic verification (signatures may be expired or invalid)

## Structure

```
fixtures/
├── valid_attestation_ios17.b64      # Valid iOS 17 attestation
├── valid_attestation_ios18.b64       # Valid iOS 18 attestation
├── truncated_base64.b64              # Malformed: truncated base64
├── corrupted_cbor.b64                # Malformed: corrupted CBOR
├── extension_attestation.b64         # Valid extension attestation
└── README.md                          # This file
```

## Usage

### Inspecting a Valid Attestation

```bash
pretty --forensic --file fixtures/valid_attestation_ios17.b64
```

### Testing Decoder Robustness

```bash
# Should exit with error code 1 (malformed input)
pretty --file fixtures/truncated_base64.b64
```

### Comparing iOS Versions

```bash
diff <(pretty --json --file fixtures/valid_attestation_ios17.b64) \
     <(pretty --json --file fixtures/valid_attestation_ios18.b64)
```

## Adding New Fixtures

When adding new fixtures:

1. **Name clearly** - Include iOS version, device type, or issue type
2. **Document purpose** - Add a comment explaining what this fixture demonstrates
3. **Keep small** - Prefer minimal examples over large dumps
4. **Redact sensitive data** - Remove or anonymize bundle IDs, team IDs, key IDs if needed

## Security Note

These fixtures may contain:

- Real bundle IDs and team IDs (redact if publishing)
- Real certificate chains (may be expired)
- Real key material (do not use for verification)

**Do not use these fixtures for production validation.** They are reference artifacts only.

## Maintenance

- Update fixtures when iOS versions change attestation format
- Add fixtures for new edge cases discovered
- Remove fixtures that are no longer relevant
- Document any changes to fixture structure

These fixtures help ensure the decoder remains stable across iOS versions and edge cases.
