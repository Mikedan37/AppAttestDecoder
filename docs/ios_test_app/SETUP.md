# Test App Setup

**Scope:** iOS Test App (`AppAttestDecoderTestApp`)

This guide explains how to set up and run the diagnostic test app.

---

## Prerequisites

- **Physical Apple device** (iPhone or iPad running iOS 14.0 or later)
- **Apple Developer Account** (free or paid)
- **Xcode** (14.0 or later)
- **App Attest capability** enabled for your App ID

**Note:** App Attest does not work on simulators. A physical device is required.

---

## Apple Developer Setup

### Step 1: Create App ID

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Create a new App ID
3. Enable "App Attest" capability
4. Note your Bundle ID (e.g., `com.example.AppAttestDecoderTestApp`)

### Step 2: Configure Xcode Project

1. Open `AppAttestDecoderCLI.xcodeproj` in Xcode
2. Select the `AppAttestDecoderTestApp` target
3. Set Bundle Identifier to match your App ID
4. Ensure "App Attest" capability is enabled in Signing & Capabilities

---

## Local Network Configuration

The test app communicates with a backend server. Configure local network access:

### iOS Settings

1. Settings → Privacy & Security → Local Network
2. Enable access for `AppAttestDecoderTestApp`

### App Transport Security

The test app uses HTTP for local development. Configure ATS:

1. Open `AppAttestDecoderTestApp/Info.plist`
2. Ensure `NSAppTransportSecurity` allows local network access
3. Or add exception for your backend IP address

See `IOS_SANDBOX_SETUP.md` for detailed configuration.

---

## Backend Configuration

The test app requires a backend server. Configure the backend URL:

1. Launch the app
2. Enter backend URL (e.g., `http://10.0.0.108:8080`)
3. Use "Ping Backend" button to verify connectivity

---

## Running the App

1. Connect physical device to Mac
2. Select device in Xcode
3. Build and run (`Cmd+R`)
4. Follow the flow: Generate Key → Attest Key → Register → Assert Key → Send to Backend

---

## Troubleshooting

See `TROUBLESHOOTING.md` for common issues:
- Network connectivity problems
- App Attest capability errors
- Backend communication failures
- State consistency issues

---

## Related Documentation

- **`IOS_SANDBOX_SETUP.md`** - Detailed sandbox configuration
- **`DATA_FLOW.md`** - What data flows through the app
- **`TROUBLESHOOTING.md`** - Common issues and solutions
