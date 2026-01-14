# Extension Still Not Appearing? Follow These Steps

## Critical Steps (Do These First)

### 1. Delete App from Device
**This is REQUIRED.** iOS caches extension information.

- Long press app icon on device
- Tap "Remove App" → "Delete App"
- Confirm deletion

### 2. Clean Build Folder
- In Xcode: Product → Clean Build Folder (Cmd+Shift+K)
- Wait for it to complete

### 3. Verify Extension is Embedded

1. Select `AppAttestDecoderTestApp` target (main app)
2. Go to **Build Phases** tab
3. Scroll to **"Embed App Extensions"** section
4. **VERIFY**: `AppAttestActionExtension.appex` is listed
   - If NOT listed:
     - Click **"+"** button
     - Select `AppAttestActionExtension`
     - Click **"Add"**
   - **VERIFY**: "Code Sign On Copy" checkbox is checked

### 4. Verify Info.plist Configuration

1. Select `AppAttestActionExtension` target
2. Go to **Info** tab
3. Under **NSExtension**:
   - `tensionPointIdentifier` = `com.apple.ui-services`
   - `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ActionViewController`
   - `NSExtensionActivationRule` → `NSExtensionActivationSupportsText` = `true` (Boolean)

### 5. Rebuild and Reinstall

1. Select `AppAttestDecoderTestApp` scheme
2. Connect physical iOS device
3. Build and Run (Cmd+R)
4. Wait for install to complete

### 6. Check Settings App

1. Open **Settings** app on device
2. Scroll to find your app name
3. Tap on your app
4. Look for **"Extensions"** section
5. **VERIFY**: `AppAttestActionExtension` is listed

If extension is NOT in Settings → Extensions, go back to Step 3 (embedding).

## Still Not Working?

### Check Console Logs

1. In Xcode: View → Debug Area → Activate Console (Cmd+Shift+Y)
2. Run app on device
3. Tap "Test Action Extension" button
4. Look for:
   - `[ActionExtension] viewDidLoad called` → Extension IS loading
   - `[ActionExtension] Bundle ID: ...` → Extension context is correct
   - If you see these, eworking but not appearing in share sheet

### Try Sharing from Another App

1. Open **Notes** app
2. Type some text
3. Tap **Share** button
4. Scroll through share options
5. Look for your app's extension
   - May be at the bottom
   - May require scrolling right

### Verify Bundle Identifier

1. Select `AppAttestActionExtension` target
2. Go to **General** tab
3. **Bundle Identifier** should be:
   - `DanylchukStudios.AppAttestDecoderTestApp.AppAttestActionExtension`
   - Must start with main app's bundle ID

### Check Code Signing

1. Select `AppAttestActionExtension` target
2. Go to **Signing & Capabilities**
3. **VERIFY**:
   - "Automatically manage signing" is checked
   - Team is selected (same as main app)
   - No signing errors shown
   - **App Attest** capability is added
   - **App Groups** capability is added

## Most Common Issue

**"Failed to locate container app bundle record"** usually means:

1. Extension not embedded (Step 3 above)
2. App not deleted/reinstalled (Step 1 above)
3. Extension target not built (check build log)

## If Extension Appears in Settings But Not Share Sheet

1. Check Info.plist `NSExtensionActivationRule`
2. Try sharing different content types (text, URLs, images)
3. Restart device (sometimes iOS needs a reboot to refresh extension registry)

