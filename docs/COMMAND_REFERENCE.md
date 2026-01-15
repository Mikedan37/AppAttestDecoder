# App Attest Decoder CLI — Command Reference

Complete reference for all command-line options and output modes.

## Quick Start

```bash
# Semantic view (default - clean, readable)
pretty --file /tmp/attestation.b64

# Forensic view (decoded + raw evidence)
pretty --forensic --file /tmp/attestation.b64

# Lossless tree (every byte, every node - no data dropped)
pretty --lossless-tree --file /tmp/attestation.b64

# JSON export (machine-readable, lossless)
pretty --forensic --json --file /tmp/attestation.b64 > output.json
```

## Output Modes

### Semantic View (Default)

**Command:** `pretty [options]`

**Description:** Clean, human-readable output with decoded meaning only. No raw bytes, no ASN.1 dumps. Designed for quick scanning and understanding.

**Example:**
```bash
pretty --file /tmp/attestation.b64
```

**Output includes:**
- Executive summary (format, chain length, receipt presence)
- Identity (RP ID hash, flags, sign count)
- Credential (if present: AAGUID, credential ID, public key)
- Trust chain (certificates with high-level info)
- Platform claims (environment, OS version, device class)
- Footnotes for explanations

**Options:**
- `--no-color`: Disable ANSI color codes (useful for Xcode console)
- `--file <path>`: Read base64 from file
- `--base64 <string>`: Provide base64 directly
- STDIN: Pipe base64 directly

---

### Forensic View

**Command:** `pretty --forensic [options]`

**Description:** Semantic view followed by grouped raw evidence. All decoded fields first, then raw bytes at the end.

**Example:**
```bash
pretty --forensic --file /tmp/attestation.b64
```

**Additional options:**
- `--full`: Full transcript mode (linear narrative, all layers visible)
- `--raw`: Raw bytes only (no decoded content)
- `--both`: Both decoded and raw (default for --forensic)
- `--json`: Lossless JSON export (see below)

---

### Lossless Tree Mode

**Command:** `pretty --lossless-tree [options]` or `pretty --everything [options]`

**Description:** Guarantees no data is dropped. Emits every byte, every CBOR node, every ASN.1 TLV. This is the "ground truth" view for forensic analysis.

**Example:**
```bash
# Output to console
pretty --lossless-tree --file /tmp/attestation.b64

# Output to file (via environment variable)
AA_OUTPUT_PATH=/tmp/appattest_report.txt pretty --lossless-tree --file /tmp/attestation.b64
```

**Output includes:**
- Full CBOR tree (every map key/value, every array element)
- Full ASN.1 TLV tree (every tag, class, length, offset)
- All byte strings (length, SHA256, base64, hex preview)
- Receipt deep dump (full CBOR/ASN.1 structure)
- Losslessness proof (counters verifying nothing was skipped)

**Features:**
- Deterministic key ordering (integers ascending, strings lexicographic)
- Full base64 (never truncated)
- Hex previews (first 32 + last 16 bytes for long strings)
- Nested format detection (ASN.1, CBOR, UTF-8, plist)
- Path tracking (e.g., `.attStmt.x5c[0].extensions[1.2.840.113635.100.8.5]`)

**Use cases:**
- Forensic analysis
- Building corpus for research
- Verifying no data loss
- Deep inspection of unknown fields

---

### JSON Export

**Command:** `pretty --forensic --json [options]`

**Description:** Lossless JSON export. Machine-readable format preserving all raw bytes and decoded values.

**Example:**
```bash
pretty --forensic --json --no-color --file /tmp/attestation.b64 > output.json
```

**Output format:**
- Single JSON object
- All raw bytes as base64
- All decoded fields
- Full certificate chain (DER as base64 + parsed fields)
- All extensions (OID, critical, raw DER, decoded content)

**Use cases:**
- Diffing attestations
- Archiving evidence
- Building analysis pipelines
- Automated processing

---

## Common Options

### Input Methods

```bash
# From file
pretty --file /path/to/attestation.b64

# Direct base64 string
pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."

# From STDIN
echo "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..." | pretty

# Or pipe from file
cat /tmp/attestation.b64 | pretty
```

### Output Control

- `--no-color`: Disable ANSI colors (recommended for Xcode console)
- `AA_OUTPUT_PATH=<file>`: Write lossless tree to file (environment variable)

---

## Xcode Scheme Configuration

### Recommended Setup

1. **Edit Scheme** → **Run** → **Arguments**
2. Add ONE argument at a time:

**Semantic View:**
```
pretty --file /tmp/attestation.b64
```

**Forensic View:**
```
pretty --forensic --file /tmp/attestation.b64
```

**Lossless Tree:**
```
pretty --lossless-tree --file /tmp/attestation.b64
```

**JSON Export:**
```
pretty --forensic --json --no-color --file /tmp/attestation.b64
```

3. **Environment Variables** (optional):
   - `AA_OUTPUT_PATH=/tmp/appattest_report.txt` (for lossless tree file output)

---

## Output Examples

### Semantic View Output

```
APPLE APP ATTEST

FORMAT              apple-appattest
CERTIFICATE CHAIN   3 certificate(s)
RECEIPT             Present
ATTESTED CREDENTIAL Present
ENVIRONMENT         production (from extension)
EXTENSIONS          12 total (10 decoded, 2 opaque)

IDENTITY

RP ID HASH          32 bytes (hex: 1109a3b5c7d9…, b64: EQm5…yc4=)
FLAGS               0x40 (0b01000000) [AT]
SIGN COUNT          0 (First attestation (no prior use))

CREDENTIAL

AAGUID              AAAA0000-0000-0000-0000-000000000000
CREDENTIAL ID       64 bytes
PUBLIC KEY
  KEY TYPE          EC (2)
  ALGORITHM         ES256 (-7)
  CURVE             P-256 (1)
  X COORDINATE      [32 bytes] [OPAQUE]
  Y COORDINATE      [32 bytes] [OPAQUE]

TRUST CHAIN

STRUCTURE           leaf → 1 intermediate(s) → root

Certificate [0] — Leaf
  SUBJECT           CN=...
  ISSUER            CN=Apple App Attestation CA 1
  SERIAL NUMBER     a1b2c3d4...
  SIGNATURE ALG     ECDSA-SHA256
  PUBLIC KEY        EC (Elliptic Curve, RFC 5480)
    Type:           EC Public Key
    Curve:          P-256
    Key Size:       256 bits
  VALID FROM        2026-01-14T00:00:44Z
  VALID UNTIL       2026-01-17T00:00:44Z
  DURATION          3 days
  EXTENSIONS (12):
    • Basic Constraints
    • Key Usage
    • Extended Key Usage
    • Subject Key Identifier
    • Authority Key Identifier
    • Subject Alternative Name
    • Apple App Attest Challenge
    • Apple App Attest Receipt
      Bundle ID:    com.example.app
      Team ID:      ABC123XYZ
    • Apple App Attest Key Purpose
      Purpose:      app-attest
    • Apple App Attest Environment
      Environment:  production
    • Apple App Attest OS Version
      OS Version:   26.4
    • Apple App Attest Device Class
      Device Class: iphoneos

PLATFORM CLAIMS

ENVIRONMENT         production
OS VERSION          26.4
DEVICE CLASS        iphoneos
KEY PURPOSE         app-attest

NOTES

[1] RP ID hash is SHA-256 of the bundle identifier. Used to bind attestation to specific app.
[2] Sign count increments with each use. Zero indicates first attestation.
[3] Public key coordinates are cryptographic material. [OPAQUE] indicates opaque data.
[4] Receipt is Apple-signed evidence blob. Signature verification not performed here.
```

### Lossless Tree Output (Excerpt)

```
LOSSLESS TREE DUMP
==================

NOTE: Every byte and every parsed node is emitted below. No data is dropped.

CBOR STRUCTURE
--------------

attestationObject: map(3 entries)
  attestationObject."fmt": textString("apple-appattest")
  attestationObject."authData": byteString(37 bytes)
    sha256: 1a2b3c4d5e6f...
    base64: Gis8PF4/...
    hexPreview: 1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890…1234567890abcdef
  attestationObject."attStmt": map(2 entries)
    attestationObject."attStmt"."x5c": array(3 elements)
      attestationObject."attStmt"."x5c"[0]: byteString(1043 bytes)
        sha256: a1b2c3d4...
        base64: obLD1NQ=...
        asn1Detected: true (tag: 0x30, length: 1040)
      ...

AUTHENTICATOR DATA
------------------

rawData: 37 bytes
  sha256: 1a2b3c4d...
  base64: Gis8PF4/...
  hexPreview: 1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890…1234567890abcdef
rpIdHash: 32 bytes
  hex: 1109a3b5c7d9e1f3a5b7c9d1e3f5a7b9c1d3e5f7a9b1c3d5e7f9a1b3c5d7e9f
  base64: EQm5x8fZ4fOlvcnR4/Wnu8HD5fenuxw9V+epsc1f5qGzxdfmnw==
flags: 0x40
  userPresent: false
  userVerified: false
  attestedCredentialData: true
  extensionsIncluded: false
signCount: 0

attestedCredentialData
  aaguid: 16 bytes
    hex: aaaaaaaa000000000000000000000000
    uuid: aaaa0000-0000-0000-0000-000000000000
  credentialId: 64 bytes
    hex: 1a2b3c4d...
    base64: Gis8PF4/...
  credentialPublicKey:
    credentialPublicKey.1: unsigned(2)
    credentialPublicKey.-1: unsigned(1)
    credentialPublicKey.-2: byteString(32 bytes)
      ...
    credentialPublicKey.-3: byteString(32 bytes)
      ...
    credentialPublicKey.3: negative(-7)

CERTIFICATE CHAIN
-----------------

Certificate [0]
  rawDER: 1043 bytes
    sha256: a1b2c3d4...
    base64: obLD1NQ=...
  ASN.1 TLV Tree
    x5c[0].asn1[offset=0]: Universal SEQUENCE (constructed=true, length=1040)
      valueHexPreview: 3082040c...
      valueBase64: MIIBCgKCAQEA...
      x5c[0].asn1.children[offset=4]: Universal SEQUENCE (constructed=true, length=950)
        ...
  Semantic Fields
    subject: CN=913fb6b45aa965d8f955c6872d4650f7bba410fd4a355e3953a30e7194f05083
    issuer: CN=Apple App Attestation CA 1
    serialNumber: 9bbe745e6f
    signatureAlgorithm: 1.2.840.10045.4.3.2
    validity: 2026-01-14 00:00:44 +0000 to 2026-01-17 00:00:44 +0000
    extensions: 12
      Basic Constraints (2.5.29.19): 4 bytes
        nestedFormat: ASN.1 (tag: 0x30, length: 2)
        sha256: 1a2b3c4d...
        base64: MBQ=
        decoded: basicConstraints(isCA: false, pathLengthConstraint: nil)
      Apple App Attest Receipt (1.2.840.113635.100.8.5): 3991 bytes
        nestedFormat: CBOR
        sha256: a1b2c3d4...
        base64: obLD1NQ=...
        decoded: Apple extension
          type: receipt
          bundleID: com.example.app
          teamID: ABC123XYZ

LOSSLESSNESS PROOF
------------------

CBOR nodes emitted: 47
ASN.1 TLVs emitted: 156
Bytes accounted: 8 paths
  authenticatorData.rawData: 37 bytes
  authenticatorData.rpIdHash: 32 bytes
  authenticatorData.attestedCredentialData.aaguid: 16 bytes
  authenticatorData.attestedCredentialData.credentialId: 64 bytes
  attStmt.signature: 72 bytes
  x5c[0].rawDER: 1043 bytes
  x5c[1].rawDER: 892 bytes
  receipt.rawData: 3991 bytes

LOSSLESS OK: All nodes and bytes accounted for
```

---

## Command Comparison

| Mode | Command | Use Case | Output Size |
|------|---------|----------|-------------|
| Semantic | `pretty` | Quick scan, human reading | Small (~50 lines) |
| Forensic | `pretty --forensic` | Analysis with raw evidence | Medium (~200 lines) |
| Lossless Tree | `pretty --lossless-tree` | Forensic audit, corpus building | Large (~1000+ lines) |
| JSON | `pretty --forensic --json` | Machine processing, diffing | Medium (structured) |

---

## Tips

1. **For Xcode Console:** Always use `--no-color` to avoid ANSI wrapping issues
2. **For Large Output:** Use `AA_OUTPUT_PATH` to write lossless tree to file
3. **For Diffing:** Use JSON export and `diff` or `jq` for comparison
4. **For Research:** Use lossless tree mode to build corpus of attestations

---

## Troubleshooting

**"Invalid base64 string"**
- Check file encoding (must be UTF-8)
- Remove any whitespace/newlines
- Ensure file contains only base64 characters

**"CBOR decoding failed"**
- Verify input is a valid App Attest attestation object
- Check that base64 decoding succeeded first

**Output too large for console**
- Use `AA_OUTPUT_PATH` environment variable
- Or pipe to file: `pretty --lossless-tree --file input.b64 > output.txt`

---

## See Also

- `docs/HOW_TO_USE.md` - Getting started guide
- `docs/FORENSIC_MODE.md` - Forensic mode details
- `docs/TROUBLESHOOTING.md` - Common issues and solutions
