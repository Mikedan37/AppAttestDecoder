# App Attest Decoder CLI – Executable Argument Paths

Complete reference for all ways to run the tool. No guessing.

## Input Methods (How You Feed It Data)

### 1. Read from a File

Use when you have an attestation object saved on disk.

```bash
pretty --file /path/to/attestation.b64
```

**Requirements:**
- File must contain valid base64-encoded attestation object
- File must be UTF-8 encoded
- Whitespace/newlines are automatically stripped

**Example:**
```bash
pretty --file /tmp/attestation.b64
```

---

### 2. Read Base64 Directly

Use when you copied a base64 blob from logs/JSON.

```bash
pretty --base64 "<BASE64_ATTESTATION_OBJECT>"
```

**Example:**
```bash
pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."
```

---

### 3. Read from STDIN

Use when piping data from another tool.

```bash
cat attestation.b64 | pretty
```

Or with explicit base64 flag:
```bash
pbpaste | pretty --base64
```

**Note:** The tool automatically detects if input is base64 or raw bytes.

---

## Output Modes (What It Prints)

### A. Semantic View (Default)

**Command:**
```bash
pretty --file attestation.b64
```

**What you get:**
- Clean, human-readable summary
- Format, chain structure, receipt presence
- Identity (RP ID hash, flags, sign count)
- Credential (AAGUID, credential ID, public key)
- Trust chain (certificates with high-level info)
- Platform claims (environment, OS version, device class)
- Collapsed hex (first 12 + last 12 bytes)
- Footnotes for explanations

**Use when:** Quick scan, understanding what the attestation claims

---

### B. Forensic View

**Command:**
```bash
pretty --forensic --file attestation.b64
```

**What you get:**
- Everything from semantic view
- Plus grouped raw evidence:
  - Raw CBOR length + hex + base64
  - AuthenticatorData raw bytes + parsed fields
  - Full COSE key coordinates (hex)
  - Raw x5c cert bytes (DER)
  - Extension payloads (raw DER)
  - Receipt structure analysis

**Additional options:**
- `--full`: Full transcript mode (linear narrative, all layers visible)
- `--raw`: Raw bytes only (no decoded content)
- `--both`: Both decoded and raw (default for --forensic)
- `--json`: Lossless JSON export

**Use when:** Analysis, debugging, proving claims

---

### C. Lossless Tree Dump

**Command:**
```bash
pretty --lossless-tree --file attestation.b64
# or
pretty --everything --file attestation.b64
```

**What you get:**
- Every CBOR node (map/array/int/string/bytes)
- Every ASN.1 TLV (tag, class, length, offset)
- All byte strings (length, SHA256, full base64, hex preview)
- Full certificate DER + parsed fields
- Receipt deep dump (full CBOR/ASN.1 structure)
- Losslessness proof (counters verifying nothing was skipped)

**Output to file:**
```bash
AA_OUTPUT_PATH=/tmp/report.txt pretty --lossless-tree --file attestation.b64
```

**Use when:** Forensic audit, corpus building, verifying no data loss

---

### D. JSON Export

**Command:**
```bash
pretty --forensic --json --no-color --file attestation.b64 > output.json
```

**What you get:**
- Single JSON object
- All raw bytes as base64
- All decoded fields
- Full certificate chain (DER + parsed)
- All extensions (OID, critical, raw DER, decoded)

**Use when:** Machine processing, diffing, automation, archiving

---

## Color Control

**Disable colors (recommended for Xcode console):**
```bash
pretty --no-color --file attestation.b64
```

**Default:** Colors enabled if TTY detected

---

## Quick Reference: Known Good Commands

### Print Summary from File
```bash
pretty --file /tmp/attestation.b64
```

### Print Summary from Base64
```bash
pretty --base64 "$(cat /tmp/attestation.b64)"
```

### Print Everything (Debug Dump)
```bash
pretty --forensic --lossless-tree --file /tmp/attestation.b64
```

### Export to JSON
```bash
pretty --forensic --json --no-color --file /tmp/attestation.b64 > output.json
```

### Lossless Tree to File
```bash
AA_OUTPUT_PATH=/tmp/report.txt pretty --lossless-tree --file /tmp/attestation.b64
```

---

## Xcode Scheme Setup

### Recommended Configuration

1. **Edit Scheme** → **Run** → **Arguments**
2. Add ONE argument at a time:

**Semantic View:**
```
pretty --file /tmp/attestation.b64 --no-color
```

**Forensic View:**
```
pretty --forensic --file /tmp/attestation.b64 --no-color
```

**Lossless Tree:**
```
pretty --lossless-tree --file /tmp/attestation.b64 --no-color
```

**JSON Export:**
```
pretty --forensic --json --no-color --file /tmp/attestation.b64
```

3. **Environment Variables** (optional):
   - `AA_OUTPUT_PATH=/tmp/appattest_report.txt` (for lossless tree file output)

---

## Internal Branching (What Happens Based on Content)

These are not arguments, but they determine what branches run internally.

### 1. Format Detection

**If CBOR `fmt == "apple-appattest"`:**
- Runs Apple App Attest decode path
- Prints `APPLE APP ATTEST` header
- Parses `authenticatorData`
- Parses `attestedCredentialData`
- Parses `attStmt.x5c` chain
- Extracts `attStmt.receipt`

**If format is unknown:**
- Still parses structure
- Preserves raw bytes
- Marks as opaque where appropriate

---

### 2. Trust Chain Parsing

**If `attStmt.x5c` is present:**
- Prints certificate chain count
- Prints structure (Leaf → Intermediate(s) → Root)
- Parses each cert:
  - Subject/Issuer (full DN + CN extraction)
  - Serial number (hex)
  - Signature algorithm
  - Public key (type, curve, size)
  - Validity (dates + duration)
  - Extensions (decoded when known, raw when not)

---

### 3. Public Key Parsing

**If COSE key decodes:**
- Prints key type: `EC (2)`
- Algorithm: `ES256 (-7)`
- Curve: `P-256 (1)`
- X/Y coordinates (marked as opaque in semantic view, full hex in forensic)

**If COSE key has unknown parameters:**
- Preserves raw CBOR
- Lists unknown parameter count
- Shows in lossless tree dump

---

### 4. Platform Claims Decoding

**If platform claims are decoded:**
- Environment (production/sandbox)
- OS Version
- Device Class (iphoneos, etc.)
- Key Purpose

**If platform claims aren't recognized:**
- Prints "No platform claims decoded"
- Raw bytes preserved in forensic/lossless modes

---

### 5. Receipt Handling

**Current behavior:**
- Detects receipt presence
- Attempts structure detection (CMS/CBOR/ASN.1/plist)
- Preserves raw bytes
- Shows container type and size

**Note:** Receipt is PKCS#7/CMS SignedData (ASN.1), not CBOR. The tool correctly identifies this and preserves raw bytes.

---

## What Your Sample Proves (Sanity Checks)

From typical App Attest attestations:

- **Format:** `apple-appattest` ✓
- **Flags:** `0x40` with `[AT]` (attested credential data present) ✓
- **Sign Count:** `0` (first attestation) ✓
- **x5c:** 2-3 certs (leaf + intermediate + optional root) ✓
- **Leaf Validity:** 3 days (normal for App Attest leafs) ✓
- **Receipt:** Present, structure detected ✓

---

## Mode Comparison

| Mode | Command | Use Case | Output Size | Hex Display |
|------|---------|----------|-------------|-------------|
| Semantic | `pretty` | Quick scan, human reading | Small (~50 lines) | Collapsed (12+12) |
| Forensic | `pretty --forensic` | Analysis with raw evidence | Medium (~200 lines) | Full hex/base64 |
| Lossless Tree | `pretty --lossless-tree` | Forensic audit, corpus | Large (~1000+ lines) | Full + previews |
| JSON | `pretty --forensic --json` | Machine processing | Medium (structured) | Base64 only |

---

## Troubleshooting

### "Invalid base64 string"
- Check file encoding (must be UTF-8)
- Remove whitespace/newlines
- Ensure file contains only base64 characters

### "CBOR decoding failed"
- Verify input is a valid App Attest attestation object
- Check that base64 decoding succeeded first

### Output too large for console
- Use `AA_OUTPUT_PATH` environment variable
- Or pipe to file: `pretty --lossless-tree --file input.b64 > output.txt`

### Colors not working in Xcode
- Always use `--no-color` flag in Xcode schemes
- Xcode console doesn't handle ANSI codes well

---

## See Also

- `docs/COMMAND_REFERENCE.md` - Complete command reference with examples
- `docs/HOW_TO_USE.md` - Getting started guide
- `docs/FORENSIC_MODE.md` - Forensic mode details
- `docs/TROUBLESHOOTING.md` - Common issues and solutions
