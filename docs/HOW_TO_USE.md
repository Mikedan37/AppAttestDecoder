# How to Use AppAttestDecoderCLI

Complete guide for using the App Attest Decoder CLI tool to decode and inspect Apple App Attest attestation objects and assertions.

## Table of Contents

1. [Building the Tool](#building-the-tool)
2. [Basic Usage](#basic-usage)
3. [Command Reference](#command-reference)
4. [Pretty Print Command](#pretty-print-command)
5. [Input Methods](#input-methods)
6. [Output Formats](#output-formats)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)
9. [Integration Examples](#integration-examples)

---

## Building the Tool

### Prerequisites

- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

### Build Steps

1. **Open the project in Xcode:**
   ```bash
   open AppAttestDecoderCLI.xcodeproj
   ```

2. **Select the AppAttestDecoderCLI scheme:**
   - In Xcode, select "AppAttestDecoderCLI" from the scheme dropdown
   - Choose "My Mac" as the destination

3. **Build the project:**
   - Press `Command+B` or go to Product → Build
   - The binary will be built to: `build/Debug/AppAttestDecoderCLI`

4. **Alternative: Build from command line:**
   ```bash
   xcodebuild -scheme AppAttestDecoderCLI -configuration Debug
   ```

5. **Make the binary executable (optional):**
   ```bash
   chmod +x build/Debug/AppAttestDecoderCLI
   ```

6. **Add to PATH (optional):**
   ```bash
   # Add to ~/.zshrc or ~/.bash_profile
   export PATH="$PATH:/path/to/AppAttestDecoderCLI/build/Debug"
   ```

---

## Basic Usage

### Command Syntax

```bash
./AppAttestDecoderCLI <command> [options] [input]
```

### Quick Start

```bash
# Decode an attestation object from base64 string
./AppAttestDecoderCLI attest --base64 "BASE64_STRING"

# Pretty-print an attestation object
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING"

# Read from file
./AppAttestDecoderCLI pretty --file attestation.txt

# Read from STDIN
echo "BASE64_STRING" | ./AppAttestDecoderCLI pretty
```

---

## Command Reference

### 1. `attest` - Decode Attestation Object

Decodes and displays the structure of an App Attest attestation object.

**Syntax:**
```bash
./AppAttestDecoderCLI attest [--base64 <b64> | --file <path>] [--hex] [--raw] [--json]
```

**Options:**
- `--base64 <b64>`: Provide base64 blob as command-line argument
- `--file <path>`: Read base64 blob from file
- `--hex`: Print hex dump of the input blob
- `--raw`: Echo raw base64 of the input blob
- `--json`: Print decoded structure as JSON

**Examples:**
```bash
# Basic decode
./AppAttestDecoderCLI attest --base64 "BASE64_STRING"

# With hex dump
./AppAttestDecoderCLI attest --base64 "BASE64_STRING" --hex

# With JSON output
./AppAttestDecoderCLI attest --base64 "BASE64_STRING" --json

# From file
./AppAttestDecoderCLI attest --file attestation.txt

# From STDIN
cat attestation.txt | ./AppAttestDecoderCLI attest
```

**Output:**
- Displays parsed structure of the attestation object
- Shows format, authenticator data fields, and attestation statement
- Note: This command does NOT validate signatures or certificates

---

### 2. `assert` - Decode Assertion

Decodes and displays the structure of an App Attest assertion object (COSE_Sign1 message).

**Syntax:**
```bash
./AppAttestDecoderCLI assert [--base64 <b64> | --file <path>] [--hex] [--raw] [--json]
```

**Options:**
- `--base64 <b64>`: Provide base64 blob as command-line argument
- `--file <path>`: Read base64 blob from file
- `--hex`: Print hex dump of the input blob
- `--raw`: Echo raw base64 of the input blob
- `--json`: Print decoded structure as JSON

**Examples:**
```bash
# Basic decode (pretty-print by default)
./AppAttestDecoderCLI assert --base64 "BASE64_ASSERTION_STRING"

# With hex dump
./AppAttestDecoderCLI assert --base64 "BASE64_STRING" --hex

# With JSON output
./AppAttestDecoderCLI assert --base64 "BASE64_STRING" --json

# From file
./AppAttestDecoderCLI assert --file assertion.txt

# From STDIN
cat assertion.txt | ./AppAttestDecoderCLI assert
```

**Output:**
- Displays parsed structure of the assertion object
- Shows COSE_Sign1 structure (protected header, unprotected header, payload, signature)
- Shows authenticator data fields (rpIdHash, flags, signCount)
- Note: This command does NOT validate signatures or certificates

---

### 3. `pretty` - Pretty-Print Attestation Object

**Note:** The `pretty` command works with attestation objects. For assertions, use the `assert` command which pretty-prints by default.

Pretty-prints an attestation object with hierarchical formatting and optional colorization.

**Syntax:**
```bash
./AppAttestDecoderCLI pretty [--base64 <b64> | --file <path>] [--verbose] [--no-color]
```

**Options:**
- `--base64 <b64>`: Provide base64 blob as command-line argument
- `--file <path>`: Read base64 blob from file
- `--verbose` or `-v`: Enable verbose logging (prints blob lengths)
- `--no-color`: Disable colorized output

**Features:**
- Hierarchical indentation (2 spaces per level)
- Hex formatting with spaces every 4 bytes
- Flags display (raw value + boolean interpretations)
- Recursive CBOR structure printing
- Automatic colorization when outputting to terminal
- Colors disabled automatically when piped to file/command

**Examples:**
```bash
# Basic pretty-print (with auto-detected colors)
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING"

# From file
./AppAttestDecoderCLI pretty --file attestation.txt

# With verbose logging
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING" --verbose

# Disable colors
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING" --no-color

# Pipe from STDIN
echo "BASE64_STRING" | ./AppAttestDecoderCLI pretty

# Save to file (colors auto-disabled)
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING" > output.txt
```

**Output Format:**
```
Attestation Object
==================

`format`: apple-appattest
`authenticatorData`: {
  `rpIdHash`: a1b2c3d4 e5f6a7b8 c9d0e1f2 a3b4c5d6 ... (32 bytes)
  `flags`: {
    `rawValue`: 0x45 (69)
    `userPresent`: true
    `userVerified`: true
    `attestedCredentialData`: true
    `extensionsIncluded`: false
  }
  `signCount`: 0
  ...
}
`attestationStatement`: {
  `alg`: -7
  `signature`: 1a2b3c4d 5e6f7a8b ... (256 bytes)
  `x5c`: {
    [0]: 30820122 3081c8a0 ... (1234 bytes)
    [1]: 30820145 3081d2b1 ... (1456 bytes)
  }
  ...
}
```

---

### 4. `selftest` - Self-Test

Runs a self-test to verify CLI functionality.

**Syntax:**
```bash
./AppAttestDecoderCLI selftest
```

**Output:**
```
Self-test:
  base64 decode OK (len=2)
  no DeviceCheck linkage
  deterministic CLI path OK
```

---

### 4. `selftest` - Self-Test

Runs a self-test to verify CLI functionality.

**Syntax:**
```bash
./AppAttestDecoderCLI selftest
```

**Output:**
- Verifies base64 decoding works
- Confirms no DeviceCheck linkage
- Verifies deterministic CLI path

---

### 5. `--version` / `-V` - Version Information

Displays version information and exits.

**Syntax:**
```bash
./AppAttestDecoderCLI --version
# or
./AppAttestDecoderCLI -V
```

**Output:**
```
AppAttestDecoderCLI version 1.0.0
```

---

## Input Methods

The tool supports three ways to provide input:

### 1. Command-Line Argument (`--base64`)

```bash
./AppAttestDecoderCLI pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."
```

**Use when:**
- Testing with small base64 strings
- Quick one-off inspections
- Scripting with variables

**Limitations:**
- Command-line length limits (varies by shell)
- May require escaping special characters

### 2. File Input (`--file`)

```bash
./AppAttestDecoderCLI pretty --file /path/to/attestation.txt
```

**File format:**
- Plain text file containing base64 string
- Can include newlines (automatically trimmed)
- UTF-8 encoding

**Use when:**
- Working with large attestation blobs
- Storing attestation data for reuse
- Batch processing multiple files

**Example file:**
```
attestation.txt:
o2NmbXRvYXBwbGUtYXBwYXR0ZXN0
Z2F0dFN0bXSiY3g1Y4JZBBIwggQO
...
```

### 3. STDIN (Standard Input)

```bash
echo "BASE64_STRING" | ./AppAttestDecoderCLI pretty
cat attestation.txt | ./AppAttestDecoderCLI pretty
```

**Use when:**
- Piping from other commands
- Processing in shell pipelines
- Reading from process output

**Priority:**
The tool checks input sources in this order:
1. `--base64` argument (highest priority)
2. `--file` argument
3. STDIN (fallback)

---

## Output Formats

### Plain Text (Default)

Default output format for `attest` and `assert` commands:
```
Attestation blob bytes: 1234
{
  "format": "apple-appattest",
  "authenticatorData": {...},
  ...
}
```

### Hex Dump (`--hex`)

Hexadecimal representation of the input blob:
```
00000000:  a3 63 36 6d 66 74 76 6f 61 70 70 6c 65 2d 61 70
00000010:  70 61 74 74 65 73 74 67 61 74 74 53 74 6d 74 62
...
```

### JSON (`--json`)

Structured JSON output:
```json
{
  "format": "apple-appattest",
  "authenticatorData": {
    "rpIdHash": "...",
    "flags": {...}
  }
}
```

### Pretty Print (Hierarchical)

Formatted hierarchical output with indentation:
```
Attestation Object
==================

`format`: apple-appattest
`authenticatorData`: {
  `rpIdHash`: ...
  `flags`: {
    ...
  }
}
```

---

## Examples

### Example 1: Decode Attestation from iOS App

```bash
# 1. Capture attestation blob from your iOS app
# (Copy the base64 string from your app's logs or network response)

# 2. Save to file
echo "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..." > attestation.txt

# 3. Pretty-print it
./AppAttestDecoderCLI pretty --file attestation.txt

# 4. Save formatted output
./AppAttestDecoderCLI pretty --file attestation.txt > formatted_output.txt
```

### Example 2: Inspect Certificate Chain

```bash
# Pretty-print to see certificate chain
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING" | grep -A 20 "x5c"

# Extract just the certificate data
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING" | grep "\[0\]"
```

### Example 3: Debug Invalid Attestation

```bash
# Use verbose mode to see blob lengths
./AppAttestDecoderCLI pretty --base64 "BASE64_STRING" --verbose

# Output will show:
# Debug: Base64 string length: 9212 characters
# Debug: Decoded data length: 6909 bytes
```

### Example 4: Batch Processing

```bash
# Process multiple attestation files
for file in attestations/*.txt; do
    echo "Processing $file..."
    ./AppAttestDecoderCLI pretty --file "$file" > "output/$(basename $file).formatted"
done
```

### Example 5: Integration with Backend Validation

```bash
# Extract attestation blob from API response
curl -s https://api.example.com/attestation | \
    jq -r '.attestation_blob' | \
    ./AppAttestDecoderCLI pretty --verbose > validation_log.txt
```

### Example 6: Compare Two Attestations

```bash
# Pretty-print both attestations
./AppAttestDecoderCLI pretty --file attestation1.txt > output1.txt
./AppAttestDecoderCLI pretty --file attestation2.txt > output2.txt

# Compare (ignoring color codes)
diff output1.txt output2.txt
```

---

## Troubleshooting

### Problem: "Invalid base64 string"

**Symptoms:**
```
Error: Invalid base64 string
  Base64 string length: 123 characters
```

**Solutions:**
1. **Check for incomplete base64:**
   - Ensure the base64 string is complete
   - Attestation objects are typically 800-1500+ bytes when decoded
   - If decoded length < 500 bytes, the blob is likely incomplete

2. **Remove whitespace/newlines:**
   ```bash
   # Remove all whitespace
   echo "BASE64_STRING" | tr -d '[:space:]' | ./AppAttestDecoderCLI pretty
   ```

3. **Verify base64 encoding:**
   ```bash
   # Test if base64 is valid
   echo "BASE64_STRING" | base64 -d > /dev/null && echo "Valid" || echo "Invalid"
   ```

### Problem: "CBOR data truncated"

**Symptoms:**
```
Error: CBOR decoding failed
  CBOR data truncated: expected 20 bytes, but only 5 remaining at offset 71
```

**Solutions:**
1. **Incomplete base64 string:**
   - The attestation blob was cut off
   - Re-capture the complete base64 string from your app

2. **Check base64 string length:**
   ```bash
   # Base64 length should be a multiple of 4
   echo "BASE64_STRING" | wc -c
   # If not divisible by 4, add padding '=' characters
   ```

3. **Verify data completeness:**
   ```bash
   # Decode and check size
   echo "BASE64_STRING" | base64 -d | wc -c
   # Should be 800-1500+ bytes for complete attestation
   ```

### Problem: "Missing required field in attestation object"

**Symptoms:**
```
Error: Attestation decoding failed
  Missing required field in attestation object. All keys: fmt, attStmt, -791634803
```

**Solutions:**
1. **This is usually a decoder issue, not your data:**
   - The decoder should handle Apple's non-standard CBOR encoding
   - Check that you're using the latest version of the decoder

2. **Verify attestation format:**
   - Ensure the attestation is from App Attest (not WebAuthn)
   - Format should be "apple-appattest"

### Problem: Colors not showing

**Symptoms:**
- Output appears plain text even in terminal

**Solutions:**
1. **Check if output is piped:**
   ```bash
   # Colors auto-disable when piped
   ./AppAttestDecoderCLI pretty --base64 "BLOB" | cat  # No colors
   ./AppAttestDecoderCLI pretty --base64 "BLOB"          # Has colors
   ```

2. **Force colors (if needed):**
   - Currently, colors are auto-detected
   - Use `--no-color` to explicitly disable

3. **Check terminal support:**
   ```bash
   # Test if terminal supports colors
   echo -e "\033[36mTest\033[0m"  # Should show cyan text
   ```

### Problem: "Unable to find module dependency"

**Symptoms:**
```
error: Unable to find module dependency: 'AppAttestCore'
```

**Solutions:**
1. **Build the framework first:**
   ```bash
   xcodebuild -target AppAttestCore -configuration Debug
   ```

2. **Clean and rebuild:**
   ```bash
   xcodebuild clean
   xcodebuild -scheme AppAttestDecoderCLI -configuration Debug
   ```

### Problem: Binary not found

**Symptoms:**
```
zsh: command not found: AppAttestDecoderCLI
```

**Solutions:**
1. **Use full path:**
   ```bash
   ./build/Debug/AppAttestDecoderCLI pretty --base64 "BLOB"
   ```

2. **Add to PATH:**
   ```bash
   export PATH="$PATH:$(pwd)/build/Debug"
   ```

3. **Create symlink:**
   ```bash
   ln -s $(pwd)/build/Debug/AppAttestDecoderCLI /usr/local/bin/appattest-decode
   ```

---

## Swift Package Manager Usage

The `AppAttestCore` framework can be used as a Swift Package dependency.

### Adding as a Dependency

**In Xcode:**
1. File → Add Packages...
2. Enter the repository URL
3. Select version or branch
4. Add to your target

**In Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AppAttestDecoderCLI.git", from: "1.0.0")
]
```

### Usage in Code

```swift
import AppAttestCore

let decoder = AppAttestDecoder(teamID: "YOUR_TEAM_ID")

// Decode attestation
let attestationData = Data(base64Encoded: base64String)!
let attestation = try decoder.decodeAttestationObject(attestationData)

// Decode assertion
let assertionData = Data(base64Encoded: assertionBase64String)!
let assertion = try decoder.decodeAssertion(assertionData)

// Pretty print
print(attestation.prettyPrint())
print(assertion.prettyPrint())
```

---

## Integration Examples

### Python Integration

```python
import subprocess
import json

def decode_attestation(base64_string):
    """Decode attestation using CLI tool."""
    result = subprocess.run(
        ['./AppAttestDecoderCLI', 'pretty', '--base64', base64_string],
        capture_output=True,
        text=True
    )
    return result.stdout

# Usage
attestation_blob = "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."
output = decode_attestation(attestation_blob)
print(output)
```

### Shell Script Integration

```bash
#!/bin/bash

# Function to validate attestation
validate_attestation() {
    local base64_blob="$1"
    local output
    
    output=$(./AppAttestDecoderCLI pretty --base64 "$base64_blob" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "Attestation is valid"
        echo "$output"
        return 0
    else
        echo "Attestation validation failed"
        echo "$output" >&2
        return 1
    fi
}

# Usage
validate_attestation "BASE64_STRING"
```

### Node.js Integration

```javascript
const { execSync } = require('child_process');

function decodeAttestation(base64String) {
    try {
        const output = execSync(
            `./AppAttestDecoderCLI pretty --base64 "${base64String}"`,
            { encoding: 'utf-8' }
        );
        return output;
    } catch (error) {
        throw new Error(`Decoding failed: ${error.message}`);
    }
}

// Usage
const attestationBlob = "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0...";
const decoded = decodeAttestation(attestationBlob);
console.log(decoded);
```

---

## Best Practices

1. **Always use verbose mode for debugging:**
   ```bash
   ./AppAttestDecoderCLI pretty --base64 "BLOB" --verbose
   ```

2. **Save output for analysis:**
   ```bash
   ./AppAttestDecoderCLI pretty --file attestation.txt > analysis.txt
   ```

3. **Validate base64 before decoding:**
   ```bash
   echo "BASE64_STRING" | base64 -d > /dev/null && echo "Valid"
   ```

4. **Use file input for large blobs:**
   - Avoid command-line length limits
   - Easier to manage and reuse

5. **Pipe to grep for specific fields:**
   ```bash
   ./AppAttestDecoderCLI pretty --file attestation.txt | grep "rpIdHash"
   ```

---

## Additional Resources

- **Project README:** See `README.md` for architecture and security notes
- **Test Suite:** See `AppAttestCoreTests.swift` for test examples
- **Apple Documentation:** [App Attest Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions)

---

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review test cases in `AppAttestCoreTests.swift`
3. Verify you're using a complete, valid attestation blob
4. Check that the base64 string is properly formatted

