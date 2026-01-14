# Fix: Extension Embedding Location

## The Problem

You're seeing the extension in "Frameworks, Libraries, and Embedded Content" but it needs to be in a **separate** "Embed App Extensions" build phase.

## The Solution

### Step 1: Find the Correct Section

1. Select `AppAttestDecoderTestApp` target (main app)
2. Go to **Build Phases** tab
3. Scroll down and look for **"Embed App Extensions"** section
   - This is DIFFERENT from "Frameworks, Libraries, and Embedded Content"
   - It should be near the bottom of the Build Phases list

### Step 2: Add Extension to Embed App Extensions

If "Embed App Extensions" section doesn't exist:
1. Click the **"+"** button at the top of Build Phases
2. Select **"New Copy Files Phase"**
3. In the new phase:
   - Set **Destination**: "Products Directory"
   - Set **Subpath**: (leave empty)
   - Set **Code Sign On Copy**: ✅ (checked)
4. Rename the phase to "Embed App Eensions" (optional, for clarity)

If "Embed App Extensions" section exists:
1. Click **"+"** button in that section
2. Select `AppAttestActionExtension.appex`
3. Click **"Add"**
4. Verify **"Code Sign On Copy"** is checked

### Step 3: Remove from Wrong Location (if needed)

If `AppAttestActionExtension.appex` appears in "Frameworks, Libraries, and Embedded Content":
1. Select it
2. Click **"-"** (minus) button to remove it
3. This section is for frameworks, not app extensions

### Step 4: Verify

After adding to "Embed App Extensions":
- ✅ Extension appears in "Embed App Extensions" section
- ✅ "Code Sign On Copy" is checked
- ✅ Extension does NOT appear in "Frameworks, Libraries, and Embedded Content"

### Step 5: Clean and Rebuild

1. Product → Clean Build Folder (Cmd+Shift+K)
2. Delete app from device
3. Build and Run

## Why This Matters

- **"Frameworks, Libraries, and Embedded Content"**: For frameworks and libraries
- **"Embed App Extensions"**: For app extensions (Action Extensions, Share Es, etc.)

Extensions must be in the correct build phase or iOS won't recognize them.

