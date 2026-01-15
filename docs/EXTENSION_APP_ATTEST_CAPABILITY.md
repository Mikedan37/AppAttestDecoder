# Fix: "App Attest not supported" in Extension

## The Problem

The extension shows "App Attest not supported on this device" even though:
- App Attest works in the main app
- The device supports App Attest

## What This Error ACTUALLY Means

**This is NOT a hardware issue.** Apple's error message is misleading.

`DCAppAttestService.shared.isSupported` returns `false` in extensions when:

1. **Extension target missing App Attest capability** (most common)
2. **Extension signed with wrong team/provisioning profile**
3. **Provisioning profile doesn't include the entitlement**
4. **Checking `isSupported` too early** (before extension fully loads)
5. **Running simulator binary instead of device**

This is **expected platform behavior** - App Attest support is evaluated per execution context, not per device. The fact that main app works but extension doesn't is the signal you're looking for - it proves contextual trust evaluation.

## The Cause

The **extension target** doesn't have the App Attest capability enabled. Extensions need their own capabilities - they don't inherit from the main app.

## The Fix

### Step 1: Enable App Attest Capability in Extension

1. Select `AppAttestActionExtension` target (NOT the main app)
2. Go to **Signing & Capabilities** tab
3. Click **"+ Capability"** button (top left)
4. Search for and add **"App Attest"**
5. Verify you see:
   - App Attest capability with green checkmark
   - No errors or warnings

### Step 2: Verify Both Targets Have App Attest

**Main App:**
1. Select `AppAttestDecoderTestApp` target
2. Go to **Signing & Capabilities** tab
3. Verify **App Attest** capaby is present

**Extension:**
1. Select `AppAttestActionExtension` target
2. Go to **Signing & Capabilities** tab
3. Verify **App Attest** capability is present

**Both must have it!**

### Step 3: Verify Code Signing

1. Select `AppAttestActionExtension` target
2. Go to **Signing & Capabilities** tab
3. Verify:
   - "Automatically manage signing" is checked
   - Team is selected (same as main app)
   - No signing errors shown

### Step 4: Clean and Rebuild

1. Product → Clean Build Folder (Cmd+Shift+K)
2. Delete app from device
3. Rebuild and reinstall

### Step 5: Test Again

1. Open extension from share sheet
2. Check console for:
   - `[ActionExtension] viewDidAppear called`
   - `[ActionExtension] DCAppAttestService.shared.isSupported = true`
   - `[ActionExtension] App Attest is supported, starting flow...`
3. Extension should now show "Initializing..." instead of error

**Important**: The code now checks `isSupported` in `viewDidAppear` (not `viewDidLoad`) to ensure the extension is fully loaded before checking.

## Why This Happens

Extensions are separate executables with their own:
- Bundle identifier
- Entitlements
- Capabilities
- Code signing

The main app's App Attest capability does NOT automatically apply to extensions. Each target must have it explicitly en## Verification Checklist

- [ ] `AppAttestActionExtension` target has App Attest capability
- [ ] `AppAttestDecoderTestApp` target has App Attest capability
- [ ] Both targets signed with same team
- [ ] No signing errors
- [ ] App deleted and reinstalled
- [ ] Console shows "App Attest is supported"

