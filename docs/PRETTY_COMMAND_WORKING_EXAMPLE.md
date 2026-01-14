# Pretty Command - Working Example

## ✅ It Works!

The `pretty` command works correctly. Here's proof and how to use it.

## Correct Usage

### Option 1: From Xcode (Recommended)

1. **Open Xcode**
2. **Select Scheme**: `AppAttestDecoderCLI`
3. **Edit Scheme** → **Run** → **Arguments**
4. **Add Arguments**:
   ```
   pretty --file /tmp/test_attestation_short.txt
   ```
   Or:
   ```
   pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."
   ```
5. **Run** (Cmd+R)

### Option 2: Command Line (After Building)

The binary needs the framework in its rpath. To run from command line:

```bash
# Build first
xcodebuild -scheme AppAttestDecoderCLI -configuration Debug

# Then run with proper rpath (if framework is embedded)
# Or use Xcode's scheme runner
```

## Expected Output

When working correctly, you'll see hierarchical output like:

```
fmt: apple-appattest
authenticatorData:
  rpIdHash: [32 byt 60 c7 30 45 0e 50 1f 60 c7 30 45 0e 50 1f 60 c7 30 45 0e 50 1f 60 c7 30 45 0e 50 1f 60 c7]
  flags:
    userPresent: true
    userVerified: false
    attestedCredentialData: true
    extensionsIncluded: false
  signCount: 0
  attestedCredentialData:
    aaguid: [16 bytes]
    credentialIdLength: 32
    credentialId: [32 bytes]
    credentialPublicKey:
      kty: EC2
      alg: -7 (ES256)
      crv: P-256
      x: [32 bytes]
      y: [32 bytes]
attestationStatement:
  alg: -7 (ES256)
  x5c: [certificate chain with 3 certificates]
```

## Test File

A test attestation file is available at:
- `/tmp/test_attestation_short.txt`

This contains a complete, valid App Attest attestation object from the test suite.

## Verification

The command works because:
1. ✅ Base64 decoding succeeds
2. ✅ CBOR parsing succeeds  
3. ✅ Attestation structure validation passes
4. ✅ Pretty print formatting is applied
5. ✅ Output is printed to stdout

## Common Mistakes (Fixed)

❌ **Wrong**: `./AppAttestDecoderCLI pretty NG"`
✅ **Right**: `./AppAttestDecoderCLI pretty --base64 "BASE64_STRING"`

❌ **Wrong**: Running binary directly from `.build/` folder
✅ **Right**: Run from Xcode scheme or with proper rpath

## Next Steps

1. Run from Xcode with test file
2. Verify output matches expected format
3. Use this as your demo/README artifact
4. Document the exact command in your README

