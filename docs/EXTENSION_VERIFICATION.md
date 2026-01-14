# Extension Verification Checklist

Use this checklist to verify your extension is properly configured.

## ✅ Step 1: Target Exists

- [ ] Open Xcode
- [ ] Click project name in navigator
- [ ] See `ActionExtension` in TARGETS list
- [ ] If NO → Go back to QUICK_FIX_EXTENSION.md Step 1

## ✅ Step 2: Source File is in Target

- [ ] Select `ActionExtensionViewController.swift` in navigator
- [ ] Open File Inspector (right sidebar)
- [ ] Under "Target Membership":
  - [ ] `ActionExtension` is CHECKED
  - [ ] `AppAttestDecoderTestApp` is UNCHECKED (should NOT be in main app)

## ✅ Step 3: Extension is Embedded

- [ ] Select `AppAttestDecoderTestApp` target (main app)
- [ ] Go to "Build Phases" tab
- [ ] Expand "Embed App Extensions"
- [ ] See `ActionExtension.appex` listed
- [ ] "Code Sign On Copy" checkbox is checked
- [ ] If NOT listed → Click "+" → Add `ActionExtension`

## ✅ Step 4: Capabilities Configured

- [ ] Select `ActionExtension` target
- [ ] Go to "Signing & Capabilities" tab
- [ ] See "App Attest" capability (with green checkmark)
- [ ] See "App Groups" capability (with green checkmark)
- [ ] App Group ID matches main app's App Group ID

## ✅ Step 5: Info.plist Configuration

- [ ] Select `ActionExtension` target
- [ ] Go to "Info" tab
- [ ] Expand "NSExtension" section
- [ ] `NSExtensionPointIdentifier` = `com.apple.ui-services`
- [ ] `NSExtensionActivationRule` → `NSExtensionActivationSupportsText` = `true` (Boolean)

## ✅ Step 6: Bundle Identifier

- [ ] Select `ActionExtension` target
- [ ] Go to "General" tab
- [ ] Bundle Identifier = `DanylchukStudios.AppAttestDecoderTestApp.ActionExtension` (or your team's format)
- [ ] Must start with main app's bundle ID: `DanylchukStudios.AppAttestDecoderTestApp`

## ✅ Step 7: Code Signing

- [ ] Select `ActionExtension` target
- [ ] Go to "Signing & Capabilities" tab
- [ ] "Automatically manage signing" is checked
- [ ] Team is selected (same as main app)
- [ ] No signing errors shown

## ✅ Step 8: Build and Install

- [ ] Product → Clean Build Folder (Cmd+Shift+K)
- [ ] **Delete app from device** (long press → Delete)
- [ ] Select `AppAttestDecoderTestApp` scheme
- [ ] Connect physical iOS device
- [ ] Build and Run (Cmd+R)
- [ ] Wait for install to complete

## ✅ Step 9: Verify in Settings

- [ ] Open Settings app on device
- [ ] Scroll to find your app name
- [ ] Tap on your app
- [ ] See "Extensions" section
- [ ] See `ActionExtension` listed under Extensions
- [ ] If NOT listed → Extension isn't properly embedded

## ✅ Step 10: Test Share Sheet

- [ ] Open your app on device
- [ ] Tap "Test Action Extension" button
- [ ] Share sheet opens
- [ ] Scroll through share options
- [ ] See your app's extension (may be at the bottom, scroll right)
- [ ] Tap on it
- [ ] Extension UI appears
- [ ] Console shows: `[ActionExtension] viewDidLoad called`

## Common Issues

### Extension Not in Settings
- **Cause**: Not properly embedded
- **Fix**: Check Step 3 (Embed App Extensions)

### Extension Not in Share Sheet
- **Cause**: Info.plist not configured correctly
- **Fix**: Check Step 5 (Info.plist)

### "Failed to locate container app bundle record"
- **Cause**: Extension not embedded OR app not reinstalled after creating extension
- **Fix**: 
  1. Check Step 3 (Embed App Extensions)
  2. Delete app from device
  3. Clean build folder
  4. Rebuild and reinstall

### Extension Crashes on Launch
- **Cause**: Source file not in extension target OR in wrong target
- **Fix**: Check Step 2 (Source File Target Membership)

## Still Not Working?

1. **Check Console Logs**:
   - Look for `[ActionExtension]` messages
   - If you see `[ActionExtension] viewDidLoad called`, extension IS loading
   - If you don't see it, extension isn't loading

2. **Try Sharing from Another App**:
   - Open Notes app
   - Type some text
   - Tap Share button
   - See if your extension appears
   - This tests if extension works outside your app

3. **Verify Extension Bundle**:
   - After build, check: `Products` folder in Xcode
   - Should see `ActionExtension.appex` file
   - If missing, extension target isn't building

4. **Check Build Log**:
   - View → Navigators → Report Navigator
   - Look for `ActionExtension` in build log
   - Should see "Build Succeeded" for ActionExtension target

