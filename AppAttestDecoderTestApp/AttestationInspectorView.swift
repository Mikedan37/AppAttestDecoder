//
//  AttestationInspectorView.swift
//  AppAttestDecoderTestApp
//
//  On-device inspection UI for App Attest attestation objects.
//
//  SECURITY BOUNDARIES (NON-NEGOTIABLE):
//  - This view is INSPECTION ONLY, not verification
//  - Verification MUST occur on the server
//  - Output may include Apple-private or undocumented fields
//  - Decoded does NOT mean stable or safe to rely on
//  - This view makes NO trust decisions
//  - This view makes NO security claims
//
//  If this UI were accidentally shipped, it should:
//  - Reveal no secrets beyond what the app already has
//  - Make no trust claims
//  - Cause no security regression
//

import SwiftUI
import AppAttestCore

struct AttestationInspectorView: View {
    let base64Attestation: String
    
    @State private var selectedMode: InspectionMode = .semantic
    @State private var output: String = ""
    @State private var error: String?
    @State private var isDecoding: Bool = false
    
    enum InspectionMode: String, CaseIterable {
        case semantic = "Semantic"
        case forensic = "Forensic"
        case losslessTree = "Lossless Tree"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Base64 Input (read-only)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Attestation Object (Base64)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(base64Attestation)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Mode Selector
                VStack(alignment: .leading, spacing: 6) {
                    Text("Inspection Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(InspectionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedMode) { _ in
                        decodeAttestation()
                    }
                }
                
                // Decode Button
                Button(action: decodeAttestation) {
                    HStack {
                        if isDecoding {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isDecoding ? "Decoding..." : "Inspect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDecoding || base64Attestation.isEmpty)
                
                // Error Display
                if let error {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Output Display
                if !output.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Decoded Output")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: copyOutput) {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                        }
                        
                        ScrollView {
                            Text(output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                } else if error == nil && !isDecoding {
                    Spacer()
                    Text("Tap 'Inspect' to decode the attestation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Attestation Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: copyBase64) {
                        Label("Copy Base64", systemImage: "doc.on.doc")
                    }
                }
            }
            .onAppear {
                // Auto-decode on appear
                decodeAttestation()
            }
        }
    }
    
    // MARK: - Decoding
    
    /// Decodes the attestation object for inspection only.
    /// 
    /// SECURITY NOTE: This performs structural decoding only.
    /// - Does NOT verify signatures
    /// - Does NOT validate certificate chains
    /// - Does NOT check RP ID hashes
    /// - Does NOT make trust decisions
    /// 
    /// All verification must occur on the server.
    private func decodeAttestation() {
        error = nil
        output = ""
        isDecoding = true
        
        // Validate Base64 (graceful error handling, no force unwraps)
        guard let data = Data(base64Encoded: base64Attestation.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            error = "Invalid Base64 encoding"
            isDecoding = false
            return
        }
        
        // Decode on background queue to avoid blocking UI
        // This is inspection work, not verification, so it's safe to do off-main-thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Structural decoding only - no verification
                let decoder = AppAttestDecoder(teamID: nil)
                let attestation = try decoder.decodeAttestationObject(data)
                
                let decodedOutput: String
                
                // Select output mode (all are inspection-only views)
                switch selectedMode {
                case .semantic:
                    // Human-readable semantic view
                    let model = try attestation.buildSemanticModel()
                    let printer = SemanticPrinter(colorized: false)
                    decodedOutput = printer.print(model)
                    
                case .forensic:
                    // Semantic + raw evidence view
                    let mode = ForensicMode(colorized: false)
                    decodedOutput = attestation.forensicPrint(mode: mode)
                    
                case .losslessTree:
                    // Complete CBOR/ASN.1 tree dump
                    let dumper = LosslessTreeDumper(colorized: false)
                    decodedOutput = dumper.dump(attestation)
                }
                
                DispatchQueue.main.async {
                    self.output = decodedOutput
                    self.error = nil
                    self.isDecoding = false
                }
            } catch {
                // Graceful error handling - show error as diagnostic text
                // Do NOT crash, do NOT hide errors
                let errorMessage = "Decode error: \(error.localizedDescription)\n\n\(error)"
                
                DispatchQueue.main.async {
                    self.error = errorMessage
                    self.isDecoding = false
                    // Preserve partial output if available (best-effort)
                    if self.output.isEmpty {
                        self.output = ""
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func copyOutput() {
        UIPasteboard.general.string = output
    }
    
    private func copyBase64() {
        UIPasteboard.general.string = base64Attestation
    }
}
