# Troubleshooting: Pretty Command Not Printing

## The Issue

The `pretty` command isn't producing output when you provide a test attestation.

## Common Causes

### 1. Missing Input Flag

The `pretty` command requires one of:
- `--base64 <base64-string>` - Provide base64 directly
- `--file <path>` - Read from file
- STDIN input (pipe or redirect)

**Incorrect:**
```bash
./AppAttestDecoderCLI pretty "BASE64_STRING"
```

**Correct:**
```bash
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING"
```

### 2. Base64 String Issues

- **Newlines in base64**: The command trims whitespace, but ensure the base64 is complete
- **Invalid base64**: Check that the string is valid base64 (only A-Z, a-z, 0-9, +, /, =)
- **Truncated base64**: Complete attestation objects are typically 1000+ characters

**Test base64 validity:**
```bash
echo "YOUR_BASE64" | base64 -d > /dev/null && echo "Valid" || echo "Invalid"
```

### 3. Running from Xcode

If running from Xcode's scheme:
1. **Check the console output** - Pretty print goes to stdout
2. **Check for errors** - Errors go to stderr (red text in Xcode console)
3. **Use verbose mode** - Add `--verbose` flag to see debug info

**Example:**
```
Arguments: pretty --base64 "YOUR_BASE64" --verbose
```

### 4. Framework Not Found (Runtime Error)

If you see:
```
dyld: Library not loaded: @rpath/AppAttestCore.framework
```

**Solution:**
- Run from Xcode (scheme: AppAttestDecoderCLI)
- Or build a release binary with embedded frameworks
- Don't run the binary directly from `.build/` folder

## Testing the Command

### Test 1: Basic Pretty Print
```bash
# From Xcode: Edit Scheme → Arguments
# Add: pretty --base64 "YOUR_BASE64_STRING"
```

### Test 2: From File
```bash
# Save attestation to file
echo "YOUR_BASE64" > /tmp/attestation.txt

# Run pretty command
# From Xcode: Arguments: pretty --file /tmp/attestation.txt
```

### Test 3: Verbose Mode
```bash
# From Xcode: Argument pretty --base64 "YOUR_BASE64" --verbose
# This shows debug info about base64 length and data size
```

### Test 4: Check for Errors
```bash
# If no output, check stderr for errors
# In Xcode console, look for red error messages
```

## Expected Output

When working correctly, you should see:
```
fmt: apple-appattest
authenticatorData:
  rpIdHash: [32 bytes]
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
    credentialPublicKey: [CBOR map]
attestationStatement:
  alg: -7 (ES256)
  x5c: [certificate chain]
```

## If Still Not Working

1. **Check the exact command you're running**
   - Copy the exact command from Xcode scheme arguments
   - Verify it includes `--base64` or `--file`

2. **Test with verbose mode**
   - Add `--verbose` flag
   - Check console for debug output

3. **Verify base64 is complete**
   - Attestation objects are typically 1000+ characters
   - Check for truncation

4. **Check for silent errors**
   - Look in Xcode console for stderr messages
   - Errors are printed in red

5. **Test with a known-good attestation**
   - Use the test attestation from `AppAttestCoreTests.swift`
   - Verify the command works with that

