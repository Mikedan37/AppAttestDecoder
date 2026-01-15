# On-Device Inspection in iOS Test App

## Overview

Your iOS test app can generate an App Attest attestation and immediately inspect it using the decoder. This is safe, correct, and does not weaken Apple's security model.

**See also:** `docs/INSPECTOR_PROMPT.md` for a copy-pasteable prompt to implement this in other projects.

## Architecture: What Runs Where

### On-Device (iOS App)

**App Attest Operations:**
- `DCAppAttestService.generateKey()` - Creates new App Attest key
- `DCAppAttestService.attestKey(_:clientDataHash:)` - Generates attestation object
- Collect: `attestationObject` (base64), `keyId`, `clientDataHash`

**Decoder Operations (Inspection Only):**
- Decode CBOR structure
- Decode ASN.1/DER certificates
- Decode X.509 extensions
- Print semantic / forensic / lossless views
- **NO verification**
- **NO trust decisions**
- **NO "this is valid" claims**

### Server (Later / Optional)

**Actual Security Operations:**
- Cryptographic signature verification
- Certificate chain validation
- Receipt submission to Apple
- Risk metrics and policy enforcement
- RP ID hash validation
- Replay protection

## Why This Works

### You Are Not:
- Faking verification
- Replacing server validation
- Making trust decisions on-device
- Bypassing Apple's trust boundaries

### You Are:
- Inspecting data your app already possesses
- Treating it as a debugging / developer tool
- Preserving Apple's trust boundaries
- Making systems observable

**This is no different than:**
- Dumping a certificate chain in Settings
- Printing a receipt locally
- Viewing X.509 certificate details

Apple does not forbid looking. They forbid lying about trust. You aren't doing that.

## Constraints: iOS Compatibility

The decoder must not require macOS-only APIs.

**Already Compliant:**
- Pure Swift implementation
- No Security.framework verification helpers
- No Keychain assumptions
- No file system expectations
- Pure decoding, pure formatting

The decoder is already iOS-compatible.

## UI Design Principles

**One extra screen. That's it.**

### Attestation Inspector Screen

**Components:**
- Paste / auto-fill Base64 attestation input
- Mode selector:
  - Semantic (default, human-readable)
  - Forensic (raw bytes + decoded)
  - Lossless Tree (complete dump)
- Render output (scrollable text view)
- Copy / export buttons

**Design Rules:**
- No animations
- No "score" or trust indicators
- No green checkmarks
- No cute UI elements
- This is a microscope, not a game

**Example Layout:**
```
┌─────────────────────────────────┐
│ Attestation Inspector           │
├─────────────────────────────────┤
│ [Paste Base64]                  │
│                                 │
│ Mode: [Semantic ▼]              │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ Output (scrollable)         │ │
│ │                             │ │
│ │ ATTESTATION OBJECT          │ │
│ │ Format: apple-appattest     │ │
│ │ ...                         │ │
│ └─────────────────────────────┘ │
│                                 │
│ [Copy] [Export]                 │
└─────────────────────────────────┘
```

## Implementation Example

### Step 1: Add Decoder to iOS Target

Ensure `AppAttestCore` framework is linked to your iOS app target:

1. Select your iOS app target in Xcode
2. Go to **Build Phases** → **Link Binary With Libraries**
3. Add `AppAttestCore.framework` (if not already present)

### Step 2: Create Inspector View

```swift
import SwiftUI
import AppAttestCore

struct AttestationInspectorView: View {
    @State private var base64Input: String = ""
    @State private var selectedMode: InspectionMode = .semantic
    @State private var output: String = ""
    @State private var error: String?
    
    enum InspectionMode: String, CaseIterable {
        case semantic = "Semantic"
        case forensic = "Forensic"
        case losslessTree = "Lossless Tree"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Input
                VStack(alignment: .leading) {
                    Text("Base64 Attestation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $base64Input)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(height: 120)
                        .border(Color.gray.opacity(0.3))
                }
                
                // Mode selector
                Picker("Mode", selection: $selectedMode) {
                    ForEach(InspectionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                
                // Decode button
                Button("Inspect") {
                    inspectAttestation()
                }
                .buttonStyle(.borderedProminent)
                .disabled(base64Input.isEmpty)
                
                // Error
                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                // Output
                if !output.isEmpty {
                    ScrollView {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .border(Color.gray.opacity(0.3))
                    
                    HStack {
                        Button("Copy") {
                            UIPasteboard.general.string = output
                        }
                        Button("Export") {
                            // Export logic
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Attestation Inspector")
        }
    }
    
    private func inspectAttestation() {
        error = nil
        output = ""
        
        guard let data = Data(base64Encoded: base64Input.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            error = "Invalid base64"
            return
        }
        
        do {
            let decoder = AppAttestDecoder(teamID: nil)
            let attestation = try decoder.decodeAttestationObject(data)
            
            switch selectedMode {
            case .semantic:
                let model = try attestation.buildSemanticModel()
                let printer = SemanticPrinter(colorized: false)
                output = printer.print(model)
                
            case .forensic:
                let printer = ForensicPrinter(colorized: false)
                output = printer.print(attestation)
                
            case .losslessTree:
                let dumper = LosslessTreeDumper(colorized: false)
                output = dumper.dump(attestation)
            }
        } catch {
            error = "Decode error: \(error.localizedDescription)"
        }
    }
}
```

### Step 3: Integrate with Test App

In your main test app view, add a button to open the inspector:

```swift
// In ContentView.swift, after attestation generation:

if let attestationBlobB64 {
    // ... existing attestation display ...
    
    Button("Inspect Attestation") {
        // Pass attestation to inspector
        // You can use NavigationLink or sheet presentation
    }
}
```

## The Subtle Win

This lets you:
- **Validate your mental model** - See what Apple actually generates
- **Compare dev vs prod** - Spot differences early
- **See Apple drift** - Detect schema changes across OS versions
- **Build server logic with confidence** - Instead of guesswork

This tool provides structured inspection instead of manual Base64 analysis.

## Security Boundaries

### What the Decoder Does (Safe)
- Parses structure (CBOR, ASN.1, X.509)
- Extracts fields and displays them
- Provides debugging and inspection tools
- Preserves all raw data

### What the Decoder Does NOT Do (By Design)
- Verify cryptographic signatures
- Validate certificate chains
- Check RP ID hashes
- Validate nonces/challenges
- Perform any security validation
- Make trust decisions

### Your Responsibility

**For production use**, you must:
1. Implement complete server-side validation
2. Validate certificate chains against Apple's Root CA
3. Verify cryptographic signatures
4. Check RP ID hashes match bundle identifier
5. Validate nonces/challenges
6. Track challenge uniqueness
7. Implement replay protection

The on-device decoder is **inspection only**. It helps you understand structure and test your validation logic, but it does not provide security guarantees.

## Final Answer

**Yes, your iOS test app can generate the attestation and immediately inspect it using this decoder.**

**And doing that does not make it less secure.**

**It makes you harder to fool.**

---

## See Also

- `docs/WHAT_THIS_TOOL_IS.md` - What the decoder is and isn't
- `docs/VERIFICATION_GUIDE.md` - What to verify on the server
- `docs/TEST_APP_GUIDE.md` - Generating attestations in test app
