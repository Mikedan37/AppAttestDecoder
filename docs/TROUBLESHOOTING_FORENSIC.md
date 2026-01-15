# Troubleshooting Forensic Mode

## Common Issues

### EXC_BREAKPOINT / CBOR Decoding Error

**Symptom**: Crash with `CBORDecodingError.truncated` or `EXC_BREAKPOINT` in `CBORDecoder.readByte()`

**Causes**:
1. **Truncated base64 string** - The attestation data is incomplete
2. **Extra whitespace** - Newlines or spaces in the base64 string
3. **Corrupted data** - The base64 string is malformed

**Solutions**:
1. **Verify base64 is complete**:
   ```bash
   wc -c /path/to/attestation.txt
   # Should be several thousand characters (typically 5000-10000)
   ```

2. **Check for newlines**:
   ```bash
   cat /path/to/attestation.txt | wc -l
   # Should be 1 (single line)
   ```

3. **Verify base64 is valid**:
   ```bash
   # The file should contain only base64 characters (A-Z, a-z, 0-9, +, /, =)
   # No spaces, no newlines (except at end of file)
   ```

4. **Ensure file is read correctly**:
   - Use `--file` flag, not `--base64` with a file path
   - The tool automatically trims whitespace, but verify the file is valid

### "Variable was written to, but never read"

**Symptom**: Warning about unused variable `decodedAttestation`

**Status**: Fixed in latest commit. This was a harmless warning.

### Framework Not Found

**Symptom**: "dyld: Library not loaded" or "framework not found"

**Cause**: Running binary outside Xcode (rpath issue)

**Solution**: **Always run from Xcode scheme**, not Terminal directly.

### No Output

**Symptom**: Command runs but produces no output

**Causes**:
1. Missing `--forensic` flag (using legacy pretty printer)
2. Invalid base64 (silently fails)
3. Running from Terminal instead of Xcode

**Solutions**:
1. Always use `--forensic` flag
2. Run from Xcode scheme
3. Check error messages in stderr

## Diagnostic Commands

### Verify Base64 is Valid
```bash
# Check file size (should be 5000-10000 chars)
wc -c /path/to/attestation.txt

# Check it's a single line
wc -l /path/to/attestation.txt

# Verify it's valid base64 (Swift can decode it)
swift -c 'import Foundation; let b64 = try String(contentsOfFile: "/path/to/attestation.txt").trimmingCharacters(in: .whitespacesAndNewlines); print(Data(base64Encoded: b64) != nil ? "Valid" : "Invalid")'
```

### Test Decoding
```bash
# From Xcode scheme arguments:
pretty --forensic --file /path/to/attestation.txt

# Should produce output. If it crashes, check:
# 1. File is valid base64
# 2. File is complete (not truncated)
# 3. Running from Xcode, not Terminal
```

## Error Messages

### "CBOR decoding failed: truncated"
- **Meaning**: The CBOR data is incomplete
- **Fix**: Verify the base64 string is complete and not truncated

### "Invalid base64 string"
- **Meaning**: The base64 string contains invalid characters
- **Fix**: Ensure the file contains only base64 characters (A-Z, a-z, 0-9, +, /, =)

### "Attestation parsing failed"
- **Meaning**: The attestation structure is invalid
- **Fix**: Verify you're using an App Attest attestation object, not an assertion or other artifact

## Best Practices

1. **Always run from Xcode** - Framework loading requires proper rpath
2. **Use `--file` flag** - More reliable than `--base64` for file input
3. **Verify base64 is complete** - Truncated data will crash
4. **Check error messages** - They provide diagnostic info
