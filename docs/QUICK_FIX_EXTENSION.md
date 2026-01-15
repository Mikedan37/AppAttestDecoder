# Quick Fix: Action Extension Not Appearing

## The Problem

You're seeing:
- "Failed to locate container app bundle record"
- Extension doesn't appear in share sheet
- Long delay when opening share sheet

## The Cause

**The extension target doesn't exist in Xcode yet.** The source code file exists, but Xcode needs the target to be created manually.

## The Fix (5 minutes)

### Step 1: Create the Extension Target

1. **Open Xcode**
2. **Click on the project name** in the navigator (left sidebar, very top - the blue icon)
   - This selects the PROJECT, not a file
   - You should see "PROJECT" and "TARGETS" sections in the middle panel
3. **Click the "+" button** at the bottom of the TARGETS list
4. **Select "iOS" tab** → **"Action Extension"**
5. **Click "Next"**
6. **Fill in the form**:
   - **Product Name**: `ActionExtension`
   - **Bundle Identifier**: `com.YOURTEAM.AppAttestDecoderTestApp.ActionExtension`
     - Replace `YOURTEAM` with your actual team/identifier (same as main app)
   - **Language**: Swift
   - **Embed in Application**: Select `AppAttestDecoderTestApp` from dropdown
7. **Click "Finish"**
8. **When prompted "Activate ActionExtension scheme?"** → Click **"Cancel"** (we'll use main app scheme)

### Step 2: Add the Source File to the Target

1. **Find the file** `AppAttestDecoderTestApp/ActionExtension/ActionExtensionViewController.swift` in the navigator
2. **Click on it** to select it
3. **Open File Inspector** (right sidebar, or View → Inspectors → File)
4. **Under "Target Membership"**, check the box for **`ActionExtension`**
5. **Uncheck** `AppAttestDecoderTestApp` (if it's checked) - this file should ONLY be in the extension target

### Step 3: Configure Capabilities

1. **Select `ActionExtension` target** in the TARGETS list
2. **Go to "Signing & Capabilities" tab**
3. **Click "+ Capability"**
4. **Add "App Attest"** capability
5. **Click "+ Capability" again**
6. **Add "App Groups"** capability
7. **In App Groups**, click the "+" and add your App Group ID
   - If you don't have one yet, create it in Apple Developer Portal first
   - Format: `group.com.yourteam.AppAttestDecoder` (replace with your actual group)

### Step 4: Configure Info.plist

1. **Still on `ActionExtension` target**
2. **Go to "Info" tab**
3. **Expand "NSExtension"** (if it doesn't exist, click "+" and add it)
4. **Set these values**:
   - `NSExtensionPointIdentifier` = `com.apple.ui-services`
   - `NSExtensionActivationRule` → Click "+" → Add `NSExtensionActivationSupportsText` = `true` (Boolean)

### Step 5: Verify Embedding

1. **Select `AppAttestDecoderTestApp` target** (main app)
2. **Go to "Build Phases" tab**
3. **Expand "Embed App Extensions"**
4. **Verify `ActionExtension.appex` is listed**
   - If not, click "+" and add it

### Step 6: Verify Embedding (CRITICAL)

1. **Select `AppAttestDecoderTestApp` target** (main app)
2. **Go to "Build Phases" tab**
3. **Look for "Embed App Extensions" section**
4. **Verify `ActionExtension.appex` is listed there**
   - If NOT listed: Click "+" button → Select `ActionExtension` → Click "Add"
5. **Verify the "Code Sign On Copy" checkbox is checked** for the extension

### Step 7: Clean and Rebuild

1. **Product → Clean Build Folder** (Cmd+Shift+K)
2. **Delete the app from your device** (long press app icon → Delete)
3. **Select the main app scheme** (`AppAttestDecoderTestApp`) in the scheme selector (top toolbar)
4. **Connect a physical iOS device** (App Attest doesn't work in simulator)
5. **Build and Run** (Cmd+R)
6. **After install, try the "Test Action Extension" button again**

**IMPORTANT**: You MUST delete the app from the device and reinstall after creating the extension target. iOS caches extension information, and a fresh install is required.

## Verification

After following these steps, you should:
- See `ActionExtension` in the TARGETS list
- See the extension in Settings → [Your App Name]
- See the extension in the share sheet when you tap "Test Action Extension"
- See `[ActionExtension] viewDidLoad called` in the console when extension loads

## Still Not Working?

1. **Clean build folder**: Product → Clean Build Folder (Cmd+Shift+K)
2. **Delete app from device**
3. **Rebuild and reinstall**
4. **Check console logs** for `[ActionExtension]` messages
5. **Try sharing from another app** (Notes, Safari) to see if extension appears there

## Common Mistakes

- Forgetting to add the source file to the extension target
- Adding the source file to BOTH main app and extension (should be extension only)
- Not setting `NSExtensionPointIdentifier` correctly
- Not embedding the extension in the main app
- Trying to run in simulator (App Attest requires physical device)

