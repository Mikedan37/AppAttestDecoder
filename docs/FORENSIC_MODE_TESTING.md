# Testing Forensic Mode

## Quick Test (Recommended)

### Step 1: Save Attestation to File

```bash
cat > /tmp/attestation.b64
<paste base64 attestation>
^D
```

Or use a text editor to create `/tmp/attestation.b64` with the base64 string.

### Step 2: Run from Xcode

**This is the only reliable way to run it** (due to framework rpath requirements).

1. Select scheme: **AppAttestDecoderCLI**
2. **Edit Scheme** → **Run** → **Arguments**
3. Add exactly:
   ```
   pretty --forensic --file /tmp/attestation.b64
   ```
4. **Run** (Cmd+R)

### Step 3: Verify Output

You should see:
- ✅ **Attestation Object (Forensic View)** header
- ✅ **rawCBOR** with base64 + hex + length
- ✅ **authenticatorData** with:
  - Raw bytes (hex + base64)
  - RP ID hash (hex + base64 + encoding)
  - Flags (raw byte + bit breakdown)
  - Sign count
  - Attested credential data (if present)
- ✅ **attestationStatement** with:
  - Algorithm
  - Signature (marked [OPAQUE])
  - **x5c** certificate chain:
    - `[0] (leaf)` with Subject, Issuer, Validity, Extensions
    - `[1] (intermediate)` with full details
    - `[2] (root)` with full details
- ✅ **Extensions** decoded:
  - Apple App Attest Receipt (bundle ID, team ID, environment, OS version, device class)
  - Key Usage, Basic Constraints, etc.
- ✅ **Raw DER** preserved everywhere alongside decoded values

## Alternative: Direct Base64 Input

From Xcode scheme arguments:
```
pretty --forensic --base64 o2NmbXRvYXBwbGUtYXBwYXR0ZXN0...
```

## JSON Export

For lossless JSON export:
```
pretty --forensic --json --file /tmp/attestation.b64
```

This produces machine-readable JSON with:
- Every field includes: `path`, `type`, `raw` (base64 + hex + length), `decoded` (optional), `encoding`
- Full attestation structure preserved
- Suitable for diffing, archiving, corpus building

## What Success Looks Like

Success is **not** "I recognize every field."

Success is:
- ✅ Nothing hidden
- ✅ Nothing dropped
- ✅ Raw bytes always visible
- ✅ Decoded values clearly labeled
- ✅ Unknown things preserved, not guessed
- ✅ Opaque values marked [OPAQUE]

## Common Issues

### "Nothing prints"
- Missing `--base64` or `--file` flag
- Running from Terminal instead of Xcode
- Extra whitespace in base64 string

### "Framework not found"
- You're running the binary outside Xcode
- **Solution**: Always run from Xcode scheme

### "Output is still ugly"
- You're not using `--forensic` flag
- Without it, you get the legacy pretty printer

## Why This Matters

This tool makes attestations:
- **Auditable** - Every byte visible
- **Reviewable** - Decoded values alongside raw
- **Diffable** - JSON export enables structural comparison
- **Explainable** - Platform drift becomes visible

This is instrumentation for platform security work, not a demo.
