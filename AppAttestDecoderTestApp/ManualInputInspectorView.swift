//
//  ManualInputInspectorView.swift
//  AppAttestDecoderTestApp
//
//  Manual paste/inspection mode for external App Attest artifacts.
//

import SwiftUI
import AppAttestCore
import UIKit

struct ManualInputInspectorView: View {
    @AppStorage("manualInput_keyID") private var keyID: String = ""
    @AppStorage("manualInput_clientDataHash") private var clientDataHash: String = ""
    @AppStorage("manualInput_publicKey") private var publicKey: String = ""
    @AppStorage("manualInput_encoding") private var encodingRaw: String = "base64"
    
    @State private var rawText: String = ""
    @State private var isInspecting: Bool = false
    @State private var inspectionResult: InspectionResult?
    @State private var inspectionError: String?
    @State private var selectedMode: InspectionMode = .semantic
    @State private var showExportSheet = false
    @State private var exportData: Data?
    @State private var inputWarnings: [String] = []
    
    private var encoding: InputEncoding {
        switch encodingRaw {
        case "base64URL": return .base64URL
        case "hex": return .hex
        default: return .base64
        }
    }
    
    private func setEncoding(_ newValue: InputEncoding) {
        switch newValue {
        case .base64URL: encodingRaw = "base64URL"
        case .hex: encodingRaw = "hex"
        default: encodingRaw = "base64"
        }
    }
    
    enum InspectionMode {
        case semantic
        case forensic
        case losslessTree
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Trust boundary banner
                VStack(alignment: .leading, spacing: 4) {
                    Text("This view shows what exists, not what is trusted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                Section("Input") {
                    Text("Paste Base64 / CBOR / Hex")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $rawText)
                        .frame(minHeight: 140)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: rawText) { oldValue, newValue in
                            checkInputWarnings(newValue)
                        }
                    
                    Picker("Encoding", selection: Binding(
                        get: { encoding },
                        set: { setEncoding($0) }
                    )) {
                        Text("Auto").tag(InputEncoding.base64) // Will use auto-normalize
                        Text("Base64").tag(InputEncoding.base64)
                        Text("Base64URL").tag(InputEncoding.base64URL)
                        Text("Hex").tag(InputEncoding.hex)
                    }
                    .pickerStyle(.menu)
                    
                    if !inputWarnings.isEmpty {
                        ForEach(inputWarnings, id: \.self) { warning in
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section("Optional Context") {
                    HStack {
                        TextField("KeyID (Base64)", text: $keyID)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !keyID.isEmpty {
                            Button {
                                UIPasteboard.general.string = keyID
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .imageScale(.small)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("clientDataHash (Base64)", text: $clientDataHash)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !clientDataHash.isEmpty {
                            Button {
                                UIPasteboard.general.string = clientDataHash
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .imageScale(.small)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Public Key (Base64 / DER)", text: $publicKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !publicKey.isEmpty {
                            Button {
                                UIPasteboard.general.string = publicKey
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .imageScale(.small)
                            }
                        }
                    }
                    
                    if keyID.isEmpty && clientDataHash.isEmpty && publicKey.isEmpty {
                        Text("Context missing: verification impossible without keyID, clientDataHash, and publicKey")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Context fields persist between sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(isInspecting ? "Inspecting..." : "Inspect") {
                        runInspection()
                    }
                    .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isInspecting)
                    
                    if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Paste artifact data above to begin inspection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !isInspecting && inspectionResult == nil {
                        Text("Tap 'Inspect' to decode the artifact")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let error = inspectionError {
                    Section("Error") {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if let result = inspectionResult {
                    Section("Trust Boundary") {
                        TrustBoundaryView(
                            hasDecodedData: result.parsedAuthData != nil || result.authenticatorDataBytes != nil,
                            hasReconstructedData: result.virtualCOSE != nil,
                            hasVerifiedData: false // Manual mode doesn't verify
                        )
                    }
                    
                    Section("Inspection Result") {
                        Picker("Mode", selection: $selectedMode) {
                            Text("Semantic").tag(InspectionMode.semantic)
                            Text("Forensic").tag(InspectionMode.forensic)
                            Text("Lossless Tree").tag(InspectionMode.losslessTree)
                        }
                        .pickerStyle(.segmented)
                        
                        ScrollView {
                            Text(formatResult(result, mode: selectedMode))
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(maxHeight: 400)
                    }
                    
                    Section("Export") {
                        Button("Export Inspection Data") {
                            exportInspectionData(result)
                        }
                    }
                }
            }
            .navigationTitle("Manual Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showExportSheet) {
                if let exportData = exportData {
                    ManualInputShareSheet(exportData: exportData)
                }
            }
        }
    }
    
    private func runInspection() {
        isInspecting = true
        inspectionError = nil
        inspectionResult = nil
        
        Task {
            do {
                // Normalize input
                let normalizedData: Data
                if encoding == .base64 {
                    // Use auto-normalize for "Auto" selection
                    normalizedData = try InputNormalizer.autoNormalize(rawText)
                } else {
                    normalizedData = try InputNormalizer.normalize(rawText, encoding: encoding)
                }
                
                // Build context
                var context: InspectionContext?
                if !keyID.isEmpty || !clientDataHash.isEmpty || !publicKey.isEmpty {
                    let clientDataHashData = clientDataHash.isEmpty ? nil : Data(base64Encoded: clientDataHash)
                    let publicKeyData = publicKey.isEmpty ? nil : Data(base64Encoded: publicKey)
                    
                    context = InspectionContext(
                        keyID: keyID.isEmpty ? nil : keyID,
                        clientDataHash: clientDataHashData,
                        publicKey: publicKeyData
                    )
                }
                
                // Run inspection (off main thread)
                let result = try await Task.detached {
                    try AppAttestInspector.inspect(data: normalizedData, context: context)
                }.value
                
                await MainActor.run {
                    inspectionResult = result
                    isInspecting = false
                    
                    // Add warnings based on result
                    if let sig = result.signatureBytes {
                        if sig.count != 64 && sig.count != 70 && sig.count != 72 {
                            inputWarnings.append("⚠️ Signature length (\(sig.count) bytes) is unusual but may be valid")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    inspectionError = error.localizedDescription
                    isInspecting = false
                }
            }
        }
    }
    
    private func formatResult(_ result: InspectionResult, mode: InspectionMode) -> String {
        // Use the same formatting logic as AssertionInspectorView
        // This ensures consistency between live and manual inspection
        var output = ""
        
        switch mode {
        case .semantic:
            output += formatSemantic(result)
        case .forensic:
            output += formatForensic(result)
        case .losslessTree:
            output += formatLosslessTree(result)
        }
        
        return output
    }
    
    private func formatSemantic(_ result: InspectionResult) -> String {
        var output = ""
        
        output += "Artifact Type: \(result.artifactType)\n"
        output += "Decode Status: \(result.decodeStatus)\n\n"
        
        if let parsed = result.parsedAuthData {
            output += "Authenticator Data\n"
            output += "------------------\n"
            output += "Length: \(parsed.rawBytes.count) bytes\n"
            output += "RP ID Hash: \(parsed.authenticatorData.rpIdHash.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            output += "Flags: 0x\(String(format: "%02x", parsed.authenticatorData.flags.rawValue))\n"
            output += "  userPresent: \(parsed.authenticatorData.flags.userPresent)\n"
            output += "  userVerified: \(parsed.authenticatorData.flags.userVerified)\n"
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
        }
        
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
        
        if let virtualCOSE = result.virtualCOSE {
            output += formatVirtualCOSE(virtualCOSE, indent: 0)
        }
        
        if !result.warnings.isEmpty {
            output += "\nWarnings:\n"
            for warning in result.warnings {
                output += "⚠️ \(warning.message)\n"
            }
        }
        
        if !result.missingContext.isEmpty {
            output += "\nMissing Context:\n"
            for item in result.missingContext {
                output += "• \(item)\n"
            }
        }
        
        return output
    }
    
    private func formatForensic(_ result: InspectionResult) -> String {
        var output = ""
        
        output += "Artifact Type: \(result.artifactType)\n"
        output += "Decode Status: \(result.decodeStatus)\n\n"
        
        if let cbor = result.cborValue {
            output += "CBOR STRUCTURE\n"
            output += "---------------\n"
            output += formatCBORValue(cbor, path: "artifact", indent: 0)
            output += "\n\n"
        }
        
        if let authData = result.authenticatorDataBytes {
            output += "EXTRACTED FIELDS\n"
            output += "----------------\n"
            output += "Payload (AuthenticatorData): \(authData.count) bytes\n"
            output += "  Base64: \(authData.base64EncodedString())\n"
            output += "  Hex (first 64): \(authData.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " "))"
            if authData.count > 64 { output += "..." }
            output += "\n"
            
            if let parsed = result.parsedAuthData {
                output += "\nParsed AuthenticatorData:\n"
                if !parsed.warnings.isEmpty {
                    for warning in parsed.warnings {
                        output += "  ⚠️ \(warning.message)\n"
                    }
                }
                output += formatAuthenticatorData(parsed, indent: 2)
            }
        }
        
        if let sig = result.signatureBytes {
            output += "\nSignature: \(sig.count) bytes\n"
            output += "  Base64: \(sig.base64EncodedString())\n"
            output += "  Hex: \(sig.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
        }
        
        if let virtualCOSE = result.virtualCOSE {
            output += "\n"
            output += formatVirtualCOSE(virtualCOSE, indent: 0)
        }
        
        return output
    }
    
    private func formatLosslessTree(_ result: InspectionResult) -> String {
        var output = ""
        
        output += "LOSSLESS TREE VIEW\n"
        output += "==================\n\n"
        output += "This is the complete CBOR structure for an App Attest artifact.\n\n"
        
        if let cbor = result.cborValue {
            output += "CBOR STRUCTURE\n"
            output += "---------------\n"
            output += formatCBORValue(cbor, path: "artifact", indent: 0)
        }
        
        if let authData = result.authenticatorDataBytes {
            output += "\n\nEXTRACTED AUTHENTICATOR DATA\n"
            output += "----------------------------\n"
            if let parsed = result.parsedAuthData {
                output += formatAuthenticatorData(parsed, indent: 0)
            } else {
                output += "Raw bytes: \(authData.count) bytes\n"
                output += "Hex: \(authData.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            }
        }
        
        if let sig = result.signatureBytes {
            output += "\n\nEXTRACTED SIGNATURE\n"
            output += "-------------------\n"
            output += "Length: \(sig.count) bytes\n"
            output += "Hex: \(sig.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
        }
        
        return output
    }
    
    private func formatVirtualCOSE(_ virtualCOSE: VirtualCOSESign1, indent: Int) -> String {
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
    
    private func formatAuthenticatorData(_ parsed: ParsedAuthData, indent: Int) -> String {
        let indentStr = String(repeating: " ", count: indent)
        let authData = parsed.authenticatorData
        var output = ""
        
        output += "\(indentStr)rpIdHash: \(authData.rpIdHash.map { String(format: "%02x", $0) }.joined(separator: " ")) (32 bytes)\n"
        output += "\(indentStr)flags: 0x\(String(format: "%02x", authData.flags.rawValue))\n"
        output += "\(indentStr)  userPresent: \(authData.flags.userPresent)\n"
        output += "\(indentStr)  userVerified: \(authData.flags.userVerified)\n"
        
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
    
    private func formatCBORValue(_ value: CBORValue, path: String, indent: Int) -> String {
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
                output += formatCBORValue(item, path: "\(path)[\(index)]", indent: indent + 2)
            }
        case .map(let pairs):
            output += "\(indentStr)\(path): map(\(pairs.count) pairs)\n"
            for (key, value) in pairs {
                var keyStr = ""
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
                output += formatCBORValue(value, path: keyPath, indent: indent + 2)
            }
        case .tagged(let tag, let value):
            output += "\(indentStr)\(path): tagged(\(tag), ...)\n"
            output += formatCBORValue(value, path: "\(path).value", indent: indent + 2)
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
    
    private func checkInputWarnings(_ input: String) {
        var warnings: [String] = []
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            inputWarnings = []
            return
        }
        
        // Check for Base64URL vs Base64
        if trimmed.contains("-") || trimmed.contains("_") {
            if encoding == .base64 {
                warnings.append("⚠️ Input contains '-' or '_': This looks like Base64URL, not Base64")
            }
        }
        
        // Check for hex patterns
        let hexPattern = trimmed.replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if hexPattern.count % 2 == 0 && hexPattern.allSatisfy({ $0.isHexDigit }) && encoding != .hex {
            warnings.append("⚠️ Input looks like hex, but encoding is set to \(encoding == .base64 ? "Base64" : "Base64URL")")
        }
        
        inputWarnings = warnings
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
}

// Helper for sharing export data
struct ManualInputShareSheet: UIViewControllerRepresentable {
    let exportData: Data
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-attest-inspection-\(UUID().uuidString).json")
        
        try? exportData.write(to: tempURL)
        
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
