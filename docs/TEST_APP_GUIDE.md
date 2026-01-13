# Test App Guide - Generating App Attest Artifacts

Complete guide for using a companion test app to generate App Attest attestation and assertion objects for testing with the AppAttestDecoderCLI tool.

## Table of Contents

1. [Purpose](#purpose)
2. [Apple Developer Account Setup](#apple-developer-account-setup)
3. [Xcode Test App Setup](#xcode-test-app-setup)
4. [Generating Attestations](#generating-attestations)
5. [Generating Assertions](#generating-assertions)
6. [Using the CLI with Test App Output](#using-the-cli-with-test-app-output)
7. [Common Mistakes & Gotchas](#common-mistakes--gotchas)
8. [Scope Disclaimer](#scope-disclaimer)

---

## Purpose

A companion test app is used to generate real App Attest attestation and assertion objects. These artifacts are necessary for:

- **Testing the decoder**: Validating that the CLI correctly parses real device-generated artifacts
- **Learning App Attest structure**: Understanding how Apple encodes attestation and assertion data
- **Backend development**: Testing server-side validation logic with real artifacts
- **Debugging**: Inspecting attestation structure when troubleshooting integration issues

### Requirements

- **Physical Apple device** (iPhone or iPad running iOS 14.0 or later)
- **Apple Developer Account** (free or paid)
- **Xcode** (14.0 or later)
- **App Attest capability** enabled for your App ID

**Critical**: App Attest does NOT work on simulators. You must use a physical device.

---

## Apple Developer Account Setup

### Step 1: Enroll in Apple Developer Program

1. Visit [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple ID
3. Enroll in the Apple Developer Program (free account is sufficient for development)
4. Accept the Apple Developer Agreement

### Step 2: Create an App ID

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Click the "+" button to create a new identifier
3. Select "App IDs" and click Continue
4. Select "App" and click Continue
5. Enter a description (e.g., "App Attest Test App")
6. Enter a Bundle ID (e.g., `com.yourcompany.appattesttest`)
7. Under Capabilities, check "App Attest"
8. Click Continue, then Register

**Important**: The Bundle ID you choose will be used as the RP ID (Relying Party ID) in attestations. Make note of it.

### Step 3: Enable App Attest Capability

The App Attest capability is automatically enabled when you create the App ID with it checked. Verify it's enabled:

1. Go to your App ID in the developer portal
2. Confirm "App Attest" appears in the Capabilities list
3. If not present, edit the App ID and enable it

### Step 4: Create Provisioning Profile (if needed)

For development:
1. Go to Profiles section
2. Create a Development profile for your App ID
3. Select your development certificate
4. Select your test device
5. Download and install the profile

Xcode can automatically manage provisioning profiles if you have Automatic Signing enabled.

---

## Xcode Test App Setup

### Step 1: Open the Test App Project

If using the companion test app in this repository:

1. Open `AppAttestDecoderCLI.xcodeproj` in Xcode
2. Select the `AppAttestDecoderTestApp` target
3. Ensure the project is configured for iOS deployment

### Step 2: Configure Signing & Capabilities

1. Select the `AppAttestDecoderTestApp` target in Xcode
2. Go to the "Signing & Capabilities" tab
3. Select your Development Team from the dropdown
4. Xcode will automatically create a Bundle Identifier (or use the one you created)
5. Ensure "Automatically manage signing" is checked (recommended)

### Step 3: Add App Attest Capability

1. In the "Signing & Capabilities" tab, click "+ Capability"
2. Search for "App Attest"
3. Double-click "App Attest" to add it
4. Verify "App Attest" appears in the Capabilities list

**Note**: If App Attest doesn't appear in the capability list, ensure:
- Your App ID has App Attest enabled in the developer portal
- Your provisioning profile includes the App Attest entitlement
- You're signed in with the correct Apple Developer account

### Step 4: Build and Run on Device

1. Connect your physical iOS device via USB
2. Select your device from the device dropdown in Xcode
3. Click the Run button (or press Command+R)
4. If prompted, trust the developer certificate on your device:
   - Settings → General → VPN & Device Management
   - Tap your developer certificate
   - Tap "Trust"

The app should launch on your device.

---

## Generating Attestations

### Understanding Attestations

An attestation object is generated when:
- A new App Attest key is created
- The app calls `DCAppAttestService.generateKey()`
- The app then calls `DCAppAttestService.attestKey(_:clientDataHash:)` with a challenge

The attestation object proves that:
- The key was created on a genuine Apple device
- The device is running a legitimate iOS installation
- The app is signed with a valid developer certificate

### Generating an Attestation in the Test App

1. **Launch the test app** on your physical device
2. **Tap "Generate Key"** (or equivalent button in your test app)
   - This creates a new App Attest key
   - The key ID is typically displayed or stored
3. **Tap "Attest Key"** (or equivalent button)
   - This generates the attestation object
   - The app should display the base64-encoded attestation blob
4. **Copy the base64 string**
   - The attestation blob is typically 800-2000+ bytes when decoded
   - Ensure you copy the complete string (it may be very long)

### Example Console Output

The test app may display output like:

```
Key ID: 8NtgGXwpsqzAEIyTiM8w4xHgUAYEw+pUYLKG9d12ih8=
Attestation Object (base64):
o2NmbXRvYXBwbGUtYXBwYXR0ZXN0Z2F0dFN0bXSiY3g1Y4JZBBIwggQOMIIDlKADAgECAgYBm7S3gl4w...
[very long base64 string continues]
```

### What to Look For

- **Complete base64 string**: Should be 1000+ characters typically
- **No truncation**: The string should end with valid base64 padding (`=`, `==`, or no padding)
- **Key ID**: Usually 32 bytes when decoded (44 characters in base64)

---

## Generating Assertions

### Understanding Assertions

An assertion object is generated when:
- An existing App Attest key is used to sign data
- The app calls `DCAppAttestService.generateAssertion(_:clientDataHash:)` with:
  - A previously created key ID
  - A client data hash (SHA256 of a challenge)

Assertions are used for:
- Authenticating subsequent requests after initial attestation
- Proving the device still controls the key
- Including authenticator data (RP ID hash, flags, sign count)

### Generating an Assertion in the Test App

1. **Ensure you have a previously generated key**
   - You must have completed the attestation step first
   - The key ID should be stored or displayed
2. **Tap "Generate Assertion"** (or equivalent button)
   - The app will use the stored key ID
   - It will generate a client data hash from a challenge
3. **Copy the base64-encoded assertion blob**
   - Assertions are typically smaller than attestations (200-500 bytes when decoded)
   - The assertion is a COSE_Sign1 message

### Example Console Output

The test app may display output like:

```
Key ID: 8NtgGXwpsqzAEIyTiM8w4xHgUAYEw+pUYLKG9d12ih8=
Assertion Object (base64):
h'84a10126a0f658...' [base64 string]
```

### What to Look For

- **Complete base64 string**: Typically 300-700 characters
- **Key ID matches**: Should match the key ID from the attestation step
- **Client data hash**: May be displayed separately (32 bytes, 44 base64 characters)

---

## Using the CLI with Test App Output

### Decoding Attestations

Once you have a base64 attestation blob from the test app:

```bash
# Pretty-print the attestation
./AppAttestDecoderCLI pretty --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..."

# Or save to file first
echo "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..." > attestation.txt
./AppAttestDecoderCLI pretty --file attestation.txt

# JSON output for programmatic processing
./AppAttestDecoderCLI attest --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..." --json

# Hex dump for binary inspection
./AppAttestDecoderCLI attest --base64 "o2NmbXRvYXBwbGUtYXBwYXR0ZXN0..." --hex
```

### Decoding Assertions

Once you have a base64 assertion blob from the test app:

```bash
# Pretty-print the assertion
./AppAttestDecoderCLI assert --base64 "h'84a10126a0f658..."

# JSON output
./AppAttestDecoderCLI assert --base64 "h'84a10126a0f658..." --json

# Save to file and decode
echo "h'84a10126a0f658..." > assertion.txt
./AppAttestDecoderCLI assert --file assertion.txt
```

### Example Pipeline

A typical workflow:

```bash
# 1. Generate attestation in test app, copy base64
# 2. Save to file
echo "ATTESTATION_BASE64" > test_attestation.txt

# 3. Decode and inspect
./AppAttestDecoderCLI pretty --file test_attestation.txt

# 4. Extract specific fields (using grep/jq if JSON)
./AppAttestDecoderCLI attest --file test_attestation.txt --json | jq '.format'
./AppAttestDecoderCLI attest --file test_attestation.txt --json | jq '.authenticatorData.rpIdHashLength'

# 5. Generate assertion in test app, copy base64
# 6. Decode assertion
echo "ASSERTION_BASE64" > test_assertion.txt
./AppAttestDecoderCLI assert --file test_assertion.txt
```

### Verifying RP ID Hash

The RP ID hash in the attestation should match SHA256 of your bundle identifier:

```bash
# Extract RP ID hash from attestation
./AppAttestDecoderCLI attest --file test_attestation.txt --json | jq '.authenticatorData.rpIdHash'

# Compute expected RP ID hash (example)
echo -n "com.yourcompany.appattesttest" | shasum -a 256
```

The hash values should match (accounting for hex vs base64 encoding).

---

## Common Mistakes & Gotchas

### Simulator Usage

**Problem**: App Attest does not work on iOS Simulator.

**Symptom**: 
- `DCAppAttestService.isSupported` returns `false`
- Key generation fails
- Attestation generation fails

**Solution**: Always use a physical device. There is no workaround.

### Missing App Attest Entitlement

**Problem**: App Attest capability not properly configured.

**Symptoms**:
- `DCAppAttestService.isSupported` returns `false`
- Key generation fails with entitlement error

**Solution**:
1. Verify App Attest is enabled in your App ID in developer portal
2. Verify App Attest capability is added in Xcode
3. Verify provisioning profile includes the entitlement
4. Clean build folder and rebuild

### RP ID Hash Confusion

**Problem**: RP ID hash doesn't match expected value.

**Explanation**: 
- RP ID is your app's bundle identifier
- RP ID hash is SHA256 of the bundle identifier (as UTF-8 bytes)
- The hash appears in `authenticatorData.rpIdHash` (32 bytes)

**Solution**: 
- Verify you're using the correct bundle identifier
- Compute SHA256 of the bundle ID and compare
- Remember: RP ID is the bundle ID, not a domain

### Expecting Certificate Chains in Assertions

**Problem**: Looking for x5c certificate chain in assertion objects.

**Explanation**:
- **Attestations** contain certificate chains (x5c) in `attestationStatement.x5c`
- **Assertions** do NOT contain certificate chains
- Assertions are COSE_Sign1 messages with signature, but no certificates

**Solution**: 
- Use attestations when you need certificate chain validation
- Use assertions for subsequent authentications (they reference the original attestation key)

### Sign Count Misunderstanding

**Problem**: Confusion about what sign count means in assertions.

**Explanation**:
- Sign count is a counter that increments with each assertion
- It's stored in `authenticatorData.signCount` (4 bytes, big-endian)
- It helps detect replay attacks (count should always increase)

**Solution**:
- Track sign count on your backend
- Reject assertions with sign count <= previous value
- First assertion typically has sign count = 0 or 1

### Base64 Encoding Issues

**Problem**: Truncated or malformed base64 strings.

**Symptoms**:
- CLI reports "Invalid base64" error
- CBOR decoding fails with truncation error
- Missing fields in decoded output

**Solution**:
- Ensure you copy the complete base64 string (may be very long)
- Check for line breaks or whitespace (remove them)
- Verify base64 padding is correct (`=`, `==`, or none)
- Test with: `echo "BASE64" | base64 -d | wc -c` (should decode successfully)

### Challenge/Nonce Mismatch

**Problem**: Backend validation fails due to nonce mismatch.

**Explanation**:
- Attestations include a nonce in the certificate extension
- Nonce = SHA256(authData + clientDataHash)
- clientDataHash = SHA256(server challenge)
- The challenge used in the test app must match what your backend expects

**Solution**:
- Use the same challenge on both client (test app) and server
- Verify nonce computation matches Apple's specification
- See README Security Notes for complete validation steps

---

## Scope Disclaimer

### What the Test App Does

- Generates real App Attest keys on physical devices
- Creates attestation objects with valid certificate chains
- Generates assertion objects for authentication
- Provides base64-encoded artifacts for testing

### What the Test App Does NOT Do

- Validate attestations or assertions
- Perform server-side security checks
- Verify certificate chains
- Check RP ID hashes
- Prevent replay attacks

### What the CLI Does

- Parses attestation and assertion structures
- Extracts fields and displays them
- Provides debugging and inspection tools

### What the CLI Does NOT Do

- Verify cryptographic signatures
- Validate certificate chains
- Check RP ID hashes
- Validate nonces/challenges
- Perform any security validation

### Your Responsibility

**For production use**, you must:

1. Implement complete server-side validation following Apple's [Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations)
2. Validate certificate chains against Apple's App Attest Root CA
3. Verify cryptographic signatures using validated certificates
4. Check RP ID hashes match your bundle identifier
5. Validate nonces/challenges to prevent replay attacks
6. Track challenge uniqueness to prevent reuse

The test app and CLI are **development and testing tools only**. They help you understand App Attest structure and test your validation logic, but they do not provide security guarantees.

---

## Additional Resources

- [Apple App Attest Documentation](https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity_with_app_attest)
- [Apple Attestation Object Validation Guide](https://developer.apple.com/documentation/devicecheck/validating_app_attest_assertions_and_attestations)
- [AppAttestDecoderCLI README](../README.md) - Decoder usage and API documentation
- [AppAttestDecoderCLI HOW_TO_USE](HOW_TO_USE.md) - Complete CLI usage guide

---

**End of Guide**

