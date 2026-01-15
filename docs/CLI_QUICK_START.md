# App Attest Decoder CLI — Quick Start

## What is this tool?

A forensic decoder for Apple App Attest attestation objects. It provides lossless inspection of trust artifacts with multiple output modes for different use cases.

## Which command should I run?

| If you want to… | Run this |
|----------------|----------|
| Just see what's inside | `pretty --file /tmp/attestation.b64` |
| Understand what it means | `pretty --explain --file /tmp/attestation.b64` |
| Build a backend | `pretty --backend-ready --file /tmp/attestation.b64` |
| Review security posture | `pretty --security --file /tmp/attestation.b64` |
| See all evidence | `pretty --forensic --file /tmp/attestation.b64` |
| Prove nothing is hidden | `pretty --lossless-tree --file /tmp/attestation.b64` |

## Quick Reference

**Default (semantic view):**
```bash
pretty --file /tmp/attestation.b64
```
Clean, readable output. Decoded meaning only. Collapsed hex.

**With interpretation:**
```bash
pretty --explain --file /tmp/attestation.b64
```
Same as default, plus explanations of opaque fields and usage guidance.

**Backend setup:**
```bash
pretty --backend-ready --file /tmp/attestation.b64
```
Shows what to store, verify, monitor, and reject. Use this when implementing server-side verification.

**Security review:**
```bash
pretty --security --file /tmp/attestation.b64
```
Shows trust posture assessment, interpretation, and backend readiness. All guidance in one view.

**Forensic (evidence + meaning):**
```bash
pretty --forensic --file /tmp/attestation.b64
```
Decoded fields plus grouped raw evidence (hex, base64, DER). Use for analysis and debugging.

**Lossless tree (proof tool):**
```bash
pretty --lossless-tree --file /tmp/attestation.b64 --no-color
```
Every byte, every node, every path. Use for audits, corpus building, or proving nothing is hidden.

## Input Methods

**From file:**
```bash
pretty --file /path/to/attestation.b64
```

**From base64 string:**
```bash
pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."
```

**From STDIN:**
```bash
cat attestation.b64 | pretty
```

## See Also

- `docs/MODES_AND_LAYERS.md` - Why the modes exist
- `docs/VERIFICATION_GUIDE.md` - What to verify server-side
- `docs/CLI_Argument_Paths.md` - Complete command reference
