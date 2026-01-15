//
//  InspectorIntegration.swift
//  Example: On-device attestation inspection for debugging only
//
//  WARNING: This is inspection only, not verification.
//  Do not use this to make trust decisions or gate network requests.
//

import SwiftUI
import AppAttestCore

/// SwiftUI view for inspecting attestations on-device
/// This is for debugging and development only, not production validation
struct AttestationInspectorView: View {
    @State private var attestationBase64: String = ""
    @State private var decodedOutput: String = ""
    @State private var isDecoding: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attestation Inspector")
                .font(.headline)
            
            Text("This view is for inspection only, not verification.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("WARNING: Do not use this to make trust decisions or gate network requests.")
                .font(.caption)
                .foregroundColor(.red)
            
            TextEditor(text: $attestationBase64)
                .frame(height: 100)
                .border(Color.gray)
                .placeholder(when: attestationBase64.isEmpty) {
                    Text("Paste base64 attestation here")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            
            Button("Inspect") {
                inspectAttestation()
            }
            .disabled(attestationBase64.isEmpty || isDecoding)
            
            if isDecoding {
                ProgressView()
                    .padding()
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            ScrollView {
                Text(decodedOutput)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)
        }
        .padding()
    }
    
    private func inspectAttestation() {
        isDecoding = true
        errorMessage = nil
        decodedOutput = ""
        
        // Decode on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Parse base64
                guard let data = Data(base64Encoded: attestationBase64.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw InspectionError.invalidBase64
                }
                
                // Decode attestation (inspection only, no verification)
                let decoder = AppAttestDecoder(teamID: nil)
                let attestation = try decoder.decodeAttestationObject(data)
                
                // Build semantic model for display
                let model = try attestation.buildSemanticModel()
                
                // Generate output (inspection only)
                let printer = SemanticPrinter(colorized: false)
                let output = printer.print(model)
                
                // Update UI on main queue
                DispatchQueue.main.async {
                    self.decodedOutput = output
                    self.isDecoding = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isDecoding = false
                }
            }
        }
    }
}

enum InspectionError: LocalizedError {
    case invalidBase64
    
    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Invalid base64 encoding"
        }
    }
}

// MARK: - View Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Usage Notes

/*
 INTEGRATION NOTES:
 
 1. This view is INSPECTION ONLY, not verification.
    - It parses structure, nothing more
    - No cryptographic verification is performed
    - No trust decisions are made
 
 2. Do not gate network requests on this.
    - Inspection results must not be used to accept/reject API calls
    - All verification must happen server-side
    - This is for debugging and development only
 
 3. This is for test apps, not production.
    - Use in development and test environments
    - Do not use in production to make trust decisions
    - Do not expose inspection results to end users
 
 4. Verification must happen separately.
    - Server-side validation is required
    - Use raw materials from decoder for verification
    - See docs/VERIFICATION_GUIDE.md for details
 */
