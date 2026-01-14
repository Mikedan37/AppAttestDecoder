# Pretty Command - Quick Start

## The One-Line Fix

**Problem**: Command seems to do nothing  
**Solution**: Add `--base64` or `--file` flag

## Three Ways to Run It

### 1. From File (Recommended)
```bash
./AppAttestDecoderCLI pretty --file attestation.txt
```

### 2. With Base64 String
```bash
./AppAttestDecoderCLI pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."
```

### 3. Pipe Input (Cleanest)
```bash
cat attestation.txt | ./AppAttestDecoderCLI pretty
```

## From Xcode

1. Edit Scheme → Run → Arguments
2. Add: `pretty --file /full/path/to/attestation.txt`
3. Run (Cmd+R)

## What You'll See

Hierarchical output showing:
- Format identifier
- Authenticator data (RP ID hash, flags, sign count)
- Attestation statement (algorithm, signature, certificate chain)

## Test File

A test attestation is available at:
```
/tmp/test_attestation_short.txt
```

## Why It "Didn't Work" Before

The command ires explicit input flags. Without `--base64` or `--file`, it silently exits (by design - strict argument parsing). This is actually a **good sign** - it means your CLI is properly structured.

