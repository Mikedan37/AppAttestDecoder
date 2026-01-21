# iOS Inspector Setup

## Adding the Inspector to Your Test App

The `AttestationInspectorView` is ready to use, but you need to link the `AppAttestCore` framework to your test app target.

## Step 1: Link AppAttestCore Framework

1. Open `AppAttestDecoderCLI.xcodeproj` in Xcode
2. Select the `AppAttestDecoderTestApp` target
3. Go to **Build Phases** tab
4. Expand **Link Binary With Libraries**
5. Click the **+** button
6. Select `AppAttestCore.framework` from the list
7. Ensure it's set to **Required** (not Optional)

Alternatively, if using file system synchronized groups:
1. Select the `AppAttestDecoderTestApp` target
2. Go to **Build Phases** tab
3. Expand **Dependencies**
4. Click **+** and add `AppAttestCore` as a dependency

## Step 2: Verify Import

The `AttestationInspectorView.swift` file should compile with:
```swift
import AppAttestCore
```

If you see "Unable to find module dependency: 'AppAttestCore'", the framework isn't linked (see Step 1).

## Step 3: Test the Integration

1. Build and run the test app on a physical device
2. Generate a key
3. Attest the key
4. Tap "Inspect Attestation" button
5. The inspector screen should appear with decoded output

## Architecture Notes

**What the Inspector Does:**
- Accepts Base64 attestation blob
- Decodes structure (CBOR, ASN.1, X.509)
- Displays semantic / forensic / lossless views
- Provides copy/export functionality

**What the Inspector Does NOT Do:**
- Verify signatures
- Validate certificate chains
- Make trust decisions
- Perform any security validation

This is inspection-only. Verification happens on your server.

## Troubleshooting

### "Unable to find module dependency: 'AppAttestCore'"

**Solution:** The framework isn't linked. Follow Step 1 above.

### Build succeeds but runtime crash

**Solution:** Ensure `AppAttestCore.framework` is embedded:
1. Select `AppAttestDecoderTestApp` target
2. Go to **General** tab
3. Under **Frameworks, Libraries, and Embedded Content**
4. Ensure `AppAttestCore.framework` is listed
5. Set to **Embed & Sign** (not "Do Not Embed")

### Inspector shows empty output

**Check:**
- Base64 string is valid and complete
- Attestation was successfully generated
- No decoding errors in console

## Code Integration

The inspector is already integrated into `ContentView.swift`:

```swift
// Inspector Button
NavigationLink {
    AttestationInspectorView(base64Attestation: attestationBlobB64)
} label: {
    HStack {
        Image(systemName: "magnifyingglass")
        Text("Inspect Attestation")
    }
    .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
```

This appears below the attestation blob display when an attestation is generated.

## UI Design

The inspector UI is intentionally boring and utilitarian:
- No animations
- No trust indicators
- No "secure" badges
- No green checkmarks
- Just data, formatted clearly

This is a developer inspection tool, not a trust authority.
