# iOS Sandbox Setup for Local Network Access

## Problem

iOS apps require explicit permission to access local network resources. Without proper configuration, network requests to local IPs (e.g., `http://10.0.0.108:8080`) fail silently or are blocked by App Transport Security (ATS).

## Required Configuration

### 1. Local Network Permission

Add to Info.plist (or build settings):

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connects to a local App Attest verifier for testing.</string>
```

This triggers the iOS system prompt: "App would like to find and connect to devices on your local network"

### 2. App Transport Security (ATS)

iOS blocks plain HTTP by default, even for local IPs. 

**Note:** `INFOPLIST_KEY_NSAppTransportSecurity` does NOT support nested dictionaries in build settings. You must create an actual Info.plist file.

**Create `AppAttestDecoderTestApp/Info.plist`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
</dict>
</plist>
```

Then set `INFOPLIST_FILE = AppAttestDecoderTestApp/Info.plist` in Xcode build settings (or add it to the project).

**Note:** This allows HTTP for testing only. Production apps should use HTTPS or configure ATS exceptions per-domain.

## Critical: Info.plist Changes Don't Apply Retroactively

If you add or modify these keys after the app is already installed, iOS keeps the old sandbox rules. Toggling the permission in Settings is not enough.

**You must:**
1. Delete the app from the device (not just stop/rebuild)
2. Clean build folder in Xcode
3. Rebuild and reinstall fresh

This resets the sandbox and applies new Info.plist values.

## Verification Steps

### 1. Check System Prompt

When the app launches after fresh install, iOS MUST show:

"App would like to find and connect to devices on your local network"

If you don't see this prompt, the app is still misconfigured.

### 2. Test Network Access from Device

On the iPhone, open Safari and navigate to:

```
http://10.0.0.108:8080/health
```

- If this fails → network/Wi-Fi/VPN/router issue (not app configuration)
- If this works → app should work once permissions are correct

Safari is the control experiment.

### 3. Check Logs

After granting permission, network errors should stop. You should see:
- Successful HTTP requests
- No "Local network prohibited" errors
- Backend receives requests

## Common Failure Modes

### "Local network prohibited" persists

**Cause:** App installed before Info.plist was correct, or permission not granted.

**Fix:** Delete app, verify Info.plist, reinstall.

### Network works in Safari but not app

**Cause:** ATS blocking HTTP, or permission not granted to app.

**Fix:** Add `NSAppTransportSecurity` with `NSAllowsArbitraryLoads`, delete app, reinstall.

### Permission prompt never appears

**Cause:** Info.plist key missing or incorrect, or app was installed before key was added.

**Fix:** Verify key exists, delete app, clean build, reinstall.

## Detection in Code

The app should check for network errors and stop the flow:

```swift
if let error {
    // Network error - registration cannot proceed
    self.backendError = "Network error: \(error.localizedDescription)"
    self.registrationSucceeded = false // Disable assertion button
    return
}
```

If `/register` fails, do not allow `/verify` to proceed. The key was never registered.

## Why This Matters

Without local network access:
- Registration fails silently
- Assertion verification appears to fail cryptographically
- Error messages are misleading ("signature invalid" when it's actually "network blocked")

Fix sandbox configuration first, then debug crypto.
