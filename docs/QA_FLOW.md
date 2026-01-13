# QA Flow - AppAttestDecoderCLI Testing Checklist

Comprehensive quality assurance testing flow for AppAttestDecoderCLI before submission or release.

## Table of Contents

1. [Pre-Testing Setup](#pre-testing-setup)
2. [Build Verification](#build-verification)
3. [Unit Test Execution](#unit-test-execution)
4. [CLI Command Testing](#cli-command-testing)
5. [Pretty Print Command Testing](#pretty-print-command-testing)
6. [Error Handling Testing](#error-handling-testing)
7. [Integration Testing](#integration-testing)
8. [Performance Testing](#performance-testing)
9. [Documentation Verification](#documentation-verification)
10. [Final Checklist](#final-checklist)

---

## Pre-Testing Setup

### Environment Requirements

- [ ] macOS 12.0 or later installed
- [ ] Xcode 14.0 or later installed
- [ ] Swift 5.7 or later available
- [ ] Terminal access with bash/zsh
- [ ] Test attestation blob available (base64 string)

### Test Data Preparation

- [ ] Valid attestation blob (complete, device-generated)
- [ ] Invalid base64 string for error testing
- [ ] Truncated attestation blob (for error testing)
- [ ] Empty file for edge case testing
- [ ] Large attestation blob (>5000 bytes) for performance testing

### Build Environment

```bash
# Verify Xcode is installed
xcodebuild -version

# Verify Swift is available
swift --version

# Clean previous builds
cd /path/to/AppAttestDecoderCLI
xcodebuild clean
```

---

## Build Verification

### Test 1: Clean Build

**Objective:** Verify the project builds without errors

**Steps:**
1. Open `AppAttestDecoderCLI.xcodeproj` in Xcode
2. Select "AppAttestDecoderCLI" scheme
3. Select "My Mac" as destination
4. Press `Command+Shift+K` to clean
5. Press `Command+B` to build

**Expected Result:**
- [ ] Build succeeds with no errors
- [ ] Build succeeds with no warnings (or only acceptable warnings)
- [ ] Binary created at `build/Debug/AppAttestDecoderCLI`

**Command Line:**
```bash
xcodebuild -scheme AppAttestDecoderCLI -configuration Debug clean build
```

**Pass Criteria:** Build completes successfully, binary exists and is executable

---

### Test 2: Framework Build

**Objective:** Verify AppAttestCore framework builds independently

**Steps:**
```bash
xcodebuild -target AppAttestCore -configuration Debug
```

**Expected Result:**
- [ ] Framework builds successfully
- [ ] No compilation errors
- [ ] Framework binary created

**Pass Criteria:** Framework builds without errors

---

### Test 3: Release Build

**Objective:** Verify release configuration builds

**Steps:**
```bash
xcodebuild -scheme AppAttestDecoderCLI -configuration Release
```

**Expected Result:**
- [ ] Release build succeeds
- [ ] Binary is optimized
- [ ] Binary size is reasonable

**Pass Criteria:** Release build completes successfully

---

## Unit Test Execution

### Test 4: Run All Unit Tests

**Objective:** Verify all unit tests pass

**Steps:**
1. In Xcode: Select "AppAttestCoreTests" scheme
2. Press `Command+U` to run tests
3. Or via command line:
   ```bash
   xcodebuild test -scheme AppAttestCore -destination 'platform=macOS'
   ```

**Expected Result:**
- [ ] All tests pass (100% pass rate)
- [ ] No test failures
- [ ] Test execution completes in reasonable time (<30 seconds)

**Test Coverage:**
- [ ] `testDecodeAttestationObject` - Valid attestation decoding
- [ ] `testDecodeTruncatedCBOR` - Error handling for truncated data
- [ ] `testDecodeMissingRequiredFields` - Missing field detection
- [ ] `testDecodeIntegerKeyFallback` - Apple CBOR quirk handling
- [ ] `testAttStmtX5cExtraction` - Certificate chain extraction
- [ ] `testAuthenticatorDataFlags` - Flag semantics
- [ ] `testDecodeInvalidCBOR` - Invalid CBOR handling
- [ ] All `testPrettyPrint*` tests - Pretty print functionality

**Pass Criteria:** All tests pass, no failures or crashes

---

### Test 5: Test Coverage

**Objective:** Verify adequate test coverage

**Steps:**
```bash
xcodebuild test -scheme AppAttestCore -destination 'platform=macOS' \
  -enableCodeCoverage YES
```

**Expected Result:**
- [ ] Code coverage ≥ 80% (as per project requirements)
- [ ] Critical paths are covered
- [ ] Error handling paths are tested

**Pass Criteria:** Coverage meets project standards

---

## CLI Command Testing

### Test 6: Help/Usage Command

**Objective:** Verify usage information displays correctly

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI
# or
./build/Debug/AppAttestDecoderCLI invalid_command
```

**Expected Result:**
- [ ] Usage information is displayed
- [ ] All commands are listed
- [ ] All options are documented
- [ ] Examples are provided

**Pass Criteria:** Usage information is clear and complete

---

### Test 7: Version Command

**Objective:** Verify version flag displays correctly

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI --version
# or
./build/Debug/AppAttestDecoderCLI -V
```

**Expected Result:**
- [ ] Command executes successfully
- [ ] Output shows: "AppAttestDecoderCLI version 1.0.0"
- [ ] Exit code is 0
- [ ] No other output is produced

**Pass Criteria:** Version information displays correctly and exits cleanly

---

### Test 8: Self-Test Command

**Objective:** Verify self-test command works

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI selftest
```

**Expected Result:**
- [ ] Command executes successfully
- [ ] Output shows:
  - [ ] "base64 decode OK"
  - [ ] "no DeviceCheck linkage"
  - [ ] "deterministic CLI path OK"
- [ ] Exit code is 0

**Pass Criteria:** Self-test passes all checks

---

### Test 9: Attest Command - Valid Input

**Objective:** Verify attest command decodes valid attestation

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI attest --base64 "VALID_BASE64_STRING"
```

**Expected Result:**
- [ ] Command executes without errors
- [ ] Output shows attestation structure
- [ ] Format field is displayed
- [ ] Authenticator data is shown
- [ ] Attestation statement is shown
- [ ] Exit code is 0

**Pass Criteria:** Valid attestation is decoded and displayed correctly

---

### Test 10: Attest Command - File Input

**Objective:** Verify file input method works

**Steps:**
```bash
# Create test file
echo "VALID_BASE64_STRING" > /tmp/test_attestation.txt

# Run command
./build/Debug/AppAttestDecoderCLI attest --file /tmp/test_attestation.txt
```

**Expected Result:**
- [ ] File is read correctly
- [ ] Base64 is decoded
- [ ] Output matches command-line input
- [ ] Exit code is 0

**Pass Criteria:** File input works identically to command-line input

---

### Test 11: Attest Command - STDIN Input

**Objective:** Verify STDIN input method works

**Steps:**
```bash
echo "VALID_BASE64_STRING" | ./build/Debug/AppAttestDecoderCLI attest
```

**Expected Result:**
- [ ] STDIN is read correctly
- [ ] Base64 is decoded
- [ ] Output matches other input methods
- [ ] Exit code is 0

**Pass Criteria:** STDIN input works correctly

---

### Test 12: Attest Command - Hex Output

**Objective:** Verify hex dump output format

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI attest --base64 "VALID_BASE64" --hex
```

**Expected Result:**
- [ ] Hex dump is displayed
- [ ] Format is readable (bytes per line)
- [ ] All data is shown
- [ ] Exit code is 0

**Pass Criteria:** Hex output is correctly formatted

---

### Test 13: Attest Command - JSON Output

**Objective:** Verify JSON output format

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI attest --base64 "VALID_BASE64" --json
```

**Expected Result:**
- [ ] Valid JSON is output
- [ ] JSON can be parsed by `jq` or similar
- [ ] All fields are present
- [ ] Exit code is 0

**Pass Criteria:** JSON output is valid and parseable

---

## Pretty Print Command Testing

### Test 21: Pretty Print - Basic Functionality

**Objective:** Verify pretty print produces formatted output

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64"
```

**Expected Result:**
- [ ] Output is formatted hierarchically
- [ ] Indentation is consistent (2 spaces)
- [ ] All major fields are present:
  - [ ] `format`
  - [ ] `authenticatorData`
  - [ ] `attestationStatement`
  - [ ] `rpIdHash`
  - [ ] `flags`
  - [ ] `x5c`
- [ ] Exit code is 0

**Pass Criteria:** Output is well-formatted and complete

---

### Test 22: Pretty Print - Colorization

**Objective:** Verify colorization works in terminal

**Steps:**
```bash
# In terminal (not piped)
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64"
```

**Expected Result:**
- [ ] Colors are displayed in terminal
- [ ] Field names are colored (cyan)
- [ ] Values are appropriately colored
- [ ] Colors enhance readability

**Verification:**
```bash
# Check for ANSI codes
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" | grep -q $'\033' && echo "Colors present"
```

**Pass Criteria:** Colors are displayed when outputting to terminal

---

### Test 21: Pretty Print - Color Auto-Disable

**Objective:** Verify colors are disabled when piped

**Steps:**
```bash
# Pipe to file
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" > /tmp/output.txt

# Check for ANSI codes
grep -q $'\033' /tmp/output.txt && echo "FAIL: Colors in file" || echo "PASS: No colors in file"
```

**Expected Result:**
- [ ] No ANSI color codes in piped output
- [ ] Output is still readable
- [ ] All content is present

**Pass Criteria:** Colors are automatically disabled when piped

---

### Test 22: Pretty Print - No-Color Flag

**Objective:** Verify --no-color flag works

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" --no-color | \
  grep -q $'\033' && echo "FAIL" || echo "PASS"
```

**Expected Result:**
- [ ] No ANSI codes in output
- [ ] Output is identical to non-colorized version
- [ ] Exit code is 0

**Pass Criteria:** --no-color flag disables colors

---

### Test 21: Pretty Print - Verbose Mode

**Objective:** Verify verbose logging works

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" --verbose
```

**Expected Result:**
- [ ] Debug information is printed to stderr
- [ ] Base64 string length is shown
- [ ] Decoded data length is shown
- [ ] Main output is still printed to stdout
- [ ] Exit code is 0

**Verification:**
```bash
# Check stderr has debug info
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" --verbose 2>&1 | grep -q "Debug:" && echo "PASS"
```

**Pass Criteria:** Verbose mode shows debug information

---

### Test 22: Pretty Print - Hex Formatting

**Objective:** Verify hex data is formatted correctly

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" | grep "rpIdHash"
```

**Expected Result:**
- [ ] Hex strings have spaces every 4 bytes
- [ ] Format: `a1b2c3d4 e5f6a7b8 ...`
- [ ] Byte count is shown: `(32 bytes)`
- [ ] All hex data follows this pattern

**Pass Criteria:** Hex formatting is consistent and readable

---

### Test 21: Pretty Print - Flags Display

**Objective:** Verify flags are displayed correctly

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" | grep -A 10 "flags"
```

**Expected Result:**
- [ ] `rawValue` is shown (hex and decimal)
- [ ] `userPresent` is shown (boolean)
- [ ] `userVerified` is shown (boolean)
- [ ] `attestedCredentialData` is shown (boolean)
- [ ] `extensionsIncluded` is shown (boolean)

**Pass Criteria:** All flags are displayed with both raw and interpreted values

---

### Test 22: Pretty Print - Certificate Chain

**Objective:** Verify certificate chain is displayed

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" | grep -A 5 "x5c"
```

**Expected Result:**
- [ ] `x5c` array is shown
- [ ] Certificate indices are shown: `[0]`, `[1]`, etc.
- [ ] Certificate sizes are shown
- [ ] All certificates in chain are displayed

**Pass Criteria:** Certificate chain is fully displayed

---

## Error Handling Testing

### Test 23: Invalid Base64

**Objective:** Verify error handling for invalid base64

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 "INVALID!!!"
```

**Expected Result:**
- [ ] Error message is displayed
- [ ] Error goes to stderr
- [ ] Message includes "Invalid base64 string"
- [ ] Base64 length is shown
- [ ] Exit code is 1

**Pass Criteria:** Invalid base64 is handled gracefully with clear error message

---

### Test 24: Truncated Attestation

**Objective:** Verify error handling for truncated data

**Steps:**
```bash
# Use incomplete base64 (first 100 chars)
TRUNCATED=$(echo "VALID_BASE64" | cut -c1-100)
./build/Debug/AppAttestDecoderCLI pretty --base64 "$TRUNCATED"
```

**Expected Result:**
- [ ] CBOR decoding error is shown
- [ ] Error message includes truncation details
- [ ] Expected/remaining bytes are shown
- [ ] Offset is shown
- [ ] Exit code is 1

**Pass Criteria:** Truncated data produces informative error

---

### Test 25: Empty Input

**Objective:** Verify handling of empty input

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --base64 ""
echo "" | ./build/Debug/AppAttestDecoderCLI pretty
```

**Expected Result:**
- [ ] Appropriate error is shown
- [ ] No crash occurs
- [ ] Exit code is 1

**Pass Criteria:** Empty input is handled gracefully

---

### Test 26: Missing File

**Objective:** Verify error handling for missing file

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI pretty --file /nonexistent/file.txt
```

**Expected Result:**
- [ ] Error message is displayed
- [ ] File path is mentioned in error
- [ ] Exit code is 1

**Pass Criteria:** Missing file produces clear error

---

### Test 27: Invalid Command

**Objective:** Verify handling of invalid command

**Steps:**
```bash
./build/Debug/AppAttestDecoderCLI invalid_command
```

**Expected Result:**
- [ ] Usage information is displayed
- [ ] Error message indicates unknown command
- [ ] Exit code is 1

**Pass Criteria:** Invalid command shows usage help

---

## Integration Testing

### Test 28: Pipeline Integration

**Objective:** Verify tool works in shell pipelines

**Steps:**
```bash
# Test piping
echo "VALID_BASE64" | ./build/Debug/AppAttestDecoderCLI pretty | head -20

# Test with grep
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" | grep "format"

# Test with file redirection
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" > /tmp/output.txt
```

**Expected Result:**
- [ ] Piping works correctly
- [ ] Colors are disabled when piped
- [ ] File redirection works
- [ ] No errors in pipeline

**Pass Criteria:** Tool integrates well with shell pipelines

---

### Test 29: Script Integration

**Objective:** Verify tool works in shell scripts

**Steps:**
```bash
# Create test script
cat > /tmp/test_script.sh << 'EOF'
#!/bin/bash
OUTPUT=$(./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64")
if [ $? -eq 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
fi
EOF

chmod +x /tmp/test_script.sh
/tmp/test_script.sh
```

**Expected Result:**
- [ ] Script executes successfully
- [ ] Exit codes are correct
- [ ] Output can be captured

**Pass Criteria:** Tool works correctly in scripts

---

### Test 30: Large Input Handling

**Objective:** Verify tool handles large attestation blobs

**Steps:**
```bash
# Use large attestation blob (>5000 bytes when decoded)
./build/Debug/AppAttestDecoderCLI pretty --base64 "LARGE_BASE64" --verbose
```

**Expected Result:**
- [ ] Large blob is processed
- [ ] No memory issues
- [ ] Output is complete
- [ ] Performance is acceptable (<5 seconds)

**Pass Criteria:** Large inputs are handled efficiently

---

## Performance Testing

### Test 31: Decode Performance

**Objective:** Verify decoding performance is acceptable

**Steps:**
```bash
time ./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64"
```

**Expected Result:**
- [ ] Decoding completes in <2 seconds for typical attestation
- [ ] No excessive memory usage
- [ ] CPU usage is reasonable

**Pass Criteria:** Performance meets requirements

---

### Test 32: Pretty Print Performance

**Objective:** Verify pretty printing performance

**Steps:**
```bash
# Measure pretty print time
time ./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" > /dev/null
```

**Expected Result:**
- [ ] Pretty printing completes in <1 second
- [ ] No performance degradation with colorization

**Pass Criteria:** Pretty printing is fast enough

---

## Documentation Verification

### Test 33: README Completeness

**Objective:** Verify README is complete and accurate

**Checklist:**
- [ ] Installation instructions are present
- [ ] Usage examples are provided
- [ ] All commands are documented
- [ ] Security notes are included
- [ ] Troubleshooting section exists
- [ ] Examples are tested and work

**Pass Criteria:** Documentation is complete and accurate

---

### Test 34: HOW_TO_USE Completeness

**Objective:** Verify HOW_TO_USE.md is comprehensive

**Checklist:**
- [ ] All commands are explained
- [ ] Input methods are documented
- [ ] Output formats are described
- [ ] Examples are provided
- [ ] Troubleshooting section is helpful
- [ ] Integration examples work

**Pass Criteria:** HOW_TO_USE.md is comprehensive

---

### Test 35: Code Comments

**Objective:** Verify code is well-commented

**Checklist:**
- [ ] Public APIs are documented
- [ ] Complex logic has comments
- [ ] Error handling is explained
- [ ] Examples are in comments where helpful

**Pass Criteria:** Code is adequately documented

---

## Version and Distribution Verification

### Test: Version Information

**Objective:** Verify version information is correct and accessible

**Steps:**
```bash
# Check CLI version
./build/Debug/AppAttestDecoderCLI --version

# Verify SPM package
swift package describe
```

**Expected Result:**
- [ ] CLI version displays as "1.0.0"
- [ ] SPM package description shows correct version
- [ ] Package.swift is valid

**Pass Criteria:** Version information is consistent across all sources

---

### Test: Swift Package Manager

**Objective:** Verify SPM package builds and can be used as dependency

**Steps:**
```bash
# Test SPM build
swift build

# Test SPM test
swift test
```

**Expected Result:**
- [ ] Package builds successfully
- [ ] Tests run (may require code signing setup)
- [ ] Package can be imported in other projects

**Pass Criteria:** SPM package is functional

---

## Final Checklist

### Pre-Submission Verification

- [ ] All tests pass (100% pass rate)
- [ ] No compiler warnings (or only acceptable ones)
- [ ] Code coverage ≥ 80%
- [ ] All commands work as documented
- [ ] Error handling is comprehensive
- [ ] Documentation is complete
- [ ] Examples are tested and work
- [ ] Performance is acceptable
- [ ] No memory leaks (checked with Instruments)
- [ ] Binary is properly signed (if required)

### Build Artifacts

- [ ] Debug binary builds successfully
- [ ] Release binary builds successfully
- [ ] Framework builds independently
- [ ] All targets compile without errors

### Documentation

- [ ] README.md is up to date
- [ ] docs/HOW_TO_USE.md is complete
- [ ] docs/QA_FLOW.md is accurate
- [ ] Code comments are adequate
- [ ] Examples are tested

### Testing

- [ ] All unit tests pass
- [ ] All CLI tests pass
- [ ] Error cases are tested
- [ ] Edge cases are tested
- [ ] Integration tests pass

### Quality

- [ ] Code follows project style guidelines
- [ ] No hardcoded values
- [ ] Error messages are user-friendly
- [ ] Output is well-formatted
- [ ] Tool is user-friendly

---

## Test Execution Summary

### Quick Test Run

Run this script to execute all critical tests:

```bash
#!/bin/bash
# Quick QA test script

echo "=== Build Verification ==="
xcodebuild -scheme AppAttestDecoderCLI -configuration Debug clean build

echo "=== Unit Tests ==="
xcodebuild test -scheme AppAttestCore -destination 'platform=macOS'

echo "=== CLI Tests ==="
./build/Debug/AppAttestDecoderCLI selftest
./build/Debug/AppAttestDecoderCLI pretty --base64 "VALID_BASE64" --verbose

echo "=== Error Handling ==="
./build/Debug/AppAttestDecoderCLI pretty --base64 "INVALID" 2>&1 | grep -q "Error" && echo "PASS" || echo "FAIL"

echo "=== QA Complete ==="
```

### Test Results Template

```
QA Test Results - AppAttestDecoderCLI
Date: ___________
Tester: ___________
Version: ___________

Build Tests:        [ ] PASS  [ ] FAIL
Unit Tests:         [ ] PASS  [ ] FAIL
CLI Tests:          [ ] PASS  [ ] FAIL
Error Handling:     [ ] PASS  [ ] FAIL
Integration:        [ ] PASS  [ ] FAIL
Performance:        [ ] PASS  [ ] FAIL
Documentation:      [ ] PASS  [ ] FAIL

Overall:            [ ] APPROVED  [ ] NEEDS WORK

Notes:
_______________________________________
_______________________________________
_______________________________________
```

---

## Release Checklist

Before creating a GitHub release:

### Pre-Release Verification

- [ ] All unit tests pass (100% pass rate)
- [ ] CI/CD pipeline passes (GitHub Actions)
- [ ] Version number matches across all files:
  - [ ] `README.md` shows correct version
  - [ ] `CHANGELOG.md` has entry for this version
  - [ ] `main.swift` has correct version constant
  - [ ] `Package.swift` has correct version
- [ ] Documentation is up to date:
  - [ ] `README.md` is current
  - [ ] `docs/HOW_TO_USE.md` is current
  - [ ] `docs/TEST_APP_GUIDE.md` is current
  - [ ] `docs/QA_FLOW.md` is current
  - [ ] `docs/PROJECT_AUDIT.md` reflects current state
- [ ] No TODOs or placeholder text in documentation
- [ ] All cross-references between docs are correct
- [ ] License file is present and correct

### Git Operations

- [ ] All changes committed
- [ ] Working directory is clean (`git status` shows no uncommitted changes)
- [ ] Git tag created: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Tag pushed to remote: `git push origin v1.0.0`

### GitHub Release

- [ ] GitHub Release created with:
  - [ ] Release title: "v1.0.0"
  - [ ] Release notes from `CHANGELOG.md`
  - [ ] Tag points to correct commit
  - [ ] Release marked as "Latest release" (if appropriate)

### Post-Release

- [ ] Verify release appears on GitHub
- [ ] Verify SPM package resolves correctly with new version
- [ ] Verify documentation links work correctly
- [ ] Update any external references if needed

---

## Sign-Off

Once all tests pass:

- [ ] All checklist items completed
- [ ] All tests documented
- [ ] Issues logged and resolved
- [ ] Ready for submission/release

**QA Sign-Off:** _________________  Date: ___________

