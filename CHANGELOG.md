# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-01-XX

### Added
- Core CBOR, ASN.1, X.509, and COSE decoding
- Semantic, forensic, and lossless tree output modes
- Certificate extension decoding (standard and Apple-specific)
- Receipt ASN.1/CMS envelope inspection with TLV tree
- Attestation diffing for side-by-side comparison
- Extension OIDs with hex preview inline
- iOS test app integration example
- Comprehensive examples directory with realistic workflows
- JSON export with documented contract (stable vs best-effort fields)
- Security policy and boundaries documentation
- Design philosophy with tradeoffs and non-goals
- Common misinterpretations section
- "Start here" onboarding path

### Design Decisions
- Inspection only, no verification
- Preserves all data, nothing discarded
- Explicit boundaries and warnings throughout
- Best-effort decoding with opaque labeling
- Separation of concerns: parsing vs validation vs policy

### Known Limitations
- Apple-private fields are opaque (by design)
- Verification must be implemented separately
- Schema drift may require decoder updates
- Output is verbose (intentional, for forensic clarity)
