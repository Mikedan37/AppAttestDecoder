# Forensic Mode: Lossless Inspection & Export

## Overview

Forensic mode provides lossless, transparent inspection of App Attest artifacts. Every byte is visible, every structured field is decoded, and nothing is hidden behind abstractions.

**This is instrumentation, not a demo.** It's what you use when reality is messy and you need to understand what actually happened.

## Modes

### Forensic View (Human-Readable)
```bash
pretty --forensic --file attestation.txt
```

Shows hierarchical tree with:
- Raw bytes (hex + base64 + length)
- Decoded values
- Encoding information
- Opaque labeling for cryptographic/undocumented fields

### Forensic Export (JSON)
```bash
pretty --forensic --json --file attestation.txt
```

Lossless JSON export with:
- Every field includes: `path`, `type`, `raw` (base64 + hex + length), `decoded` (optional), `encoding`
- Full attestation structure preserved
- Machine-readable for diffing, archiving, corpus building

## What This Enables

1. **Diff runs** - Structural comparison across OS versions, devices, execution contexts
2. **Archive evidence** - Lossless export for audit trails and incident response
3. **Build corpus** - Machine-readable format for research and pattern analysis
4. **Reproducible writeups** - Tables + findings, not vibes

## Privacy & Security Considerations

**Important**: When publishing outputs or sharing artifacts:

- **Redact identifiers**: Bundle IDs, Team IDs, key IDs, timestamps
- **Use synthetic samples** for public documentation unless you're 100% sure it's safe
- **Be mindful of device-specific data** in authenticator data and certificates

Tooling is fine. Accidentally doxxing your own artifacts is not.

## Terminology

- **Forensic View**: Human-readable tree output (lossless inspection)
- **Forensic Export**: JSON lossless export (machine-readable)
- **Opaque**: Cryptographic or undocumented values (preserved exactly, not interpreted)

## Philosophy

"Full transparency" does not mean "everything interpreted."

It means:
- Nothing hidden
- Nothing discarded
- No fake certainty

Some values are cryptographic or Apple-private. They're preserved exactly and labeled as opaque. That's correct behavior.
