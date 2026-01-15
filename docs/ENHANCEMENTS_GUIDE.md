# Enhancement Features Guide

This document describes the three major enhancements added to the App Attest Decoder: inline extension OIDs with hex, enhanced receipt ASN.1/CMS inspection, and attestation diffing.

## Overview

These enhancements address common pain points when working with App Attest artifacts:

1. **Extension OIDs with Hex**: Quickly identify and verify certificate extensions without switching between multiple views
2. **Receipt ASN.1/CMS Inspection**: Deep structural analysis of Apple's receipt container format
3. **Attestation Diffing**: Compare two attestations side-by-side to identify differences across devices, OS versions, or execution contexts

---

## 1. Extension OIDs with Hex Preview

### What It Does

Certificate extensions now display with their OID and a hex preview of the raw DER bytes inline, making it easy to:
- Verify extension presence and structure
- Identify unknown extensions by OID
- Debug extension parsing issues
- Compare extensions across certificates

### Before vs After

**Before:**
```
  extensions (5):
    • Basic Constraints
      isCA: false
    • Key Usage
      Digital Signature, Key Encipherment
```

**After:**
```
  extensions (5):
    • Basic Constraints (2.5.29.19) — 30030101ff (3 bytes)
      isCA: false
    • Key Usage (2.5.29.15) — 030205a0 (3 bytes)
      Digital Signature, Key Encipherment
```

### How to Use

This feature is automatically enabled in all semantic output modes:

```bash
# Default semantic view
pretty --file attestation.b64

# Forensic mode
pretty --forensic --file attestation.b64

# Lossless tree (shows full hex)
pretty --lossless-tree --file attestation.b64
```

### What It Fixes/Enables

**Problems Solved:**
- **Extension identification**: No need to cross-reference OIDs elsewhere
- **Debugging**: Hex preview helps identify malformed or truncated extensions
- **Verification**: Quickly verify that expected extensions are present with correct OIDs
- **Research**: Compare extension structures across different attestation samples

**Enables:**
- Rapid extension auditing across certificate chains
- Detection of unexpected or unknown extensions
- Validation that extension OIDs match expected values
- Forensic analysis of extension encoding

### Example Use Cases

1. **Verify Apple App Attest Extensions**
   ```bash
   pretty --file attestation.b64 | grep "1.2.840.113635"
   ```
   Quickly find all Apple-specific extensions and verify their OIDs.

2. **Compare Extension Structures**
   Compare the hex previews to see if extensions are encoded identically across certificates.

3. **Debug Extension Parsing**
   If an extension fails to decode, the hex preview shows the raw bytes for manual inspection.

---

## 2. Receipt ASN.1/CMS Envelope Inspection

### What It Does

Provides deep structural analysis of Apple's receipt container, including:
- Full CMS SignedData structure parsing
- ASN.1 TLV tree with offsets, tag names, and lengths
- Payload format detection (ASN.1, CBOR, plist, UTF-8)
- Hierarchical view of the receipt's nested structure

### Before vs After

**Before:**
```
RECEIPT
  containerType: CMS SignedData (PKCS#7, RFC 5652)
  size: 1234 bytes
  version: 1
  contentType: Data
  payloadSize: 456 bytes
```

**After:**
```
RECEIPT
  containerType: CMS SignedData (PKCS#7, RFC 5652)
  size: 1234 bytes
  cmsVersion: 1
  digestAlgorithms: SHA-256
  contentType: Data (1.2.840.113549.1.7.1)
  payloadSize: 456 bytes
  certificates: 2
  signers: 1

ASN.1 Envelope Structure:
  SEQUENCE [offset: 0, length: 1234] (constructed)
    INTEGER [offset: 4, length: 1]
    SET [offset: 7, length: 13] (constructed)
      SEQUENCE [offset: 9, length: 11] (constructed)
        OBJECT IDENTIFIER [offset: 11, length: 9]
          hex: 2b0601040182371402
    SEQUENCE [offset: 22, length: 500] (constructed)
      OBJECT IDENTIFIER [offset: 24, length: 9]
      [0] [offset: 35, length: 489]
        hex: 3081e53081b2a0030201...

PAYLOAD ANALYSIS
  payloadFormat: ASN.1 DER
  payloadSize: 456 bytes
  Payload structure:
    SEQUENCE [123 bytes]
    OCTET STRING [333 bytes]
```

### How to Use

Automatically enabled in semantic and forensic modes:

```bash
# Semantic view (shows top-level structure)
pretty --file attestation.b64

# Forensic mode (shows full ASN.1 tree)
pretty --forensic --file attestation.b64

# Lossless tree (complete TLV dump)
pretty --lossless-tree --file attestation.b64
```

### What It Fixes/Enables

**Problems Solved:**
- **Receipt structure mystery**: Previously, receipts were opaque blobs. Now you can see the full CMS/PKCS#7 structure
- **Debugging receipt parsing**: TLV tree shows exactly where parsing might fail
- **Format detection**: Automatically identifies if payload is ASN.1, CBOR, plist, or opaque
- **Offset tracking**: Know exactly where each structure element is located in the raw bytes

**Enables:**
- Deep forensic analysis of Apple's receipt format
- Validation of receipt structure integrity
- Research into receipt payload formats
- Debugging CMS parsing issues
- Understanding receipt encoding across iOS versions

### Example Use Cases

1. **Verify Receipt Structure**
   ```bash
   pretty --forensic --file attestation.b64 | grep -A 20 "ASN.1 Envelope"
   ```
   Inspect the complete ASN.1 structure of the receipt.

2. **Identify Payload Format**
   Check the payload analysis section to see if the receipt payload is ASN.1, CBOR, or another format.

3. **Debug CMS Parsing**
   If CMS parsing fails, the ASN.1 tree shows the raw structure for manual inspection.

4. **Research Receipt Evolution**
   Compare receipt structures across iOS versions to track format changes.

---

## 3. Attestation Diffing

### What It Does

Compare two attestation objects side-by-side to identify differences in:
- Identity section (RP ID hash, flags, sign count)
- Credential data (AAGUID, credential ID, public key)
- Trust chain (certificate count, subject/issuer, serial numbers)
- Platform claims (environment, OS version, device class, key purpose)
- Receipt (presence, container type, size)

### Before vs After

**Before:**
You had to manually compare two attestation outputs, switching between terminal windows or files.

**After:**
```
ATTESTATION DIFF

IDENTITY
  - rpIdHash: a1b2c3d4e5f6...
  + rpIdHash: f6e5d4c3b2a1...

  - flags: 0x41
  + flags: 0x45

PLATFORM CLAIMS
  - osVersion: 17.2.1
  + osVersion: 17.3.0

  - deviceClass: iphoneos
  + deviceClass: iphoneos

TRUST CHAIN
  - certificateCount: 2
  + certificateCount: 3
```

### How to Use

```bash
# Compare two attestations from files
diff --left-file attest1.b64 --right-file attest2.b64

# Compare from command-line arguments
diff --left "BASE64_ATTESTATION_1" --right "BASE64_ATTESTATION_2"

# JSON output for programmatic analysis
diff --left-file attest1.b64 --right-file attest2.b64 --json

# No color (for logs/CI)
diff --left-file attest1.b64 --right-file attest2.b64 --no-color
```

### What It Fixes/Enables

**Problems Solved:**
- **Manual comparison pain**: No more switching between files or terminal windows
- **Missed differences**: Automated diff catches all field-level changes
- **Context switching**: See both attestations' differences in one view
- **CI/CD integration**: JSON output enables automated comparison in pipelines

**Enables:**
- **Cross-device analysis**: Compare attestations from different devices to identify device-specific differences
- **OS version tracking**: See how attestations change across iOS versions
- **Execution context comparison**: Compare main app vs extension attestations
- **Regression detection**: Identify when attestation structure changes unexpectedly
- **Research**: Systematically compare attestations across different contexts

### Example Use Cases

1. **Compare Main App vs Extension**
   ```bash
   # Generate attestation from main app
   # Save to main_app.b64
   
   # Generate attestation from action extension
   # Save to extension.b64
   
   diff --left-file main_app.b64 --right-file extension.b64
   ```
   Identify differences in execution context attestations.

2. **Track OS Version Changes**
   ```bash
   # iOS 17.2 attestation
   diff --left-file ios17.2.b64 --right-file ios17.3.b64
   ```
   See what changes in attestation structure across iOS versions.

3. **CI/CD Regression Detection**
   ```bash
   # In CI script
   diff --left-file baseline.b64 --right-file current.b64 --json > diff.json
   if [ $? -ne 0 ] || [ -s diff.json ]; then
     echo "Attestation structure changed!"
     cat diff.json
     exit 1
   fi
   ```
   Automatically detect when attestation structure changes.

4. **Research: Compare Multiple Samples**
   ```bash
   # Compare attestations from different devices
   for device in device1 device2 device3; do
     echo "=== Comparing baseline to $device ==="
     diff --left-file baseline.b64 --right-file ${device}.b64
   done
   ```
   Systematically compare attestations across multiple devices.

5. **Debug Attestation Failures**
   ```bash
   # Compare working vs failing attestation
   diff --left-file working.b64 --right-file failing.b64
   ```
   Quickly identify what's different in a failing attestation.

### Diff Output Format

**Human-Readable:**
- Color-coded output (green for additions, red for removals)
- Sectioned by component (Identity, Credential, Trust Chain, etc.)
- Field-level granularity

**JSON:**
```json
{
  "identity": {
    "status": "different",
    "changes": [
      {
        "field": "rpIdHash",
        "left": "a1b2c3...",
        "right": "f6e5d4..."
      }
    ]
  },
  "platformClaims": {
    "status": "different",
    "changes": [
      {
        "field": "osVersion",
        "left": "17.2.1",
        "right": "17.3.0"
      }
    ]
  }
}
```

---

## Combined Usage Examples

### Complete Attestation Audit

```bash
# 1. Inspect with extension OIDs and hex
pretty --forensic --file attestation.b64 > audit.txt

# 2. Deep receipt analysis
pretty --forensic --file attestation.b64 | grep -A 50 "RECEIPT" >> audit.txt

# 3. Compare with baseline
diff --left-file baseline.b64 --right-file attestation.b64 >> audit.txt
```

### Research Workflow

```bash
# Generate attestations from different contexts
# main_app.b64, action_ext.b64, sso_ext.b64

# Compare all to main app
for context in action_ext sso_ext; do
  echo "=== Main App vs $context ==="
  diff --left-file main_app.b64 --right-file ${context}.b64
done

# Deep dive into receipt differences
pretty --forensic --file main_app.b64 | grep -A 30 "RECEIPT" > main_receipt.txt
pretty --forensic --file action_ext.b64 | grep -A 30 "RECEIPT" > ext_receipt.txt
diff main_receipt.txt ext_receipt.txt
```

### CI/CD Integration

```bash
#!/bin/bash
# validate_attestation.sh

BASELINE="baseline_attestation.b64"
CURRENT="$1"

# Decode and validate structure
if ! pretty --file "$CURRENT" > /dev/null 2>&1; then
  echo "ERROR: Invalid attestation structure"
  exit 1
fi

# Compare to baseline
DIFF_OUTPUT=$(diff --left-file "$BASELINE" --right-file "$CURRENT" --json)
if [ $? -ne 0 ] || [ -n "$DIFF_OUTPUT" ]; then
  echo "WARNING: Attestation structure differs from baseline"
  echo "$DIFF_OUTPUT" | jq '.'
  
  # Check if differences are expected
  # (e.g., OS version updates are OK, but certificate chain changes are not)
  if echo "$DIFF_OUTPUT" | jq -e '.trustChain.status == "different"' > /dev/null; then
    echo "ERROR: Certificate chain structure changed unexpectedly"
    exit 1
  fi
fi

echo "Attestation validation passed"
```

---

## Technical Details

### Extension OID Display

- **Format**: `Extension Name (OID) — hex_preview (N bytes)`
- **Hex Preview**: First 16 bytes + "…" + last 8 bytes (or full hex if < 24 bytes)
- **OID Source**: From `X509OID.name(for:)` mapping
- **Raw DER**: Extracted from certificate's `extensions` dictionary

### Receipt ASN.1 Inspection

- **Max Depth**: 10 levels (configurable in `ReceiptASN1Inspector`)
- **TLV Parsing**: Uses `ASN1Reader` for low-level DER parsing
- **CMS Support**: Full RFC 5652 PKCS#7 SignedData structure
- **Payload Detection**: Best-effort format identification (ASN.1, CBOR, plist, UTF-8)

### Diff Algorithm

- **Comparison**: Field-by-field comparison of semantic models
- **Granularity**: Section-level (Identity, Credential, etc.) with field-level changes
- **Performance**: O(n) where n is the number of fields
- **Output**: Both human-readable and JSON formats

---

## Limitations

1. **Extension Hex Preview**: Shows first 16 + last 8 bytes. Use `--lossless-tree` for full hex dump.

2. **Receipt ASN.1 Tree**: Limited to 10 levels deep to prevent stack overflow. Very deeply nested structures may be truncated.

3. **Diff Comparison**: Only compares semantic model fields. Raw byte differences in opaque fields are not detected.

4. **Performance**: Diffing large attestations (many certificates) may be slower. Consider using `--json` for programmatic processing.

---

## Future Enhancements

Potential improvements based on usage:

- **Extension diffing**: Compare extensions across certificates in the same attestation
- **Receipt payload decoding**: Attempt to decode receipt payload if format is detected
- **Diff statistics**: Summary of how many fields differ, similarity percentage
- **Visual diff**: Side-by-side columnar diff view
- **Batch diffing**: Compare multiple attestations at once

---

## See Also

- `docs/CLI_QUICK_START.md` - Quick reference for all CLI commands
- `docs/COMMAND_REFERENCE.md` - Complete CLI documentation
- `docs/VERIFICATION_GUIDE.md` - Server-side validation guidance
- `docs/DESIGN_PHILOSOPHY.md` - Design principles and constraints
