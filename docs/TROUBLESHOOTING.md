# Troubleshooting Action Extension

## Critical: Extension Target Must Be Created in Xcode

**IMPORTANT**: The extension source code exists, but you MUST create the extension target in Xcode for it to work. The source file alone is not enough.

### Quick Check: Does Extension Target Exist?

1. Open Xcode
2. Look at the project navigator (left sidebar)
3. Check if you see an `ActionExtension` target in the target list
4. If you DON'T see it, the extension target hasn't been created yet

**If the target doesn't exist**: Follow `EXTENSION_SETUP.md` Step 2 to create it.

## Issue: Extension doesn't appear in Share Sheet

### Check 1: Extension Target is Added (CRITICAL)

**This is the most common issue**: The extension target doesn't exist in Xcode.

1. Open Xcode project
2. Click on the project name in the navigator (top of left sidebar)
3. Look at the TARGETS list (middle panel)
4. **Do you see `ActionExtension` listed?**
   - **NO**: The target hasn't been created. Go to `EXTENSION_SETUP.md` Step 2.1 and create it.
   - **YES**: Continue to next check

5. Verify it's listed under "Embedded Extensions" in the main app target's build phases:
   - Select main app target (`AppAttestDecoderTestApp`)
   - Go to **Build Phases** tab
   - Expand **Embed App Extensions**
   - Verify `ActionExtension.appex` is listed

### Check 2: Extension is Embedded
1. Select main app target (`AppAttestDecoderTestApp`)
2. Go to **General** tab
3. Scroll to **Frameworks, Libraries, and Embedded Content**
4. Verify `ActionExtension.appex` is listed (or will be after first build)

### Check 3: Info.plist Configuration
The extension's Info.plist must have:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.ui-services</string>
    <key>NSExtensionActivationRule</key>
    <dict>
        <key>NSExtensionActivationSupportsText</key>
        <true/>
    </dict>
</dict>
```

**To check/update:**
1. Select `ActionExtension` target
2. Go to **Info** tab
3. Under **NSExtension**, verify:
   - `NSExtensionPointIdentifier` = `com.apple.ui-services`
   - `NSExtensionActivationRule` → `NSExtensionActivationSupportsText` = `true`

### Check 4: Bundle Identifier
Extension bundle ID must be:
- `com.yourteam.AppAttestDecoderTestApp.ActionExtension` (or similar)
- Must start with the main app's bundle ID prefix

### Check 5: Code Signing
1. Both targets must be signed with the same team
2. Both must have App Attest capability enabled
3. Both must have the same App Group configured

### Check 6: Build and Install
1. Clean build folder (Cmd+Shift+K)
2. Build main app target
3. Build extension target
4. Run on physical device (not simulator)
5. After first install, the extension should appear in Share Sheet

### Check 7: Extension Appears in Settings
1. Go to Settings → [Your App Name]
2. Check if extension is listed
3. If not, the extension isn't properly embedded

## Issue: Long Delay Opening Share Sheet

### Cause 1: Too Many Activities
The share sheet loads all available extensions. Excluding unnecessary system activities helps.

**Solution**: Already implemented in `ShareSheet` - excludes many system activities.

### Cause 2: Extension Not Built
If extension target isn't built, iOS may be searching for it.

**Solution**: 
1. Build the extension target explicitly
2. Ensure it's included in the scheme

### Cause 3: First Launch
First time opening share sheet can be slow as iOS indexes extensions.

**Solution**: Wait for first launch to complete, subsequent opens should be faster.

## Issue: Extension Crashes on Launch

### Check: App Attest Capability
1. Extension target → **Signing & Capabilities**
2. Verify **App Attest** capability is added
3. Verify **App Groups** capability is added with correct group ID

### Check: Source File Membership
1. Select `ActionExtensionViewController.swift`
2. In File Inspector, verify **ActionExtension** target is checked
3. Main app target should NOT be checked for this file

## Debugging Steps

1. **Check Console Logs**:
   - Look for `[ActionExtension]` prefixed messages
   - Look for `[MainApp]` prefixed messages
   - Look for `[ShareSheet]` prefixed messages

2. **Verify Extension Loads**:
   - Add `print("[ActionExtension] viewDidLoad called")` at start of `viewDidLoad`
   - If you don't see this, extension isn't loading

3. **Check App Group Access**:
   - Extension should print: `[ActionExtension] Saved sample to: ...`
   - If you see "Failed to get App Group container", App Group isn't configured correctly

4. **Test Extension Directly**:
   - Try sharing from another app (Notes, Safari)
   - See if extension appears there
   - If it appears elsewhere but not from test app, it's a presentation issue

## Quick Verification Checklist

- [ ] Extension target exists in Xcode
- [ ] Extension is in "Embedded Extensions" build phase
- [ ] Info.plist has `NSExtensionPointIdentifier` = `com.apple.ui-services`
- [ ] Info.plist has `NSExtensionActivationSupportsText` = `true`
- [ ] Bundle ID follows pattern: `mainAppBundleID.ActionExtension`
- [ ] Both targets signed with same team
- [ ] Both targets have App Attest capability
- [ ] Both targets have same App Group ID
- [ ] Extension source file is member of ActionExtension target only
- [ ] Built and run on physical device (not simulator)
- [ ] Extension appears in Settings → [Your App]

## Still Not Working?

1. Delete app from device
2. Clean build folder (Cmd+Shift+K)
3. Delete DerivedData
4. Rebuild both targets
5. Install on device
6. Check Settings → [Your App] for extension
7. Try sharing from Notes app to see if extension appears

