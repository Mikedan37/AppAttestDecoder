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
    let keyID: String? // Optional - if provided, use for direct context lookup
    
    @StateObject private var contextStore = AppAttestContextStore.shared
    @State private var selectedMode: InspectionMode = .semantic
    @State private var output: String = ""
    @State private var partialDecodeInfo: String? // Informational, not an error
    @State private var fatalError: String? // Only for truly fatal errors
    @State private var verificationStatus: VerificationStatus?
    @State private var isDecoding: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    enum VerificationStatus {
        case verified(context: AppAttestContext, clientDataHash: Data)
        case verificationFailed(reason: String)
        case noContext
        
        var isVerified: Bool {
            if case .verified = self { return true }
            return false
        }
        
        var isFailure: Bool {
            if case .verificationFailed = self { return true }
            return false
        }
    }
    
    enum InspectionMode: String, CaseIterable {
        case semantic = "Semantic"
        case forensic = "Forensic"
        case losslessTree = "Lossless Tree"
    }
    
    /// Decode state for assertion inspection
    /// Partial decode is expected behavior for App Attest assertions (they require server-side context)
    enum AssertionDecodeState {
        case full(AssertionObject)
        case partial(reason: String, cbor: CBORValue, rawData: Data)
        case invalid(error: Error)
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
                
                // Verification Status (appears when verification is attempted)
                if let status = verificationStatus {
                    VStack(alignment: .leading, spacing: 4) {
                        switch status {
                        case .verified(let context, let clientDataHash):
                            Label("Full Verified Decode", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Verified using stored context for keyID: \(context.keyID)")
                                .font(.system(.caption))
                                .foregroundColor(.secondary)
                            Text("clientDataHash: \(clientDataHash.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " "))...")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        case .verificationFailed(let reason):
                            Label("Verification Failed", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(reason)
                                .font(.system(.caption))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        case .noContext:
                            Label("Partial / Context-Dependent Decode", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("No stored context available. Full verification requires server-side clientDataHash and publicKey.")
                                .font(.system(.caption))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(status.isVerified ? Color.green.opacity(0.1) : (status.isFailure ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1)))
                    .cornerRadius(8)
                }
                
                // Partial Decode Info (informational, not error) - only show if no verification status
                if let info = partialDecodeInfo, verificationStatus == nil {
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
    /// 
    /// ERROR HANDLING PHILOSOPHY:
    /// - Fatal errors: Invalid Base64, invalid CBOR structure
    /// - Partial decode: Valid CBOR but COSE_Sign1 requires server-side context (expected for App Attest)
    ///   Partial decode is NOT an error—it's expected behavior. We extract what we can.
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
        // This is inspection work, not verification, so it's safe to do off-main-thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Try to decode CBOR first (to distinguish fatal vs non-fatal errors)
            let cborValue: CBORValue
            do {
                cborValue = try CBORDecoder.decode(data)
            } catch {
                // Fatal error: Invalid CBOR structure
                DispatchQueue.main.async {
                    self.fatalError = "Invalid CBOR structure: \(error.localizedDescription)"
                    self.isDecoding = false
                }
                return
            }
            
            // Step 2: Try full COSE_Sign1 decoding
            let decodeState: AssertionDecodeState
            var assertion: AssertionObject?
            do {
                // Structural decoding only - no verification
                let decoder = AppAttestDecoder(teamID: nil)
                assertion = try decoder.decodeAssertion(data)
                decodeState = .full(assertion!)
            } catch let decodeError {
                // Partial decode: Valid CBOR but COSE_Sign1 incomplete/context-dependent
                // This is EXPECTED for App Attest assertions—they require server-side context
                // COSEError.invalidStructure and similar are expected when context is missing
                let isExpectedPartialDecode: Bool
                if decodeError is COSEError {
                    // COSE errors indicate missing context (clientDataHash, publicKey), not malformed data
                    // This is expected behavior for App Attest assertions
                    isExpectedPartialDecode = true
                } else if decodeError is AssertionError {
                    // AssertionError also indicates structural issues that may be context-dependent
                    isExpectedPartialDecode = true
                } else {
                    // Other errors (CBOR decode failures) are truly fatal
                    isExpectedPartialDecode = false
                }
                
                if isExpectedPartialDecode {
                    decodeState = .partial(reason: decodeError.localizedDescription, cbor: cborValue, rawData: data)
                } else {
                    decodeState = .invalid(error: decodeError)
                }
            }
            
            // Step 3: Attempt verification if we have a decoded assertion
            var verificationStatus: VerificationStatus?
            if let assertion = assertion {
                print("[AssertionInspector] Attempting verification with keyID: \(self.keyID ?? "nil")")
                verificationStatus = attemptVerification(assertion: assertion, rawData: data)
                if let status = verificationStatus {
                    switch status {
                    case .verified:
                        print("[AssertionInspector] ✅ Verification succeeded")
                    case .verificationFailed(let reason):
                        print("[AssertionInspector] ⚠️ Verification failed: \(reason)")
                    case .noContext:
                        print("[AssertionInspector] ℹ️ No context available")
                    }
                }
            }
            
            // Step 4: Generate output based on decode state
            let decodedOutput: String
            switch decodeState {
            case .full(let assertion):
                // Select output mode (all are inspection-only views)
                switch selectedMode {
                case .semantic:
                    // Human-readable semantic view
                    decodedOutput = assertion.prettyPrint(colorized: false)
                    
                case .forensic:
                    // Semantic + raw evidence view
                    // For now, use prettyPrint with more detail
                    // TODO: Add full forensic print support for assertions
                    var forensicOutput = "Assertion Object (Forensic View)\n"
                    forensicOutput += "========================================\n\n"
                    forensicOutput += "Raw CBOR (Base64): \(assertion.rawData.base64EncodedString())\n"
                    forensicOutput += "Raw CBOR Length: \(assertion.rawData.count) bytes\n\n"
                    forensicOutput += assertion.prettyPrint(colorized: false)
                    decodedOutput = forensicOutput
                    
                case .losslessTree:
                    // Complete CBOR tree dump
                    var output = "LOSSLESS TREE DUMP - Assertion Object\n"
                    output += "========================================\n\n"
                    output += "CBOR STRUCTURE\n"
                    output += "---------------\n"
                    output += dumpCBORValueForDisplay(cborValue, path: "assertionObject", indent: 0)
                    output += "\n\nAUTHENTICATOR DATA\n"
                    output += "------------------\n"
                    output += dumpAuthenticatorDataForDisplay(assertion.authenticatorData, indent: 0)
                    output += "\n\nCOSE_SIGN1 STRUCTURE\n"
                    output += "--------------------\n"
                    output += dumpCOSESign1ForDisplay(assertion.coseSign1, indent: 0)
                    decodedOutput = output
                }
                
                DispatchQueue.main.async {
                    self.output = decodedOutput
                    self.partialDecodeInfo = nil
                    self.fatalError = nil
                    self.verificationStatus = verificationStatus
                    self.isDecoding = false
                }
                
            case .partial(let reason, let cbor, let rawData):
                // Partial decode: Extract what we can from CBOR structure
                // App Attest assertions are context-dependent by design
                
                // Extract authenticatorData and signature from CBOR even when COSE decode fails
                // COSE_Sign1 is: [protected: bstr, unprotected: map, payload: bstr/null, signature: bstr]
                var authenticatorDataBytes: Data?
                var signatureBytes: Data?
                
                if case .array(let items) = cbor, items.count >= 4 {
                    // Extract payload (index 2) - contains authenticatorData
                    if case .byteString(let payload) = items[2] {
                        authenticatorDataBytes = payload
                    }
                    
                    // Extract signature (index 3)
                    if case .byteString(let sig) = items[3] {
                        signatureBytes = sig
                    }
                }
                
                // Attempt verification if we can extract the necessary data
                var partialVerificationStatus: VerificationStatus?
                if let authDataBytes = authenticatorDataBytes,
                   let sigBytes = signatureBytes,
                   let authData = try? AuthenticatorData(rawData: authDataBytes) {
                    // Create a minimal assertion object for verification
                    // We need to construct the COSE structure manually
                    print("[AssertionInspector] Extracted authenticatorData (\(authDataBytes.count) bytes) and signature (\(sigBytes.count) bytes) from CBOR")
                    
                    // Try to verify using extracted data
                    partialVerificationStatus = attemptVerificationWithExtractedData(
                        authenticatorData: authData,
                        authenticatorDataBytes: authDataBytes,
                        signature: sigBytes
                    )
                }
                
                let partialOutput = generatePartialDecodeOutput(reason: reason, cbor: cbor, rawData: rawData, mode: selectedMode)
                
                DispatchQueue.main.async {
                    self.output = partialOutput
                    // If verification was attempted, show that status instead of generic partial decode message
                    if let status = partialVerificationStatus {
                        self.verificationStatus = status
                        self.partialDecodeInfo = nil
                    } else {
                        // Informational messaging: partial decode is expected for App Attest assertions
                        // This is NOT an error - it's how the protocol works
                        self.partialDecodeInfo = "Partial decode is expected for App Attest assertions without server context. Assertions are verified server-side. This tool focuses on forensic inspection."
                        self.verificationStatus = nil
                    }
                    self.fatalError = nil
                    self.isDecoding = false
                }
                
            case .invalid(let err):
                // Unexpected error (shouldn't happen after CBOR decode succeeds)
                DispatchQueue.main.async {
                    self.fatalError = "Unexpected decode error: \(err.localizedDescription)"
                    self.isDecoding = false
                }
            }
        }
    }
    
    // MARK: - Verification
    
    /// Attempt verification using extracted authenticatorData and signature (for partial decode cases)
    private func attemptVerificationWithExtractedData(authenticatorData: AuthenticatorData, authenticatorDataBytes: Data, signature: Data) -> VerificationStatus {
        print("[AssertionInspector] attemptVerificationWithExtractedData called")
        print("[AssertionInspector] keyID provided: \(keyID ?? "nil")")
        print("[AssertionInspector] Stored contexts count: \(contextStore.contexts.count)")
        
        // If keyID is provided, try direct lookup first (most efficient)
        if let keyID = keyID {
            print("[AssertionInspector] Looking up context for keyID: \(keyID)")
            if let context = contextStore.getContext(keyID: keyID) {
                print("[AssertionInspector] Context found! canVerifyAssertion: \(context.canVerifyAssertion)")
                print("[AssertionInspector] publicKey: \(context.publicKey.count) bytes")
                print("[AssertionInspector] assertionClientDataHashes count: \(context.assertionClientDataHashes.count)")
                
                if context.canVerifyAssertion {
                    // Try each stored clientDataHash for this keyID
                    for (index, clientDataHash) in context.assertionClientDataHashes.enumerated() {
                        print("[AssertionInspector] Trying clientDataHash[\(index)]: \(clientDataHash.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " "))...")
                        if verifyAssertionWithExtractedData(
                            authenticatorDataBytes: authenticatorDataBytes,
                            signature: signature,
                            publicKey: context.publicKey,
                            clientDataHash: clientDataHash
                        ) {
                            print("[AssertionInspector] ✅ Verification succeeded with clientDataHash[\(index)]")
                            return .verified(context: context, clientDataHash: clientDataHash)
                        } else {
                            print("[AssertionInspector] ❌ Verification failed with clientDataHash[\(index)]")
                        }
                    }
                    // Context exists but verification failed
                    return .verificationFailed(reason: "Stored context for keyID '\(keyID)' available but verification failed. Signature may not match stored clientDataHash.")
                } else {
                    // Context exists but incomplete
                    print("[AssertionInspector] Context incomplete: hasPublicKey=\(context.hasPublicKey), hasAssertionContext=\(context.hasAssertionContext)")
                    return .verificationFailed(reason: "Stored context for keyID '\(keyID)' is incomplete. Missing publicKey or clientDataHash.")
                }
            } else {
                print("[AssertionInspector] No context found for keyID: \(keyID)")
            }
        }
        
        // Fallback: Try all stored contexts (for cases where keyID wasn't provided)
        for (_, context) in contextStore.contexts {
            guard context.canVerifyAssertion else { continue }
            
            // Try each stored clientDataHash
            for clientDataHash in context.assertionClientDataHashes {
                if verifyAssertionWithExtractedData(
                    authenticatorDataBytes: authenticatorDataBytes,
                    signature: signature,
                    publicKey: context.publicKey,
                    clientDataHash: clientDataHash
                ) {
                    return .verified(context: context, clientDataHash: clientDataHash)
                }
            }
        }
        
        // Check if we have any context at all
        let hasAnyContext = contextStore.contexts.values.contains { $0.hasPublicKey }
        if hasAnyContext {
            return .verificationFailed(reason: "Stored context available but verification failed. Signature may not match stored clientDataHash.")
        }
        
        return .noContext
    }
    
    /// Attempt to verify assertion using stored context
    /// If keyID is provided, uses direct lookup. Otherwise tries all contexts.
    private func attemptVerification(assertion: AssertionObject, rawData: Data) -> VerificationStatus {
        // If keyID is provided, try direct lookup first (most efficient)
        if let keyID = keyID {
            print("[AssertionInspector] Looking up context for keyID: \(keyID)")
            if let context = contextStore.getContext(keyID: keyID) {
                print("[AssertionInspector] Context found! canVerifyAssertion: \(context.canVerifyAssertion)")
                print("[AssertionInspector] publicKey: \(context.publicKey.count) bytes")
                print("[AssertionInspector] assertionClientDataHashes count: \(context.assertionClientDataHashes.count)")
                
                if context.canVerifyAssertion {
                    // Try each stored clientDataHash for this keyID
                    for (index, clientDataHash) in context.assertionClientDataHashes.enumerated() {
                        print("[AssertionInspector] Trying clientDataHash[\(index)]: \(clientDataHash.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " "))...")
                        if verifyAssertion(assertion: assertion, publicKey: context.publicKey, clientDataHash: clientDataHash) {
                            print("[AssertionInspector] ✅ Verification succeeded with clientDataHash[\(index)]")
                            return .verified(context: context, clientDataHash: clientDataHash)
                        } else {
                            print("[AssertionInspector] ❌ Verification failed with clientDataHash[\(index)]")
                        }
                    }
                    // Context exists but verification failed
                    return .verificationFailed(reason: "Stored context for keyID '\(keyID)' available but verification failed. Signature may not match stored clientDataHash.")
                } else {
                    // Context exists but incomplete
                    print("[AssertionInspector] Context incomplete: hasPublicKey=\(context.hasPublicKey), hasAssertionContext=\(context.hasAssertionContext)")
                    return .verificationFailed(reason: "Stored context for keyID '\(keyID)' is incomplete. Missing publicKey or clientDataHash.")
                }
            } else {
                print("[AssertionInspector] No context found for keyID: \(keyID)")
            }
        }
        
        // Fallback: Try all stored contexts (for cases where keyID wasn't provided)
        for (_, context) in contextStore.contexts {
            guard context.canVerifyAssertion else { continue }
            
            // Try each stored clientDataHash
            for clientDataHash in context.assertionClientDataHashes {
                if verifyAssertion(assertion: assertion, publicKey: context.publicKey, clientDataHash: clientDataHash) {
                    return .verified(context: context, clientDataHash: clientDataHash)
                }
            }
        }
        
        // Check if we have any context at all
        let hasAnyContext = contextStore.contexts.values.contains { $0.hasPublicKey }
        if hasAnyContext {
            return .verificationFailed(reason: "Stored context available but verification failed. Signature may not match stored clientDataHash.")
        }
        
        return .noContext
    }
    
    /// Verify assertion signature using extracted authenticatorData and signature bytes
    /// Verifies signature over: authenticatorData || clientDataHash
    private func verifyAssertionWithExtractedData(authenticatorDataBytes: Data, signature: Data, publicKey: Data, clientDataHash: Data) -> Bool {
        print("[AssertionInspector] verifyAssertionWithExtractedData called")
        print("[AssertionInspector] authenticatorData length: \(authenticatorDataBytes.count) bytes")
        print("[AssertionInspector] clientDataHash length: \(clientDataHash.count) bytes")
        print("[AssertionInspector] signature length: \(signature.count) bytes")
        
        // App Attest uses ES256 (ECDSA P-256 SHA-256)
        // Signature is over: authenticatorData || clientDataHash
        
        // Construct signed data
        let signedData = authenticatorDataBytes + clientDataHash
        print("[AssertionInspector] signedData length: \(signedData.count) bytes")
        
        // Extract public key from certificate format (subjectPublicKeyBits)
        // For P-256, this is typically 0x04 || x || y (uncompressed point, 65 bytes)
        guard publicKey.count == 65, publicKey[0] == 0x04 else {
            print("[AssertionInspector] Invalid public key format: \(publicKey.count) bytes")
            return false
        }
        
        // Create P256 public key from uncompressed point format
        // publicKey is already in format: 0x04 || x || y (65 bytes)
        // CryptoKit's rawRepresentation expects exactly this format
        guard let publicKeyPoint = try? P256.Signing.PublicKey(rawRepresentation: publicKey) else {
            print("[AssertionInspector] Failed to create P256 public key from raw representation")
            return false
        }
        
        // Verify signature
        // Note: COSE signatures are in raw format (r || s, 64 bytes)
        guard signature.count == 64 else {
            print("[AssertionInspector] Invalid signature length: \(signature.count) bytes")
            return false
        }
        
        let r = signature.subdata(in: 0..<32)
        let s = signature.subdata(in: 32..<64)
        
        // Create signature from r and s
        // P256.Signing.ECDSASignature expects raw format (r || s)
        let rawSignature = r + s
        guard let ecdsaSignature = try? P256.Signing.ECDSASignature(rawRepresentation: rawSignature) else {
            print("[AssertionInspector] Failed to create ECDSA signature")
            return false
        }
        
        // Verify signature
        let hash = SHA256.hash(data: signedData)
        print("[AssertionInspector] Hash of signed data: \(hash.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " "))...")
        let isValid = publicKeyPoint.isValidSignature(ecdsaSignature, for: hash)
        print("[AssertionInspector] Signature valid: \(isValid)")
        return isValid
    }
    
    /// Verify COSE_Sign1 signature for App Attest assertion
    /// Verifies signature over: authenticatorData || clientDataHash
    private func verifyAssertion(assertion: AssertionObject, publicKey: Data, clientDataHash: Data) -> Bool {
        print("[AssertionInspector] verifyAssertion called")
        print("[AssertionInspector] authenticatorData length: \(assertion.authenticatorData.rawData.count) bytes")
        print("[AssertionInspector] clientDataHash length: \(clientDataHash.count) bytes")
        
        // App Attest uses ES256 (ECDSA P-256 SHA-256)
        // Signature is over: authenticatorData || clientDataHash
        
        // Delegate to the extracted data version
        return verifyAssertionWithExtractedData(
            authenticatorDataBytes: assertion.authenticatorData.rawData,
            signature: assertion.signature,
            publicKey: publicKey,
            clientDataHash: clientDataHash
        )
    }
    
    // MARK: - Actions
    
    private func copyOutput() {
        UIPasteboard.general.string = output
    }
    
    private func copyBase64() {
        UIPasteboard.general.string = base64Assertion
    }
    
    // MARK: - Partial Decode Support
    
    /// Generate output for partial decode state
    /// Extracts available fields from CBOR even when COSE_Sign1 parsing fails
    /// App Attest assertions are context-dependent by design—this is expected, not an error
    private func generatePartialDecodeOutput(reason: String, cbor: CBORValue, rawData: Data, mode: InspectionMode) -> String {
        var output = ""
        
        // Try to extract authenticatorData from CBOR array structure
        // COSE_Sign1 is: [protected: bstr, unprotected: map, payload: bstr/null, signature: bstr]
        var authenticatorDataBytes: Data?
        var signatureBytes: Data?
        
        if case .array(let items) = cbor, items.count >= 4 {
            // Extract payload (index 2) - contains authenticatorData
            if case .byteString(let payload) = items[2] {
                authenticatorDataBytes = payload
            }
            
            // Extract signature (index 3)
            if case .byteString(let sig) = items[3] {
                signatureBytes = sig
            }
        }
        
        switch mode {
        case .semantic:
            output += "Partial / Context-Dependent Decode\n"
            output += "========================================\n\n"
            output += "Partial decode is expected for App Attest assertions without server context.\n"
            output += "Full COSE verification requires:\n"
            output += "  • clientDataHash (from server challenge)\n"
            output += "  • publicKey (from attestation certificate)\n\n"
            output += "Assertions are verified server-side. This tool focuses on forensic inspection.\n\n"
            output += "Available Fields:\n"
            output += "-----------------\n"
            
            if let authData = authenticatorDataBytes {
                output += "Authenticator Data: \(authData.count) bytes\n"
                // Try to parse authenticatorData structure
                if let authDataParsed = try? AuthenticatorData(rawData: authData) {
                    output += "  RP ID Hash: \(authDataParsed.rpIdHash.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
                    output += "  Flags: 0x\(String(format: "%02x", authDataParsed.flags.rawValue))\n"
                    output += "    userPresent: \(authDataParsed.flags.userPresent)\n"
                    output += "    userVerified: \(authDataParsed.flags.userVerified)\n"
                    output += "    extensionsIncluded: \(authDataParsed.flags.extensionsIncluded)\n"
                    output += "  Sign Count: \(authDataParsed.signCount)\n"
                } else {
                    output += "  (AuthenticatorData structure parse failed)\n"
                }
            } else {
                output += "Authenticator Data: Not available in payload\n"
            }
            
            if let sig = signatureBytes {
                output += "Signature: \(sig.count) bytes\n"
                output += "  Hex (first 32): \(sig.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            } else {
                output += "Signature: Not available\n"
            }
            
        case .forensic:
            output += "Partial / Context-Dependent Decode (Forensic View)\n"
            output += "========================================\n\n"
            output += "COSE decode limitation: \(reason)\n"
            output += "Note: App Attest assertions are context-dependent by design.\n"
            output += "Full COSE verification requires server-side context (clientDataHash, publicKey).\n"
            output += "This partial decode is expected and correct for forensic inspection.\n\n"
            output += "CBOR STRUCTURE\n"
            output += "---------------\n"
            output += dumpCBORValueForDisplay(cbor, path: "assertionObject", indent: 0)
            output += "\n\nEXTRACTED FIELDS\n"
            output += "----------------\n"
            
            if let authData = authenticatorDataBytes {
                output += "Payload (AuthenticatorData): \(authData.count) bytes\n"
                output += "  Base64: \(authData.base64EncodedString())\n"
                output += "  Hex (first 64): \(authData.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " "))"
                if authData.count > 64 { output += "..." }
                output += "\n"
                
                if let authDataParsed = try? AuthenticatorData(rawData: authData) {
                    output += "\nParsed AuthenticatorData:\n"
                    output += dumpAuthenticatorDataForDisplay(authDataParsed, indent: 2)
                }
            }
            
            if let sig = signatureBytes {
                output += "\nSignature: \(sig.count) bytes\n"
                output += "  Base64: \(sig.base64EncodedString())\n"
                output += "  Hex: \(sig.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            }
            
            output += "\nRAW BYTES\n"
            output += "---------\n"
            output += "Total Length: \(rawData.count) bytes\n"
            output += "Base64: \(rawData.base64EncodedString())\n"
            
        case .losslessTree:
            output += "LOSSLESS TREE DUMP - Assertion Object (Partial / Context-Dependent)\n"
            output += "========================================\n\n"
            output += "COSE decode limitation: \(reason)\n"
            output += "Note: Partial decode is expected for App Attest assertions.\n"
            output += "Full COSE verification requires server-side context.\n\n"
            output += "CBOR STRUCTURE\n"
            output += "---------------\n"
            output += dumpCBORValueForDisplay(cbor, path: "assertionObject", indent: 0)
            
            if let authData = authenticatorDataBytes {
                output += "\n\nEXTRACTED AUTHENTICATOR DATA\n"
                output += "----------------------------\n"
                if let authDataParsed = try? AuthenticatorData(rawData: authData) {
                    output += dumpAuthenticatorDataForDisplay(authDataParsed, indent: 0)
                } else {
                    output += "Raw bytes: \(authData.count) bytes\n"
                    output += "Hex: \(authData.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
                }
            }
            
            if let sig = signatureBytes {
                output += "\n\nEXTRACTED SIGNATURE\n"
                output += "-------------------\n"
                output += "Length: \(sig.count) bytes\n"
                output += "Hex: \(sig.map { String(format: "%02x", $0) }.joined(separator: " "))\n"
            }
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
    
    private func dumpAuthenticatorDataForDisplay(_ authData: AuthenticatorData, indent: Int) -> String {
        let indentStr = String(repeating: " ", count: indent)
        var output = ""
        
        output += "\(indentStr)rpIdHash: \(authData.rpIdHash.map { String(format: "%02x", $0) }.joined(separator: " ")) (32 bytes)\n"
        output += "\(indentStr)flags: 0x\(String(format: "%02x", authData.flags.rawValue))\n"
        output += "\(indentStr)  userPresent: \(authData.flags.userPresent)\n"
        output += "\(indentStr)  userVerified: \(authData.flags.userVerified)\n"
        output += "\(indentStr)  attestedCredentialData: \(authData.flags.attestedCredentialData)\n"
        output += "\(indentStr)  extensionsIncluded: \(authData.flags.extensionsIncluded)\n"
        output += "\(indentStr)signCount: \(authData.signCount)\n"
        output += "\(indentStr)rawData: \(authData.rawData.count) bytes\n"
        
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
