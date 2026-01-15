import SwiftUI
import CryptoKit
import DeviceCheck
import UIKit

struct ContentView: View {
    private let service = DCAppAttestService.shared

    @State private var isSupported: Bool?

    @State private var keyID: String?
    @State private var keyIDError: String?

    // Keep these as base64 strings for display/copy. Avoid duplicating Data + String (memory).
    @State private var lastAttestClientDataHashB64: String?
    @State private var attestationBlobB64: String?
    @State private var attestationError: String?

    @State private var lastAssertClientDataHashB64: String?
    @State private var assertionBlobB64: String?
    @State private var assertionError: String?
    
    @State private var showShareSheet = false
    
    init() {
        print("[ContentView] Initializing...")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Debug: Always show something
                    Text("App Attest Test App")
                        .font(.title)
                        .padding(.bottom, 8)

                    Button("Is Supported?") {
                        isSupported = service.isSupported
                    }

                if let isSupported {
                    Text(isSupported ? "✅ Supported" : "❎ Not Supported")
                } else {
                    Text("Not checked")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Button("Generate Key") {
                        keyIDError = nil
                        keyID = nil

                        guard service.isSupported else {
                            keyIDError = "App Attest not supported on this device / configuration."
                            return
                        }

                        service.generateKey { keyID, error in
                            DispatchQueue.main.async {
                                if let keyID {
                                    self.keyID = keyID
                                    self.keyIDError = nil
                                    print("KeyID: \(keyID)")
                                } else {
                                    self.keyID = nil
                                    self.keyIDError = error?.localizedDescription ?? String(describing: error)
                                    print("GenerateKey error: \(self.keyIDError ?? "unknown")")
                                }
                            }
                        }
                    }

                    Button {
                        if let keyID {
                            UIPasteboard.general.string = keyID
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(keyID == nil)
                }

                if let keyIDError {
                    Text(keyIDError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if let keyID {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: .constant(keyID))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(height: 48)
                            .textSelection(.enabled)
                            .scrollDisabled(true)
                            .contextMenu {
                                Button("Copy") {
                                    UIPasteboard.general.string = keyID
                                }
                            }
                    }
                } else {
                    Text("Key not generated")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Button("Attest Key") {
                        attestationError = nil
                        attestationBlobB64 = nil
                        lastAttestClientDataHashB64 = nil

                        guard service.isSupported else {
                            attestationError = "App Attest not supported on this device / configuration."
                            return
                        }

                        guard let keyID else {
                            attestationError = "Missing keyID. Generate a key first."
                            return
                        }

                        let challenge = UUID().uuidString.data(using: .utf8)!
                        let clientDataHash = Data(SHA256.hash(data: challenge))
                        let clientDataHashB64 = clientDataHash.base64EncodedString()
                        lastAttestClientDataHashB64 = clientDataHashB64
                        print("Attest clientDataHash (b64): \(clientDataHashB64)")

                        service.attestKey(keyID, clientDataHash: clientDataHash) { attestBlob, error in
                            DispatchQueue.main.async {
                                if let error {
                                    self.attestationError = error.localizedDescription
                                    self.attestationBlobB64 = nil
                                    print("AttestKey error: \(error)")
                                } else if let attestBlob {
                                    self.attestationBlobB64 = attestBlob.base64EncodedString()
                                    self.attestationError = nil
                                    print("AttestKey success: \(attestBlob.count) bytes")
                                } else {
                                    self.attestationError = "Attestation failed with no error (unsupported or misconfigured)."
                                    self.attestationBlobB64 = nil
                                    print("AttestKey returned nil blob and nil error")
                                }
                            }
                        }
                    }

                    Button {
                        if let attestationBlobB64 {
                            UIPasteboard.general.string = attestationBlobB64
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(attestationBlobB64 == nil)
                }

                if let lastAttestClientDataHashB64 {
                    Text("Attest clientDataHash (b64): \(lastAttestClientDataHashB64)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let attestationError {
                    Text(attestationError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if let attestationBlobB64 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Attestation Blob (base64)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: .constant(attestationBlobB64))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(height: 220)
                            .textSelection(.enabled)
                            .scrollDisabled(false)
                            .contextMenu {
                                Button("Copy") {
                                    UIPasteboard.general.string = attestationBlobB64
                                }
                            }
                        
                        // Inspector Button
                        // NOTE: This opens an inspection-only view.
                        // It does NOT perform verification or make trust decisions.
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
                    }
                } else {
                    Text("Attestation not generated")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Button("Assert Key") {
                        assertionError = nil
                        assertionBlobB64 = nil
                        lastAssertClientDataHashB64 = nil

                        guard service.isSupported else {
                            assertionError = "App Attest not supported on this device / configuration."
                            return
                        }

                        guard let keyID else {
                            assertionError = "Missing keyID. Generate a key first."
                            return
                        }

                        let challenge = UUID().uuidString.data(using: .utf8)!
                        let clientDataHash = Data(SHA256.hash(data: challenge))
                        let clientDataHashB64 = clientDataHash.base64EncodedString()
                        lastAssertClientDataHashB64 = clientDataHashB64
                        print("Assert clientDataHash (b64): \(clientDataHashB64)")

                        service.generateAssertion(keyID, clientDataHash: clientDataHash) { assertionObject, error in
                            DispatchQueue.main.async {
                                if let error {
                                    self.assertionError = error.localizedDescription
                                    self.assertionBlobB64 = nil
                                    print("GenerateAssertion error: \(error)")
                                } else if let assertionObject {
                                    self.assertionBlobB64 = assertionObject.base64EncodedString()
                                    self.assertionError = nil
                                    print("GenerateAssertion success: \(assertionObject.count) bytes")
                                } else {
                                    self.assertionError = "Assertion failed with no error (unsupported or misconfigured)."
                                    self.assertionBlobB64 = nil
                                    print("GenerateAssertion returned nil blob and nil error")
                                }
                            }
                        }
                    }

                    Button {
                        if let assertionBlobB64 {
                            UIPasteboard.general.string = assertionBlobB64
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(assertionBlobB64 == nil)
                }

                if let lastAssertClientDataHashB64 {
                    Text("Assert clientDataHash (b64): \(lastAssertClientDataHashB64)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let assertionError {
                    Text(assertionError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if let assertionBlobB64 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assertion Blob (base64)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: .constant(assertionBlobB64))
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 44, maxHeight: 96)
                            .fixedSize(horizontal: false, vertical: false)
                            .textSelection(.enabled)
                            .scrollDisabled(false)
                            .contextMenu {
                                Button("Copy") {
                                    UIPasteboard.general.string = assertionBlobB64
                                }
                            }
                        
                        // Inspector Button
                        // NOTE: This opens an inspection-only view.
                        // It does NOT perform verification or make trust decisions.
                        NavigationLink {
                            AssertionInspectorView(base64Assertion: assertionBlobB64)
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Inspect Assertion")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("Assertion not generated")
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Action Extension Test Button
                HStack {
                    Button("Test Action Extension") {
                        print("[MainApp] Opening share sheet...")
                        showShareSheet = true
                    }
                    
                    Button {
                        // No copy action needed for this button
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .imageScale(.medium)
                    }
                    .disabled(true)
                    .opacity(0.3)
                }
            }
            .padding()
            .navigationTitle("App Attest Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["Test App Attest Extension"])
        }
        .onAppear {
            print("[ContentView] View appeared")
        }
    }
}

// Helper to present share sheet from SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("[ShareSheet] Creating UIActivityViewController with items: \(activityItems.count)")
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Exclude system activities we don't need (faster loading)
        controller.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo,
            .postToTwitter,
            .postToFacebook,
            .openInIBooks,
            .markupAsPDF
        ]
        
        // Configure for iPad
        if let popover = controller.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootView = windowScene.windows.first?.rootViewController?.view {
                popover.sourceView = rootView
                let screenBounds = windowScene.screen.bounds
                popover.sourceRect = CGRect(x: screenBounds.width / 2, y: screenBounds.height, width: 0, height: 0)
                popover.permittedArrowDirections = .down
            }
        }
        
        print("[ShareSheet] UIActivityViewController created, presenting...")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
