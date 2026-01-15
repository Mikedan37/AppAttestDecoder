# Fix: "Failed to locate container app bundle record"

## The Error

```
Failed to locate container app bundle record.
The process may not be entitled to access the LaunchServices database or the app may have moved.
```

## What This Means

iOS cannot find the container app (main app) that should contain the extension. This is a **deployment/installation issue**, not a code issue.

## The Fix (In Order)

### Step 1: Verify Extension is Embedded (Again)

Even though it looks correct, double-check:

1. Select `AppAttestDecoderTestApp` target (main app)
2. Go to **Build Phases** tab
3. Find **"Embed Foundation Extensions"** section
4. Verify `AppAttestActionExtension.appex` is listed
5. Verify **"Code Sign On Copy"** is checked

### Step 2: Verify Bundle IDs Match Pattern

The extension's bundle ID must start with the main app's bundle ID:

**Main App:**
- Bundle ID: `DanylchukStudios.AppAttestDecoderTestApp`

**Extension:**
- Bundle ID: `DanylchukStudios.AppAttestDecoderTestApp.AppAttestActionExtension`
- Must start with main app's bundle ID
- Must have `.AppAttestActionExtension` suffix

To check:
1. Select `AppAttestActionExtension` target
2. Go to **General** tab
3. Verify Bundle Identifier matches pattern above

### Step 3: NUCLEAR OPTION - Complete Clean

This error often persists due to cached state. Do this complete clean:

1. **Delete app from device** (long press → Remove App → Delete App)
2. **In Xcode**: Product → Clean Build Folder (Cmd+Shift+K)
3. **Delete DerivedData**:
   - Xcode → Settings → Locations
   - Click arrow next to DerivedData path
   - Delete `AppAttestDecoderCLI-*` folder
4. **Close Xcode completely**
5. **Reopen Xcode**
6. **Rebuild and Run** on device

### Step 4: Verify Code Signing (Both Targets)

**Main App:**
1. Select `AppAttestDecoderTestApp` target
2. Go to **Signing & Capabilities**
3. Verify:
   - Team: "Michael Danylchuk" (or your team)
   - "Automatically manage signing" is checked
   - No signing errors

**Extension:**
1. Select `AppAttestActionExtension` target
2. Go to **Signing & Capabilities**
3. Verify:
   - Team: **SAME** as main app
   - "Automatically manage signing" is checked
   - No signing errors
   - Bundle Identifier matches pattern (see Step 2)

### Step 5: Check Info.plist Principal Class

1. Select `AppAttestActionExtension` target
2. Go to **Info** tab
3. Under **NSExtension**:
   - `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ActionViewController`
   - `NSExtensionPointIdentifier` = `com.apple.ui-services`

### Step 6: Build Extension Target Separately

Sometimes the extension target doesn't build correctly:

1. In Xcode scheme selector, select `AppAttestActionExtension` scheme
2. Build (Cmd+B)
3. **VERIFY**: Build succeeds without errors
4. Switch back to `AppAttestDecoderTestApp` scheme
5. Build and Run

### Step 7: Check Console for Extension Logs

After reinstalling, check console:

1. View → Debug AreaConsole (Cmd+Shift+Y)
2. Run app and try to open extension
3. Look for: `[ActionExtension] viewDidLoad called`
   - If you see this: Extension IS loading (check for App Attest errors)
   - If you DON'T see this: Extension isn't loading (go back to Step 1)

## Why This Happens

iOS maintains a database of installed apps and their extensions. When you:
- Add an extension to an existing app
- Change extension configuration
- Update code signing

iOS needs to rebuild this database. Sometimes it doesn't, especially if:
- The app wasn't completely deleted
- DerivedData is stale
- Code signing changed but profiles weren't regenerated

## Verification Checklist

After all steps:
- [ ] Extension embedded in "Embed Foundation Extensions"
- [ ] Bundle IDs match pattern (extension starts with main app)
- [ ] Both targets signed with same team
- [ ] App completely deleted from device
- [ ] DerivedData deleted
- [ ] Xcode closed and reopened
- [ ] Extension target builds successfully
- [ ] Console shows `[ActionExtension] viewDidLoad called`

If you've done all of this and still see the error, the extension is likely loading but crashing immediately. Check the console for crash logs.

