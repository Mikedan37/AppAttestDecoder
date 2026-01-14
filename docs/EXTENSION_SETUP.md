# Extension Target Setup Guide

This guide explains how to add Action Extension and App SSO Extension targets to the test app for research purposes.

## Prerequisites

- Xcode 14.0 or later
- Apple Developer account with App Attest capability enabled
- Physical iOS device (App Attest does not work in simulator)
- App Group configured in Apple Developer portal

## Step 1: Configure App Group

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Under **Identifiers**, select **App Groups**
4. Create a new App Group (e.g., `group.com.example.AppAttestDecoder`)
5. Note the App Group identifier for use in Xcode

## Step 2: Add Action Extension Target

### 2.1 Create Target

1. Open `AppAttestDecoderCLI.xcodeproj` in Xcode
2. Select the project in the navigator
3. Click **+** button at the bottom of the target list
4. Select **iOS** → **Action Extension**
5. Configure:
   - **Product Name**: `ActionExtension`
   - **Bundle Identifier**: `com.example.AppAttestDecoder.ActionExtension` (adjust to match your app)
   - **Language**: Swift
   - **Embed in Application**: `AppAttestDecoderTestApp`

### 2.2 Configure Capabilities

1. Select the `ActionExtension` target
2. Go to **Signing & Capabilities**
3. Add **App Attest** capability
4. Add **App Groups** capability
   - Enable the App Group created in Step 1
5. Configure **Code Signing** with your development team

### 2.3 Add Source Files

1. The extension source file is already created at:
   - `AppAttestDecoderTestApp/ActionExtension/ActionExtensionViewController.swift`
2. Add this file to the `ActionExtension` target:
   - Select the file in Xcode
   - In File Inspector, check **ActionExtension** under **Target Membership**

### 2.4 Update Info.plist

1. Select `ActionExtension` target
2. Go to **Info** tab
3. Under **NSExtension**, configure:
   - **NSExtensionPointIdentifier**: `com.apple.ui-services` (Share Extension)
   - **NSExtensionActivationRule**: `NSExtensionActivationSupportsText` = `true`

### 2.5 Update App Group Identifier

1. Open `ActionExtensionViewController.swift`
2. Find the line:
   ```swift
   guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.AppAttestDecoder") else {
   ```
3. Replace `"group.com.example.AppAttestDecoder"` with your actual App Group identifier

## Step 3: Add App SSO Extension Target

### 3.1 Create Target

1. In Xcode, select the project
2. Click **+** button to add a new target
3. Select **iOS** → **App Extension** → **Credential Provider Extension**
4. Configure:
   - **Product Name**: `AppSSOExtension`
   - **Bundle Identifier**: `com.example.AppAttestDecoder.AppSSOExtension` (adjust to match your app)
   - **Language**: Swift
   - **Embed in Application**: `AppAttestDecoderTestApp`

### 3.2 Configure Capabilities

1. Select the `AppSSOExtension` target
2. Go to **Signing & Capabilities**
3. Add **App Attest** capability
4. Add **App Groups** capability
   - Enable the same App Group as Action Extension
5. Configure **Code Signing** with your development team

### 3.3 Add Source Files

1. The extension source file is already created at:
   - `AppAttestDecoderTestApp/AppSSOExtension/AppSSOExtensionViewController.swift`
2. Add this file to the `AppSSOExtension` target:
   - Select the file in Xcode
   - In File Inspector, check **AppSSOExtension** under **Target Membership**

### 3.4 Update App Group Identifier

1. Open `AppSSOExtensionViewController.swift`
2. Find the line:
   ```swift
   guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.AppAttestDecoder") else {
   ```
3. Replace `"group.com.example.AppAttestDecoder"` with your actual App Group identifier

## Step 4: Configure Main App

### 4.1 Add App Group to Main App

1. Select `AppAttestDecoderTestApp` target
2. Go to **Signing & Capabilities**
3. Add **App Groups** capability
4. Enable the same App Group identifier

### 4.2 Update Team ID

1. Open both extension source files
2. Find the line:
   ```swift
   "teamID": "YOUR_TEAM_ID", // Replace with actual Team ID
   ```
3. Replace `"YOUR_TEAM_ID"` with your actual Apple Team ID (found in Apple Developer Portal)

## Step 5: Build and Run

1. Connect a physical iOS device
2. Select the device as the run destination
3. Build and run `AppAttestDecoderTestApp`
4. The app should install with both extensions

## Step 6: Generate Artifacts

### Action Extension

1. Open any app that supports Share Sheet
2. Tap **Share** button
3. Scroll to find your app's Action Extension
4. Tap it to activate
5. The extension will generate an attestation and save it to the App Group container

### App SSO Extension

1. The App SSO Extension requires a key ID from the main app
2. First, generate a key in the main app
3. The main app should save the key ID to the App Group container
4. Then trigger the SSO extension (typically via Settings → Passwords → App Passwords)
5. The extension will generate an assertion and save it to the App Group container

## Step 7: Retrieve Artifacts

Artifacts are saved to the App Group container at:

- Attestations: `AttestationSamples/action-extension-*.json`
- Assertions: `AssertionSamples/app-sso-extension-*.json`

To retrieve:

1. Use Xcode's **Devices and Simulators** window
2. Select your device
3. Select `AppAttestDecoderTestApp`
4. Click **Download Container**
5. Navigate to the App Group container folder
6. Extract the JSON files

## Step 8: Analyze with CLI

Once you have artifact files:

```bash
# Annotate a single attestation
./AppAttestDecoderCLI annotate \
  --context action \
  --bundle-id com.example.AppAttestDecoder.ActionExtension \
  --team-id YOUR_TEAM_ID \
  --key-id "base64-key-id" \
  --file action-extension-2026-01-13.json

# Combine multiple samples into a JSON array
# Then analyze
./AppAttestDecoderCLI analyze --file samples.json
```

## Troubleshooting

### Extension Not Appearing

- Ensure the extension target is included in the app's **Embedded Extensions** build phase
- Check that the extension's bundle identifier matches the app's prefix
- Verify code signing is configured correctly

### App Attest Not Supported

- App Attest only works on physical devices
- Ensure the device is running iOS 14.0 or later
- Verify App Attest capability is enabled in Apple Developer Portal

### App Group Access Fails

- Verify the App Group identifier matches exactly in all targets
- Ensure the App Group is enabled in Apple Developer Portal
- Check that all targets have the App Groups capability enabled

### Key Generation Fails

- Ensure the device has a secure enclave (iPhone 5s or later, iPad with Touch ID/Face ID)
- Check that the app is properly signed with a development or distribution certificate
- Verify App Attest capability is correctly configured

## Important Notes

- **No Key Sharing**: Each extension generates its own App Attest keys. No keys are shared between targets.
- **Standard APIs Only**: All implementations use standard Apple DeviceCheck APIs. No private APIs or workarounds.
- **Research Purpose**: These extensions are for research only. They do not perform validation or make security claims.
- **Physical Device Required**: App Attest does not work in the iOS Simulator. All testing must be done on physical devices.

