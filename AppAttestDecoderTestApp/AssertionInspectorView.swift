//
//  AssertionInspectorView.swift
//  AppAttestDecoderTestApp
//
//  On-device inspection UI for App Attest assertion objects.
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
import CryptoKit

struct AssertionInspectorView: View {
    let base64Assertion: String
    let keyID: String? // Optional - used to look up clientDataHash for virtual COSE reconstruction
    
    @StateObject private var contextStore = AppAttestContextStore.shared
    @State private var selectedMode: InspectionMode = .semantic
    @State private var output: String = ""
    @State private var partialDecodeInfo: String? // Informational, not an error
    @State private var fatalError: String? // Only for truly fatal errors
    @State private var isDecoding: Bool = false
    @State private var showExportSheet = false
    @State private var exportData: Data?
    
    @Environment(\.dismiss) private var dismiss
    
    enum InspectionMode: String, CaseIterable {
        case semantic = "Semantic"
        case forensic = "Forensic"
        case losslessTree = "Lossless Tree"
    }
    
    
    var body: some View {
        // No nested NavigationView - we're already in a NavigationStack from ContentView
        ScrollView {
            VStack(spacing: 12) {
                // Base64 Input (read-only) - compact layout
                VStack(alignment: .leading, spacing: 4) {
                    Text("Assertion Object (Base64)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(base64Assertion)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Mode Selector - compact spacing
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inspection Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(InspectionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedMode) {
                        decodeAssertion()
                    }
                }
                
                // Decode Button - minimal spacing from input
                Button(action: decodeAssertion) {
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
                .disabled(isDecoding || base64Assertion.isEmpty)
                
                // No verification status - this is an inspection tool only
                
                // Partial Decode Info (informational, not error)
                if let info = partialDecodeInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Partial / Context-Dependent Decode", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(info)
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Fatal Error (only for truly fatal errors)
                if let error = fatalError {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Error", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
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
                            
                            Button(action: { exportAssertionData() }) {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .font(.caption)
                            }
                        }
                        
                        ScrollView {
                            Text(output)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 200, maxHeight: 400)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                } else if fatalError == nil && partialDecodeInfo == nil && !isDecoding {
                    Text("Tap 'Inspect' to decode the assertion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            .padding()
            .navigationTitle("Assertion Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: copyBase64) {
                        Label("Copy Base64", systemImage: "doc.on.doc")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let exportData = exportData {
                    AssertionExportShareSheet(exportData: exportData)
                }
            }
            .onAppear {
                // Auto-decode on appear
                decodeAssertion()
            }
        }
    }
    
    // MARK: - Decoding
    
    /// Decodes the assertion object for inspection only.
    /// 
    /// SECURITY NOTE: This performs structural decoding only.
    /// - Does NOT verify signatures
    /// - Does NOT validate certificate chains
    /// - Does NOT check RP ID hashes
    /// - Does NOT make trust decisions
    /// 
    /// All verification must occur on the server.
    private func decodeAssertion() {
        partialDecodeInfo = nil
        fatalError = nil
        output = ""
        isDecoding = true
        
        // Validate Base64 (graceful error handling, no force unwraps)
        guard let data = Data(base64Encoded: base64Assertion.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            fatalError = "Invalid Base64 encoding"
            isDecoding = false
            return
        }
        
        // Decode on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            // Build inspection context from stored context
            var inspectionContext: InspectionContext?
            if let keyID = self.keyID,
               let storedContext = self.contextStore.getContext(keyID: keyID) {
                // Use the first stored clientDataHash (most recent)
                let clientDataHash = storedContext.assertionClientDataHashes.first
                inspectionContext = InspectionContext(
                    keyID: keyID,
                    clientDataHash: clientDataHash,
                    publicKey: storedContext.publicKey.isEmpty ? nil : storedContext.publicKey
                )
            }
            
            // Use the core inspector module
            let result: InspectionResult
            do {
                result = try AppAttestInspector.inspect(data: data, context: inspectionContext)
            } catch {
                DispatchQueue.main.async {
                    self.fatalError = "Inspection failed: \(error.localizedDescription)"
                    self.isDecoding = false
                }
                return
            }
            
            // Generate output based on selected mode
            let decodedOutput = self.generateOutput(from: result, mode: self.selectedMode)
            
            DispatchQueue.main.async {
                self.output = decodedOutput
                // Show warnings if any
                if !result.warnings.isEmpty {
                    let warningMessages = result.warnings.map { $0.message }.joined(separator: "\n")
                    self.partialDecodeInfo = warningMessages
                } else {
                    self.partialDecodeInfo = nil
                }
                self.fatalError = nil
                self.isDecoding = false
            }
        }
    }
    
    // MARK: - Verification (REMOVED - This is an inspection tool only, not a verifier)
    // All verification code has been removed. This tool only decodes and displays assertion data.
    
    // MARK: - Actions
    
    private func copyOutput() {
        UIPasteboard.general.string = output
    }
    
    private func copyBase64() {
        UIPasteboard.general.string = base64Assertion
    }
    
    private func exportAssertionData() {
        // Extract export data from current output state
        guard let data = Data(base64Encoded: base64Assertion.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        
        // Try to inspect again to get structured result for export
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try AppAttestInspector.inspect(data: data, context: nil)
                }.value
                
                await MainActor.run {
                    exportInspectionData(result)
                }
            } catch {
                // If inspection fails, create minimal export from output text
                await MainActor.run {
                    let minimalExport: [String: Any] = [
                        "timestamp": ISO8601DateFormatter().string(from: Date()),
                        "base64Input": base64Assertion,
                        "decodedOutput": output,
                        "note": "Export generated from inspection output. For structured data, ensure inspection succeeds."
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: minimalExport, options: .prettyPrinted) {
                        exportData = jsonData
                        showExportSheet = true
                    }
                }
            }
        }
    }
    
    private func exportInspectionData(_ result: InspectionResult) {
        var exportDict: [String: Any] = [:]
        
        // Basic metadata
        exportDict["artifactType"] = String(describing: result.artifactType)
        exportDict["decodeStatus"] = String(describing: result.decodeStatus)
        exportDict["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // Sig_structure CBOR and hash (if available)
        if let virtualCOSE = result.virtualCOSE {
            if let sigStructureCBOR = virtualCOSE.sigStructureCBOR {
                exportDict["sigStructureCBOR"] = sigStructureCBOR.base64EncodedString()
            }
            if let sigStructureHash = virtualCOSE.sigStructureHash {
                exportDict["sigStructureHash"] = sigStructureHash.base64EncodedString()
                exportDict["sigStructureHashHex"] = sigStructureHash.map { String(format: "%02x", $0) }.joined(separator: "")
            }
        }
        
        // Parsed summary
        var summary: [String: Any] = [:]
        if let parsed = result.parsedAuthData {
            summary["authenticatorDataLength"] = parsed.rawBytes.count
            summary["rpIdHash"] = parsed.authenticatorData.rpIdHash.base64EncodedString()
            summary["flags"] = String(format: "0x%02x", parsed.authenticatorData.flags.rawValue)
            summary["signCount"] = parsed.authenticatorData.signCount
            summary["attestedCredentialDataPresent"] = parsed.attestedCredentialDataPresent
            summary["extensionsPresent"] = parsed.extensionsPresent
        }
        if let sig = result.signatureBytes {
            summary["signatureLength"] = sig.count
            summary["signatureBase64"] = sig.base64EncodedString()
        }
        exportDict["parsedSummary"] = summary
        
        // Warnings
        if !result.warnings.isEmpty {
            exportDict["warnings"] = result.warnings.map { $0.message }
        }
        
        // Missing context
        if !result.missingContext.isEmpty {
            exportDict["missingContext"] = result.missingContext
        }
        
        // Convert to JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted) {
            exportData = jsonData
            showExportSheet = true
        }
    }
    
    // MARK: - Output Generation
    
    /// Generate formatted output from inspection result
    private func generateOutput(from result: InspectionResult, mode: InspectionMode) -> String {
        switch mode {
        case .semantic:
            return generateSemanticOutput(from: result)
        case .forensic:
            return generateForensicOutput(from: result)
        case .losslessTree:
            return generateLosslessTreeOutput(from: result)
        }
    }
    
    /// Generate semantic (human-readable) output
    private func generateSemanticOutput(from result: InspectionResult) -> String {
        var output = ""
        
        output += "Assertion Object (Decoded)\n"
        output += "========================================\n\n"
        
        // Show authenticator data
        if let parsed = result.parsedAuthData {
            output += "Authenticator Data\n"
            output += "------------------\n"
            output += "Length: \(parsed.rawBytes.count) bytes\n"
            output += "RP ID Hash: \(parsed.authenticatorData.rpIdHash.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            output += "Flags: 0x\(String(format: "%02x", parsed.authenticatorData.flags.rawValue))\n"
            output += "  userPresent: \(parsed.authenticatorData.flags.userPresent)\n"
            output += "  userVerified: \(parsed.authenticatorData.flags.userVerified)\n"
            
            // Report flag vs payload status separately
            output += "  attestedCredentialData:\n"
            output += "    flag: \(parsed.hasATFlag ? "set (0x40)" : "not set")\n"
            output += "    payload: \(parsed.hasATPayload ? "present" : "absent")\n"
            if parsed.hasATFlag && !parsed.hasATPayload {
                output += "    ⚠️ status: inconsistent (flag set but no payload; treating as not present)\n"
            } else {
                output += "    status: \(parsed.attestedCredentialDataPresent ? "present" : "not present")\n"
            }
            
            output += "  extensionsIncluded:\n"
            output += "    flag: \(parsed.hasEDFlag ? "set (0x80)" : "not set")\n"
            output += "    payload: \(parsed.hasEDPayload ? "present" : "absent")\n"
            if parsed.hasEDFlag && !parsed.hasEDPayload {
                output += "    ⚠️ status: inconsistent (flag set but no payload; treating as not present)\n"
            } else {
                output += "    status: \(parsed.extensionsPresent ? "present" : "not present")\n"
            }
            output += "Sign Count: \(parsed.authenticatorData.signCount)\n\n"
        } else if let authDataBytes = result.authenticatorDataBytes {
            output += "Authenticator Data\n"
            output += "------------------\n"
            output += "Length: \(authDataBytes.count) bytes\n"
            output += "(Structure parsing failed - raw bytes available)\n\n"
        }
        
        // Show signature
        if let sig = result.signatureBytes {
            output += "Signature\n"
            output += "---------\n"
            output += "Length: \(sig.count) bytes\n"
            output += "Format: \(sig.count == 64 ? "Raw (r||s)" : sig.count >= 70 && sig.count <= 72 ? "ASN.1 DER" : "Unknown")\n"
            output += "Hex (first 32 bytes): \(sig.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            if sig.count > 32 {
                output += "Hex (last 16 bytes): \(sig.suffix(16).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            }
            output += "\n"
        }
        
        // Show decode status
        output += "Decode Status\n"
        output += "-------------\n"
        switch result.decodeStatus {
        case .success:
            output += "✅ Assertion object decoded successfully\n"
            if let parsed = result.parsedAuthData {
                output += "   - AuthenticatorData: ✅ Parsed (\(parsed.rawBytes.count) bytes)\n"
            }
            if let sig = result.signatureBytes {
                output += "   - Signature: ✅ Extracted (\(sig.count) bytes)\n"
            }
            output += "\n"
            output += "Note: This object does not contain a COSE envelope by design.\n"
            output += "Cryptographic verification requires external context:\n"
            output += "  • clientDataHash (from server challenge)\n"
            output += "  • public key (from attestation certificate)\n"
        case .partial(let reason):
            output += "⚠️ Partial decode: \(reason)\n"
        case .failed(let error):
            output += "❌ Decode failed: \(error)\n"
        }
        
        // Add virtual COSE envelope section if available
        if let virtualCOSE = result.virtualCOSE {
            output += "\n"
            output += formatVirtualCOSE(virtualCOSE, indent: 0)
        }
        
        return output
    }
    
    /// Format virtual COSE envelope for display
    private func formatVirtualCOSE(_ virtualCOSE: VirtualCOSESign1, indent: Int = 0) -> String {
        let indentStr = String(repeating: " ", count: indent)
        var output = ""
        
        output += "\(indentStr)Virtual COSE_Sign1 Envelope (Reconstructed)\n"
        output += "\(indentStr)==========================================\n"
        output += "\(indentStr)This COSE envelope is reconstructed according to the App Attest specification.\n"
        output += "\(indentStr)Assertion objects are not serialized as COSE, but signatures are computed over this structure.\n\n"
        
        output += "\(indentStr)Protected Headers:\n"
        output += "\(indentStr)  alg: ES256 (-7)\n"
        
        output += "\(indentStr)Unprotected Headers:\n"
        output += "\(indentStr)  (empty)\n\n"
        
        output += "\(indentStr)Payload (authenticatorData || clientDataHash):\n"
        if let clientDataHash = virtualCOSE.payloadComponents.clientDataHash {
            output += "\(indentStr)  authenticatorData: \(virtualCOSE.payloadComponents.authenticatorData.count) bytes\n"
            output += "\(indentStr)    hex (first 32): \(virtualCOSE.payloadComponents.authenticatorData.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            output += "\(indentStr)  clientDataHash: \(clientDataHash.count) bytes\n"
            output += "\(indentStr)    hex: \(clientDataHash.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            output += "\(indentStr)  concatenated payload: \(virtualCOSE.payload?.count ?? 0) bytes\n"
        } else {
            output += "\(indentStr)  authenticatorData: \(virtualCOSE.payloadComponents.authenticatorData.count) bytes\n"
            output += "\(indentStr)    hex (first 32): \(virtualCOSE.payloadComponents.authenticatorData.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            output += "\(indentStr)  clientDataHash: <missing - required for full payload reconstruction>\n"
            output += "\(indentStr)  concatenated payload: <incomplete - clientDataHash not available>\n"
        }
        
        output += "\(indentStr)\n"
        output += "\(indentStr)Signature:\n"
        output += "\(indentStr)  format: ASN.1 DER\n"
        output += "\(indentStr)  length: \(virtualCOSE.signature.count) bytes\n"
        output += "\(indentStr)  hex (first 32): \(virtualCOSE.signature.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
        if virtualCOSE.signature.count > 32 {
            output += "\(indentStr)  hex (last 16): \(virtualCOSE.signature.suffix(16).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
        }
        
        // Display Sig_structure bytes and SHA256 hash if available
        if let sigStructureCBOR = virtualCOSE.sigStructureCBOR,
           let sigStructureHash = virtualCOSE.sigStructureHash {
            output += "\(indentStr)\n"
            output += "\(indentStr)COSE_Sign1 Sig_structure (CBOR-encoded):\n"
            output += "\(indentStr)  Structure: [\"Signature1\", protected, external_aad, payload]\n"
            output += "\(indentStr)  Length: \(sigStructureCBOR.count) bytes\n"
            output += "\(indentStr)  CBOR (Base64): \(sigStructureCBOR.base64EncodedString())\n"
            output += "\(indentStr)  CBOR (hex, first 64): \(sigStructureCBOR.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " "))"
            if sigStructureCBOR.count > 64 {
                output += "..."
            }
            output += "\n"
            output += "\(indentStr)  SHA256 hash: \(sigStructureHash.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            output += "\(indentStr)  SHA256 hash (Base64): \(sigStructureHash.base64EncodedString())\n"
        }
        
        return output
    }
    
    /// Generate forensic (raw evidence) output
    private func generateForensicOutput(from result: InspectionResult) -> String {
        var output = ""
        
        output += "Assertion Object Decoded (Forensic View)\n"
        output += "========================================\n\n"
        
        switch result.decodeStatus {
        case .success:
            output += "Decode status: ✅ Full decode successful\n"
        case .partial(let reason):
            output += "Decode status: ⚠️ Partial decode: \(reason)\n"
        case .failed(let error):
            output += "Decode status: ❌ Decode failed: \(error)\n"
        }
        
        if !result.missingContext.isEmpty {
            output += "Missing context:\n"
            for item in result.missingContext {
                output += "  • \(item)\n"
            }
        }
        output += "\n"
        
        // CBOR structure
        if let cbor = result.cborValue {
            output += "CBOR STRUCTURE\n"
            output += "---------------\n"
            output += dumpCBORValueForDisplay(cbor, path: "assertionObject", indent: 0)
            output += "\n\n"
        }
        
        // Extracted fields
        output += "EXTRACTED FIELDS\n"
        output += "----------------\n"
        
        if let authData = result.authenticatorDataBytes {
            output += "Payload (AuthenticatorData): \(authData.count) bytes\n"
            output += "  Base64: \(authData.base64EncodedString())\n"
            output += "  Hex (first 64): \(authData.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " "))"
            if authData.count > 64 { output += "..." }
            output += "\n"
            
            if let parsed = result.parsedAuthData {
                output += "\nParsed AuthenticatorData:\n"
                
                // Show warnings if any
                if !parsed.warnings.isEmpty {
                    for warning in parsed.warnings {
                        output += "  ⚠️ \(warning.message)\n"
                    }
                }
                
                output += dumpAuthenticatorDataForDisplay(parsed, indent: 2)
            }
        }
        
        if let sig = result.signatureBytes {
            output += "\nSignature: \(sig.count) bytes\n"
            output += "  Base64: \(sig.base64EncodedString())\n"
            output += "  Hex: \(sig.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
        }
        
        output += "\nRAW BYTES\n"
        output += "---------\n"
        output += "Total Length: \(result.rawData.count) bytes\n"
        output += "Base64: \(result.rawData.base64EncodedString())\n"
        
        // Add virtual COSE envelope section if available
        if let virtualCOSE = result.virtualCOSE {
            output += "\n"
            output += formatVirtualCOSE(virtualCOSE, indent: 0)
        }
        
        return output
    }
    
    /// Generate lossless tree output
    private func generateLosslessTreeOutput(from result: InspectionResult) -> String {
        var output = ""
        
        output += "LOSSLESS TREE DUMP - Assertion Object\n"
        output += "========================================\n"
        output += "This is the complete CBOR structure for an App Attest assertion.\n"
        output += "Assertion objects are CBOR maps, not COSE_Sign1 messages.\n\n"
        
        switch result.decodeStatus {
        case .success:
            output += "Decode status: ✅ Full decode successful\n"
        case .partial(let reason):
            output += "Decode status: ⚠️ Partial decode: \(reason)\n"
        case .failed(let error):
            output += "Decode status: ❌ Decode failed: \(error)\n"
        }
        output += "\n"
        
        // CBOR structure
        if let cbor = result.cborValue {
            output += "CBOR STRUCTURE\n"
            output += "---------------\n"
            output += dumpCBORValueForDisplay(cbor, path: "assertionObject", indent: 0)
        }
        
        // Extracted authenticator data
        if let authData = result.authenticatorDataBytes {
            output += "\n\nEXTRACTED AUTHENTICATOR DATA\n"
            output += "----------------------------\n"
            if let parsed = result.parsedAuthData {
                output += dumpAuthenticatorDataForDisplay(parsed, indent: 0)
            } else {
                output += "Raw bytes: \(authData.count) bytes\n"
                output += "Hex: \(authData.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            }
        }
        
        // Extracted signature
        if let sig = result.signatureBytes {
            output += "\n\nEXTRACTED SIGNATURE\n"
            output += "-------------------\n"
            output += "Length: \(sig.count) bytes\n"
            output += "Hex: \(sig.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
        }
        
        // Add virtual COSE envelope section if available
        if let virtualCOSE = result.virtualCOSE {
            output += "\n"
            output += formatVirtualCOSE(virtualCOSE, indent: 0)
        }
        
        return output
    }
    
    // MARK: - Lossless Tree Helpers
    
    private func dumpCBORValueForDisplay(_ value: CBORValue, path: String, indent: Int) -> String {
        let indentStr = String(repeating: " ", count: indent)
        var output = ""
        
        switch value {
        case .unsigned(let u):
            output += "\(indentStr)\(path): unsigned(\(u))\n"
        case .negative(let n):
            output += "\(indentStr)\(path): negative(\(n))\n"
        case .byteString(let data):
            output += "\(indentStr)\(path): byteString(\(data.count) bytes)\n"
            if data.count <= 64 {
                output += "\(indentStr)  hex: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            } else {
                let preview = data.prefix(32)
                output += "\(indentStr)  hex (first 32): \(preview.map { String(format: "%02x", $0) }.joined(separator: " "))...\n"
            }
        case .textString(let str):
            output += "\(indentStr)\(path): textString(\"\(str)\")\n"
        case .array(let items):
            output += "\(indentStr)\(path): array(\(items.count) items)\n"
            for (index, item) in items.enumerated() {
                output += dumpCBORValueForDisplay(item, path: "\(path)[\(index)]", indent: indent + 2)
            }
        case .map(let map):
            output += "\(indentStr)\(path): map(\(map.count) pairs)\n"
            for (key, value) in map {
                let keyStr: String
                switch key {
                case .textString(let str):
                    keyStr = str
                case .unsigned(let u):
                    keyStr = "\(u)"
                case .negative(let n):
                    keyStr = "\(n)"
                default:
                    keyStr = "\(key)"
                }
                let keyPath = "\(path).\(keyStr)"
                output += dumpCBORValueForDisplay(value, path: keyPath, indent: indent + 2)
            }
        case .tagged(let tag, let value):
            output += "\(indentStr)\(path): tagged(\(tag), ...)\n"
            output += dumpCBORValueForDisplay(value, path: "\(path).value", indent: indent + 2)
        case .simple(let simple):
            output += "\(indentStr)\(path): simple(\(simple))\n"
        case .boolean(let b):
            output += "\(indentStr)\(path): boolean(\(b))\n"
        case .null:
            output += "\(indentStr)\(path): null\n"
        case .undefined:
            output += "\(indentStr)\(path): undefined\n"
        @unknown default:
            output += "\(indentStr)\(path): unknown CBOR type\n"
        }
        
        return output
    }
    
    private func dumpAuthenticatorDataForDisplay(_ parsed: ParsedAuthData, indent: Int) -> String {
        let indentStr = String(repeating: " ", count: indent)
        let authData = parsed.authenticatorData
        var output = ""
        
        output += "\(indentStr)rpIdHash: \(authData.rpIdHash.map { String(format: "%02x", $0) }.joined(separator: " ")) (32 bytes)\n"
        output += "\(indentStr)flags: 0x\(String(format: "%02x", authData.flags.rawValue))\n"
        output += "\(indentStr)  userPresent: \(authData.flags.userPresent)\n"
        output += "\(indentStr)  userVerified: \(authData.flags.userVerified)\n"
        
        // Report flag vs payload status separately (using shared parsed data)
        output += "\(indentStr)  attestedCredentialData:\n"
        output += "\(indentStr)    flag: \(parsed.hasATFlag ? "set (0x40)" : "not set")\n"
        output += "\(indentStr)    payload: \(parsed.hasATPayload ? "present" : "absent")\n"
        if parsed.hasATFlag && !parsed.hasATPayload {
            output += "\(indentStr)    ⚠️ status: inconsistent (flag set but no payload; treating as not present)\n"
        } else {
            output += "\(indentStr)    status: \(parsed.attestedCredentialDataPresent ? "present" : "not present")\n"
        }
        
        output += "\(indentStr)  extensionsIncluded:\n"
        output += "\(indentStr)    flag: \(parsed.hasEDFlag ? "set (0x80)" : "not set")\n"
        output += "\(indentStr)    payload: \(parsed.hasEDPayload ? "present" : "absent")\n"
        if parsed.hasEDFlag && !parsed.hasEDPayload {
            output += "\(indentStr)    ⚠️ status: inconsistent (flag set but no payload; treating as not present)\n"
        } else {
            output += "\(indentStr)    status: \(parsed.extensionsPresent ? "present" : "not present")\n"
        }
        output += "\(indentStr)signCount: \(authData.signCount)\n"
        output += "\(indentStr)rawData: \(parsed.rawBytes.count) bytes\n"
        
        return output
    }
    
    private func dumpCOSESign1ForDisplay(_ sign1: COSESign1, indent: Int) -> String {
        let indentStr = String(repeating: " ", count: indent)
        var output = ""
        
        output += "\(indentStr)protectedHeader:\n"
        if let alg = sign1.protectedHeader.algorithm {
            output += "\(indentStr)  algorithm: \(alg.rawValue)\n"
        }
        if let kid = sign1.protectedHeader.keyID {
            output += "\(indentStr)  keyID: \(kid.map { String(format: "%02x", $0) }.joined(separator: " ")) (\(kid.count) bytes)\n"
        }
        if !sign1.protectedHeader.x5c.isEmpty {
            output += "\(indentStr)  x5c: array(\(sign1.protectedHeader.x5c.count) certificates)\n"
            for (index, cert) in sign1.protectedHeader.x5c.enumerated() {
                output += "\(indentStr)    [\(index)]: \(cert.count) bytes\n"
            }
        }
        
        output += "\(indentStr)unprotectedHeader: (empty)\n"
        
        if let payload = sign1.payload {
            output += "\(indentStr)payload: \(payload.count) bytes\n"
        } else {
            output += "\(indentStr)payload: null\n"
        }
        
        output += "\(indentStr)signature: \(sign1.signature.map { String(format: "%02x", $0) }.joined(separator: " ")) (\(sign1.signature.count) bytes)\n"
        
        return output
    }
}

// Helper for sharing export data from AssertionInspectorView
struct AssertionExportShareSheet: UIViewControllerRepresentable {
    let exportData: Data
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-attest-assertion-\(UUID().uuidString).json")
        
        try? exportData.write(to: tempURL)
        
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
