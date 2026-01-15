//
//  ForensicPrinter.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/14/26.
//
//  Forensic-grade printer that shows raw bytes + decoded values
//  Lossless, transparent, spec-compliant inspection
//

import Foundation

/// Forensic printing mode configuration
public struct ForensicMode {
    public let showRaw: Bool
    public let showDecoded: Bool
    public let showJSON: Bool
    public let colorized: Bool
    public let fullTranscript: Bool
    
    public init(showRaw: Bool = true, showDecoded: Bool = true, showJSON: Bool = false, colorized: Bool = false, fullTranscript: Bool = false) {
        self.showRaw = showRaw
        self.showDecoded = showDecoded
        self.showJSON = showJSON
        self.colorized = colorized
        self.fullTranscript = fullTranscript
    }
    
    public static let both = ForensicMode(showRaw: true, showDecoded: true, showJSON: false, colorized: false, fullTranscript: false)
    public static let raw = ForensicMode(showRaw: true, showDecoded: false, showJSON: false, colorized: false, fullTranscript: false)
    public static let decoded = ForensicMode(showRaw: false, showDecoded: true, showJSON: false, colorized: false, fullTranscript: false)
    public static let json = ForensicMode(showRaw: false, showDecoded: false, showJSON: true, colorized: false, fullTranscript: false)
    public static let full = ForensicMode(showRaw: true, showDecoded: true, showJSON: false, colorized: false, fullTranscript: true)
}

/// Forensic-grade printer for App Attest artifacts
/// Shows raw bytes + decoded values + encoding info + length
public struct ForensicPrinter {
    private let mode: ForensicMode
    private var indentLevel: Int = 0
    private let indentSize: Int = 2
    
    public init(mode: ForensicMode) {
        self.mode = mode
    }
    
    // MARK: - Formatting Helpers
    
    func indent() -> String {
        return String(repeating: " ", count: indentLevel * indentSize)
    }
    
    private func formatNumber(_ num: UInt32) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
    
    private func formatHex(_ data: Data, lineLength: Int = 0) -> String {
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
    
    private func formatHexOld(_ data: Data, bytesPerGroup: Int = 4) -> String {
        let hexString = data.map { String(format: "%02x", $0) }.joined()
        var formatted = ""
        for (index, char) in hexString.enumerated() {
            if index > 0 && index % (bytesPerGroup * 2) == 0 {
                formatted += " "
            }
            formatted.append(char)
        }
        return formatted
    }
    
    private func formatBase64(_ data: Data) -> String {
        return data.base64EncodedString()
    }
    
    // MARK: - Field Printing
    
    /// Print a field with raw + decoded values
    public mutating func printField(name: String, raw: Data?, decoded: String?, encoding: String? = nil, opaque: Bool = false) -> String {
        var output = ""
        let indentStr = indent()
        let nameFormatted = mode.colorized ? "\(ANSIColor.fieldName)`\(name)`\(ANSIColor.reset)" : "`\(name)`"
        
        if opaque {
            let opaqueLabel = mode.colorized ? "\(ANSIColor.warning)[OPAQUE]\(ANSIColor.reset)" : "[OPAQUE]"
            output += "\(indentStr)\(nameFormatted): \(opaqueLabel) "
        } else {
            output += "\(indentStr)\(nameFormatted): "
        }
        
        if let raw = raw {
            if mode.showRaw {
                output += "\(formatHex(raw)) (\(raw.count) bytes)"
                if let encoding = encoding {
                    output += " [\(encoding)]"
                }
                if mode.showDecoded, let decoded = decoded {
                    output += "\n\(indentStr)  decoded: \(decoded)"
                }
            } else if mode.showDecoded, let decoded = decoded {
                output += decoded
            }
        } else if let decoded = decoded {
            output += decoded
        }
        
        output += "\n"
        return output
    }
    
    /// Print a container (opens a new indented block)
    public mutating func printContainer(name: String) -> String {
        let indentStr = indent()
        let nameFormatted = mode.colorized ? "\(ANSIColor.fieldName)`\(name)`\(ANSIColor.reset)" : "`\(name)`"
        let brace = mode.colorized ? "\(ANSIColor.separator){\(ANSIColor.reset)" : "{"
        indentLevel += 1
        return "\(indentStr)\(nameFormatted): \(brace)\n"
    }
    
    /// Close a container
    public mutating func closeContainer() -> String {
        indentLevel -= 1
        let indentStr = indent()
        let brace = mode.colorized ? "\(ANSIColor.separator)}\(ANSIColor.reset)" : "}"
        return "\(indentStr)\(brace)\n"
    }
    
    /// Print raw data block (hex + base64)
    public func printRawData(name: String, data: Data) -> String {
        var output = ""
        let indentStr = indent()
        let nameFormatted = mode.colorized ? "\(ANSIColor.fieldName)`\(name)`\(ANSIColor.reset)" : "`\(name)`"
        
        output += "\(indentStr)\(nameFormatted):\n"
        output += "\(indentStr)  length: \(data.count) bytes\n"
        output += "\(indentStr)  hex: \(formatHex(data))\n"
        output += "\(indentStr)  base64: \(formatBase64(data))\n"
        
        return output
    }
    
    // MARK: - ANSI Colors
    
    enum ANSIColor {
        static let reset = "\u{001B}[0m"
        static let header = "\u{001B}[1;36m"
        static let fieldName = "\u{001B}[36m"  // Cyan
        static let separator = "\u{001B}[90m"  // Gray
        static let warning = "\u{001B}[33m"    // Yellow
        static let hex = "\u{001B}[35m"        // Magenta
        static let string = "\u{001B}[32m"     // Green
        static let number = "\u{001B}[33m"     // Yellow
    }
}

// MARK: - Forensic Attestation Printer

extension AttestationObject {
    /// Forensic-grade print showing raw + decoded for everything
    public func forensicPrint(mode: ForensicMode) -> String {
        // JSON output mode
        if mode.showJSON {
            let json = ForensicJSONEncoder.encode(self)
            if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return "Error: Failed to serialize JSON"
            }
        }
        
        // Full transcript mode (linear narrative)
        if mode.fullTranscript {
            return forensicPrintTranscript(colorized: mode.colorized)
        }
        
        // Human-readable output (tree structure)
        var printer = ForensicPrinter(mode: mode)
        var output = ""
        
        // Header
        let header = mode.colorized ?
            "\(ForensicPrinter.ANSIColor.header)Attestation Object (Forensic View)\(ForensicPrinter.ANSIColor.reset)\n\(ForensicPrinter.ANSIColor.separator)========================================\(ForensicPrinter.ANSIColor.reset)\n\n" :
            "Attestation Object (Forensic View)\n========================================\n\n"
        output += header
        
        // Raw CBOR
        if let rawData = rawData {
            output += printer.printRawData(name: "rawCBOR", data: rawData)
            output += "\n"
        }
        
        // Format
        output += printer.printField(name: "format", raw: nil, decoded: format)
        
        // Authenticator Data
        output += printer.printContainer(name: "authenticatorData")
        output += forensicPrintAuthenticatorData(authenticatorData, printer: &printer)
        output += printer.closeContainer()
        
        // Attestation Statement
        output += printer.printContainer(name: "attestationStatement")
        output += forensicPrintAttStmt(attestationStatement, printer: &printer)
        output += printer.closeContainer()
        
        return output
    }
    
    /// Full transcript mode: linear narrative format
    private func forensicPrintTranscript(colorized: Bool, showRaw: Bool = false) -> String {
        var transcript = ForensicTranscriptPrinter(colorized: colorized, showRaw: showRaw)
        var output = ""
        
        // 1. Prominent Header
        output += transcript.summaryHeader("APPLE APP ATTEST — FORENSIC REPORT")
        
        // Summary (two-column format)
        var summaryContent = ""
        
        // Format
        summaryContent += transcript.twoColumnField(key: "FORMAT", value: format)
        
        // Certificate chain
        let chainLength = attestationStatement.x5c.count
        var chainStructure = ""
        if chainLength > 0 {
            if chainLength == 1 {
                chainStructure = "root"
            } else if chainLength == 2 {
                chainStructure = "leaf → root"
            } else {
                chainStructure = "leaf → \(chainLength - 2) intermediate(s) → root"
            }
        }
        summaryContent += transcript.twoColumnField(key: "CERTIFICATE CHAIN", value: "\(chainLength) certs (\(chainStructure))")
        
        // Receipt
        let receiptPresent = (attestationStatement.rawCBOR.mapValue?.first(where: { key, _ in
            if case .textString("receipt") = key { return true }
            return false
        }) != nil)
        summaryContent += transcript.twoColumnField(key: "RECEIPT PRESENT", value: receiptPresent ? "yes" : "no")
        
        // Attested credential
        summaryContent += transcript.twoColumnField(key: "ATTESTED CREDENTIAL", value: authenticatorData.attestedCredentialData != nil ? "present" : "absent")
        
        // Environment (if decodable)
        var environment: String? = nil
        var decodedExtCount = 0
        var opaqueExtCount = 0
        if let leafCertDER = attestationStatement.x5c.first,
           let leafCert = try? X509Certificate.parse(der: leafCertDER) {
            for (_, ext) in leafCert.decodedExtensions {
                switch ext {
                case .appleOID(_, let appleExt):
                    if case .environment(let env) = appleExt.type {
                        environment = env
                    }
                    decodedExtCount += 1
                case .basicConstraints, .keyUsage, .extendedKeyUsage, .subjectKeyIdentifier, .authorityKeyIdentifier, .subjectAlternativeName:
                    decodedExtCount += 1
                case .unknown:
                    opaqueExtCount += 1
                }
            }
        }
        if let env = environment {
            summaryContent += transcript.twoColumnField(key: "ENVIRONMENT", value: "\(env) (from extension)")
        } else {
            summaryContent += transcript.twoColumnField(key: "ENVIRONMENT", value: "not decodable (see extensions)")
        }
        
        // Extensions summary
        let totalExtCount = decodedExtCount + opaqueExtCount
        if totalExtCount > 0 {
            summaryContent += transcript.twoColumnField(key: "EXTENSIONS", value: "\(totalExtCount) total (\(decodedExtCount) decoded, \(opaqueExtCount) opaque)")
        }
        
        output += transcript.boxedSection("SUMMARY", content: summaryContent)
        
        // 2. DECODED SECTIONS (Summary → Decoded → Raw hierarchy)
        
        // Authenticator Data (boxed section)
        var authDataContent = ""
        
        // RP ID Hash: SHA-256 with hex, base64, and explanation
        let rpIdHashHex = authenticatorData.rpIdHash.map { String(format: "%02x", $0) }.joined()
        let rpIdHashBase64 = authenticatorData.rpIdHash.base64EncodedString()
        authDataContent += transcript.twoColumnField(key: "RP ID HASH", value: "SHA-256(bundle identifier)")
        authDataContent += transcript.twoColumnField(key: "  Algorithm", value: "SHA-256 (RFC 6234)")
        authDataContent += transcript.twoColumnField(key: "  Hex", value: rpIdHashHex)
        authDataContent += transcript.twoColumnField(key: "  Base64", value: rpIdHashBase64)
        
        // Flags: detailed bitmask breakdown
        let flagsRaw = authenticatorData.flags.rawValue
        var flagsBits: [String] = []
        if flagsRaw & 0x01 != 0 { flagsBits.append("UP (User Present, bit 0)") }
        if flagsRaw & 0x04 != 0 { flagsBits.append("UV (User Verified, bit 2)") }
        if flagsRaw & 0x40 != 0 { flagsBits.append("AT (Attested Credential Data, bit 6)") }
        if flagsRaw & 0x80 != 0 { flagsBits.append("ED (Extensions Included, bit 7)") }
        let flagsDesc = flagsBits.isEmpty ? "none set" : flagsBits.joined(separator: ", ")
        // Format binary correctly: 8 bits, left-padded with zeros
        let binaryStr = String(flagsRaw, radix: 2)
        let paddedBinary = String(repeating: "0", count: max(0, 8 - binaryStr.count)) + binaryStr
        authDataContent += transcript.twoColumnField(key: "FLAGS", value: "0x\(String(format: "%02x", flagsRaw)) (0b\(paddedBinary))")
        authDataContent += transcript.twoColumnField(key: "  Bitmask", value: flagsDesc)
        authDataContent += transcript.twoColumnField(key: "  USER PRESENT", value: "\(authenticatorData.flags.userPresent) (bit 0, WebAuthn §6.1)")
        authDataContent += transcript.twoColumnField(key: "  USER VERIFIED", value: "\(authenticatorData.flags.userVerified) (bit 2, WebAuthn §6.1)")
        authDataContent += transcript.twoColumnField(key: "  ATTESTED CRED", value: "\(authenticatorData.flags.attestedCredentialData) (bit 6, WebAuthn §6.1)")
        authDataContent += transcript.twoColumnField(key: "  EXTENSIONS", value: "\(authenticatorData.flags.extensionsIncluded) (bit 7, WebAuthn §6.1)")
        
        // Sign Count: replay protection explanation
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let signCountFormatted = formatter.string(from: NSNumber(value: authenticatorData.signCount)) ?? "\(authenticatorData.signCount)"
        let signCountNote = authenticatorData.signCount == 0 
            ? "Initial attestation (counter starts at 0)" 
            : "Replay protection counter (must increment on each use)"
        authDataContent += transcript.twoColumnField(key: "SIGN COUNT", value: "\(signCountFormatted)")
        authDataContent += transcript.twoColumnField(key: "  Purpose", value: signCountNote)
        authDataContent += transcript.twoColumnField(key: "  Spec", value: "WebAuthn §6.1 (monotonic counter)")
        
        output += transcript.boxedSection("AUTHENTICATOR DATA", content: authDataContent)
        
        // Attested Credential Data
        if let credData = authenticatorData.attestedCredentialData {
            var credDataContent = ""
            
            // AAGUID: UUID format + raw bytes
            let aaguidHex = credData.aaguid.map { String(format: "%02x", $0) }.joined()
            let aaguidBase64 = credData.aaguid.base64EncodedString()
            // Format as UUID if 16 bytes
            var aaguidDisplay = "[\(credData.aaguid.count) bytes]"
            if credData.aaguid.count == 16 {
                let uuidString = credData.aaguid.withUnsafeBytes { bytes in
                    let uuid = NSUUID(uuidBytes: bytes.bindMemory(to: UInt8.self).baseAddress!)
                    return uuid.uuidString
                }
                aaguidDisplay = "\(uuidString) (UUID format)"
            }
            credDataContent += transcript.twoColumnField(key: "AAGUID", value: aaguidDisplay)
            credDataContent += transcript.twoColumnField(key: "  Hex", value: aaguidHex)
            credDataContent += transcript.twoColumnField(key: "  Base64", value: aaguidBase64)
            credDataContent += transcript.twoColumnField(key: "  Purpose", value: "Authenticator Attestation Globally Unique ID (WebAuthn §6.4.1)")
            
            // Credential ID: length + format
            let credIdHex = credData.credentialId.map { String(format: "%02x", $0) }.joined()
            let credIdBase64 = credData.credentialId.base64EncodedString()
            credDataContent += transcript.twoColumnField(key: "CREDENTIAL ID", value: "\(credData.credentialId.count) bytes")
            credDataContent += transcript.twoColumnField(key: "  Hex", value: credIdHex)
            credDataContent += transcript.twoColumnField(key: "  Base64", value: credIdBase64)
            credDataContent += transcript.twoColumnField(key: "  Purpose", value: "Unique identifier for this credential (WebAuthn §6.4.1)")
            
            // Credential Public Key (COSE Key - fully decoded)
            credDataContent += "\n"
            credDataContent += transcript.twoColumnField(key: "CREDENTIAL PUBLIC KEY", value: "COSE_Key structure (RFC 8152)")
            
            if case .map(let pairs) = credData.credentialPublicKey {
                // Decode COSE key map to named fields
                var kty: String? = nil
                var alg: String? = nil
                var crv: String? = nil
                var x: Data? = nil
                var y: Data? = nil
                
                for (key, value) in pairs {
                    if case .unsigned(1) = key, case .unsigned(let ktyVal) = value {
                        kty = ktyVal == 2 ? "EC (2)" : "\(ktyVal)"
                    } else if case .negative(-1) = key, case .unsigned(1) = value {
                        crv = "P-256 (1)"
                    } else if case .negative(-2) = key, case .byteString(let xData) = value {
                        x = xData
                    } else if case .negative(-3) = key, case .byteString(let yData) = value {
                        y = yData
                    } else if case .negative(-7) = key {
                        alg = "ES256 (-7)"
                    } else if case .unsigned(3) = key, case .negative(-7) = value {
                        alg = "ES256 (-7)"
                    }
                }
                
                credDataContent += transcript.twoColumnField(key: "  kty", value: kty ?? "unknown (key type, COSE §7.1)")
                if let alg = alg {
                    credDataContent += transcript.twoColumnField(key: "  alg", value: "\(alg) (signature algorithm, COSE §7.1)")
                }
                if let crv = crv {
                    credDataContent += transcript.twoColumnField(key: "  crv", value: "\(crv) (elliptic curve, COSE §7.1)")
                }
                if let x = x {
                    let xHex = x.map { String(format: "%02x", $0) }.joined()
                    credDataContent += transcript.twoColumnField(key: "  x", value: "[\(x.count) bytes] 🔒 (EC x-coordinate)")
                    credDataContent += transcript.twoColumnField(key: "    Hex", value: xHex)
                }
                if let y = y {
                    let yHex = y.map { String(format: "%02x", $0) }.joined()
                    credDataContent += transcript.twoColumnField(key: "  y", value: "[\(y.count) bytes] 🔒 (EC y-coordinate)")
                    credDataContent += transcript.twoColumnField(key: "    Hex", value: yHex)
                }
                
                // Explanation block
                credDataContent += "\n"
                credDataContent += transcript.twoColumnField(key: "  Note", value: "Device-generated ECDSA P-256 public key bound to attestation")
            }
            
            output += transcript.boxedSection("ATTESTED CREDENTIAL DATA", content: credDataContent)
            
            // Raw bytes collected for end (if showRaw)
            transcript.addRawDataBlock(title: "AAGUID", data: credData.aaguid, encoding: "UUID")
            transcript.addRawDataBlock(title: "CREDENTIAL ID", data: credData.credentialId, encoding: "byte string")
        }
        
        // Extensions
        if authenticatorData.extensions != nil {
            let extContent = transcript.twoColumnField(key: "EXTENSIONS", value: "present (CBOR-encoded)")
            output += transcript.boxedSection("EXTENSIONS", content: extContent)
        }
        
        // Attestation Statement
        var attStmtContent = ""
        
        // Algorithm - explicit explanation
        if let alg = attestationStatement.alg {
            attStmtContent += transcript.twoColumnField(key: "ALGORITHM", value: "\(alg) (ES256, COSE alg -7)")
            attStmtContent += transcript.twoColumnField(key: "  Note", value: "Explicitly specified in attStmt map")
        } else {
            attStmtContent += transcript.twoColumnField(key: "ALGORITHM", value: "◻ Implicit (not present in attStmt)")
            attStmtContent += transcript.twoColumnField(key: "  Reason", value: "Apple App Attest uses certificate-based attestation")
            attStmtContent += transcript.twoColumnField(key: "  Implied", value: "ES256 (from certificate signature algorithm)")
        }
        
        // Signature - explicit explanation
        if !attestationStatement.signature.isEmpty {
            attStmtContent += transcript.twoColumnField(key: "SIGNATURE", value: "🔒 Present (\(attestationStatement.signature.count) bytes)")
            attStmtContent += transcript.twoColumnField(key: "  Type", value: "ECDSA signature (cryptographic, not interpreted)")
            attStmtContent += transcript.twoColumnField(key: "  Location", value: "attStmt map 'sig' field")
            attStmtContent += transcript.twoColumnField(key: "  Purpose", value: "Signature over authenticatorData || clientDataHash")
            attStmtContent += transcript.twoColumnField(key: "  Verification", value: "Requires validated certificate chain (not performed)")
            attStmtContent += transcript.twoColumnField(key: "  Spec", value: "WebAuthn §8.2 (Apple App Attest format)")
        } else {
            attStmtContent += transcript.twoColumnField(key: "SIGNATURE", value: "◻ Not present (by design)")
            attStmtContent += transcript.twoColumnField(key: "  Reason", value: "Apple App Attest relies on X.509 certificate chain")
            attStmtContent += transcript.twoColumnField(key: "  Trust Model", value: "Certificate trust, not COSE signature")
            attStmtContent += transcript.twoColumnField(key: "  Spec", value: "WebAuthn §8.2 (Apple App Attest format)")
        }
        
        // Raw attStmt CBOR explanation
        attStmtContent += "\n"
        attStmtContent += transcript.twoColumnField(key: "ATTESTATION FORMAT", value: "apple-appattest")
        attStmtContent += transcript.twoColumnField(key: "  Trust Mechanism", value: "X.509 certificate chain validation")
        attStmtContent += transcript.twoColumnField(key: "  Signature Method", value: "Certificate-based (not COSE sig)")
        
        output += transcript.boxedSection("ATTESTATION STATEMENT", content: attStmtContent)
        
        // Raw bytes collected for end (if showRaw)
        if !attestationStatement.signature.isEmpty {
            transcript.addRawDataBlock(title: "Signature", data: attestationStatement.signature, encoding: "ECDSA")
        }
        
        // Certificate Chain
        if !attestationStatement.x5c.isEmpty {
            for (index, certDER) in attestationStatement.x5c.enumerated() {
                let role = index == 0 ? "Leaf" : index == attestationStatement.x5c.count - 1 ? "Root" : "Intermediate"
                
                // Parsed certificate
                if let cert = try? X509Certificate.parse(der: certDER) {
                    var certContent = ""
                    
                    // Subject: Full DN with attribute breakdown
                    let subjectDN = X509Helpers.formatDN(cert.subject)
                    certContent += transcript.twoColumnField(key: "SUBJECT", value: subjectDN)
                    let subjectAttrs = X509Helpers.formatDNDetailed(cert.subject)
                    for attr in subjectAttrs {
                        certContent += transcript.twoColumnField(key: "  \(attr.name)", value: attr.value)
                    }
                    
                    // Issuer: Full DN with attribute breakdown
                    let issuerDN = X509Helpers.formatDN(cert.issuer)
                    certContent += transcript.twoColumnField(key: "ISSUER", value: issuerDN)
                    let issuerAttrs = X509Helpers.formatDNDetailed(cert.issuer)
                    for attr in issuerAttrs {
                        certContent += transcript.twoColumnField(key: "  \(attr.name)", value: attr.value)
                    }
                    
                    // Serial Number
                    let serialHex = cert.serialNumber.map { String(format: "%02x", $0) }.joined()
                    certContent += transcript.twoColumnField(key: "SERIAL NUMBER", value: serialHex)
                    
                    // Signature Algorithm
                    let sigAlgName = X509Helpers.signatureAlgorithmName(for: cert.signatureAlgorithmOID)
                    certContent += transcript.twoColumnField(key: "SIGNATURE ALG", value: sigAlgName)
                    certContent += transcript.twoColumnField(key: "  OID", value: cert.signatureAlgorithmOID)
                    
                    // Public Key
                    let pubKeyAlgName = X509Helpers.publicKeyAlgorithmName(for: cert.subjectPublicKeyAlgorithmOID)
                    let pubKeyDetails = X509Helpers.publicKeyDetails(algorithmOID: cert.subjectPublicKeyAlgorithmOID, keyBits: cert.subjectPublicKeyBits)
                    certContent += transcript.twoColumnField(key: "PUBLIC KEY", value: pubKeyDetails.type)
                    if let curve = pubKeyDetails.curve {
                        certContent += transcript.twoColumnField(key: "  Curve", value: curve)
                    }
                    if let keySize = pubKeyDetails.keySize {
                        certContent += transcript.twoColumnField(key: "  Key Size", value: "\(keySize) bits")
                    }
                    certContent += transcript.twoColumnField(key: "  Algorithm", value: pubKeyAlgName)
                    if let keyBits = cert.subjectPublicKeyBits {
                        certContent += transcript.twoColumnField(key: "  Raw Length", value: "\(keyBits.count) bytes")
                    }
                    
                    // Validity
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime, .withTimeZone]
                    certContent += transcript.twoColumnField(key: "NOT BEFORE", value: formatter.string(from: cert.validity.notBefore))
                    certContent += transcript.twoColumnField(key: "NOT AFTER", value: formatter.string(from: cert.validity.notAfter))
                    let durationDays = X509Helpers.validityDurationDays(notBefore: cert.validity.notBefore, notAfter: cert.validity.notAfter)
                    certContent += transcript.twoColumnField(key: "VALIDITY DURATION", value: "\(durationDays) days")
                    
                    // Extensions (Decoded) - with visual indicators
                    let decodedExts = cert.decodedExtensions
                    if !decodedExts.isEmpty {
                        certContent += "\n"
                        for (oid, ext) in decodedExts.sorted(by: { $0.key < $1.key }) {
                            let extName = X509OID.name(for: oid)
                            let symbol: String
                            switch ext {
                            case .appleOID, .basicConstraints, .keyUsage, .extendedKeyUsage, .subjectKeyIdentifier, .authorityKeyIdentifier, .subjectAlternativeName:
                                symbol = ForensicTranscriptPrinter.StatusSymbol.decoded
                            case .unknown:
                                symbol = ForensicTranscriptPrinter.StatusSymbol.opaque
                            }
                            
                            certContent += "\(symbol) \(extName):\n"
                            
                            switch ext {
                            case .basicConstraints(let isCA, let pathLength):
                                certContent += transcript.bulletPoint("isCA: \(isCA)", indent: 2)
                                if let pathLength = pathLength {
                                    certContent += transcript.bulletPoint("pathLengthConstraint: \(pathLength)", indent: 2)
                                }
                                certContent += transcript.bulletPoint("Purpose: CA certificate constraint (RFC 5280 §4.2.1.9)", indent: 2)
                            case .keyUsage(let usages):
                                for usage in usages {
                                    certContent += transcript.bulletPoint(usage.name, indent: 2)
                                }
                                certContent += transcript.bulletPoint("Purpose: Key usage constraints (RFC 5280 §4.2.1.3)", indent: 2)
                            case .extendedKeyUsage(let usages):
                                for usage in usages {
                                    certContent += transcript.bulletPoint(usage.name, indent: 2)
                                }
                                certContent += transcript.bulletPoint("Purpose: Extended key usage OIDs (RFC 5280 §4.2.1.12)", indent: 2)
                            case .subjectKeyIdentifier(let keyId):
                                let keyIdHex = keyId.map { String(format: "%02x", $0) }.joined()
                                certContent += transcript.bulletPoint("Key ID: \(keyIdHex)", indent: 2)
                                certContent += transcript.bulletPoint("Purpose: Subject public key identifier (RFC 5280 §4.2.1.2)", indent: 2)
                            case .authorityKeyIdentifier(let keyId, let issuer, let serial):
                                if let keyId = keyId {
                                    let keyIdHex = keyId.map { String(format: "%02x", $0) }.joined()
                                    certContent += transcript.bulletPoint("Key ID: \(keyIdHex)", indent: 2)
                                }
                                if let issuer = issuer {
                                    certContent += transcript.bulletPoint("Issuer: \(issuer)", indent: 2)
                                }
                                if let serial = serial {
                                    let serialHex = serial.map { String(format: "%02x", $0) }.joined()
                                    certContent += transcript.bulletPoint("Serial: \(serialHex)", indent: 2)
                                }
                                certContent += transcript.bulletPoint("Purpose: Authority key identifier (RFC 5280 §4.2.1.1)", indent: 2)
                            case .subjectAlternativeName(let names):
                                for name in names {
                                    certContent += transcript.bulletPoint("\(name.description)", indent: 2)
                                }
                                certContent += transcript.bulletPoint("Purpose: Subject alternative names (RFC 5280 §4.2.1.6)", indent: 2)
                            case .appleOID(_, let appleExt):
                                certContent += transcriptPrintAppleExtension(appleExt, transcript: &transcript, indent: 2)
                            case .unknown(let unknownOID, let raw):
                                certContent += transcript.bulletPoint("OID: \(unknownOID)", indent: 2)
                                certContent += transcript.bulletPoint("Raw DER: \(raw.count) bytes", indent: 2)
                                certContent += transcript.bulletPoint("Reason: Unknown extension (not in RFC 5280 or Apple spec)", indent: 2)
                                certContent += transcript.bulletPoint("Raw data preserved for audit", indent: 2)
                            }
                        }
                    }
                    
                    output += transcript.boxedSection("CERTIFICATE [\(index)] — \(role)", content: certContent)
                    
                    // Raw DER collected for end (if showRaw)
                    transcript.addRawDataBlock(title: "Certificate[\(index)] DER", data: certDER, encoding: "DER")
                } else {
                    output += transcript.boxedSection("CERTIFICATE [\(index)] — \(role)", content: "Parse Error: Failed to parse certificate")
                }
            }
        }
        
        // Receipt (if present in rawCBOR)
        if case .map(let mapPairs) = attestationStatement.rawCBOR,
           let receiptValue = mapPairs.first(where: { key, _ in
               if case .textString("receipt") = key { return true }
               return false
           })?.1,
           case .byteString(let receiptData) = receiptValue {
            var receiptContent = ""
            
            // Try to parse as CMS SignedData
            if let cms = try? CMSSignedData.parse(der: receiptData) {
                receiptContent += transcript.twoColumnField(key: "CONTAINER TYPE", value: "CMS SignedData (PKCS#7, RFC 5652)")
                receiptContent += transcript.twoColumnField(key: "VERSION", value: "\(cms.version)")
                
                // Digest Algorithms
                let digestAlgNames = cms.digestAlgorithms.map { $0.name }.joined(separator: ", ")
                receiptContent += transcript.twoColumnField(key: "DIGEST ALGORITHMS", value: digestAlgNames)
                
                // Encapsulated Content Info
                receiptContent += transcript.twoColumnField(key: "CONTENT TYPE", value: "\(cms.encapContentInfo.contentTypeName) (\(cms.encapContentInfo.contentType))")
                receiptContent += transcript.twoColumnField(key: "PAYLOAD SIZE", value: "\(cms.encapContentInfo.content.count) bytes")
                
                // Certificates
                if !cms.certificates.isEmpty {
                    receiptContent += transcript.twoColumnField(key: "CERTIFICATES", value: "\(cms.certificates.count) certificate(s)")
                    for (idx, certDER) in cms.certificates.enumerated() {
                        if let cert = try? X509Certificate.parse(der: certDER) {
                            let subjectDN = X509Helpers.formatDN(cert.subject)
                            receiptContent += transcript.twoColumnField(key: "  Cert[\(idx)]", value: subjectDN)
                        }
                    }
                }
                
                // Signer Infos
                if !cms.signerInfos.isEmpty {
                    receiptContent += transcript.twoColumnField(key: "SIGNERS", value: "\(cms.signerInfos.count) signer(s)")
                    for (idx, signer) in cms.signerInfos.enumerated() {
                        receiptContent += transcript.twoColumnField(key: "  Signer[\(idx)]", value: "Version \(signer.version)")
                        receiptContent += transcript.twoColumnField(key: "    Digest Alg", value: signer.digestAlgorithm.name)
                        receiptContent += transcript.twoColumnField(key: "    Signature Alg", value: signer.signatureAlgorithmName)
                        receiptContent += transcript.twoColumnField(key: "    Signature", value: "🔒 \(signer.signature.count) bytes (not verified)")
                        
                        switch signer.sid.type {
                        case .issuerAndSerialNumber(let issuer, let serial):
                            let issuerDN = X509Helpers.formatDN(issuer)
                            let serialHex = serial.map { String(format: "%02x", $0) }.joined()
                            receiptContent += transcript.twoColumnField(key: "    Issuer", value: issuerDN)
                            receiptContent += transcript.twoColumnField(key: "    Serial", value: serialHex)
                        case .subjectKeyIdentifier(let keyId):
                            let keyIdHex = keyId.map { String(format: "%02x", $0) }.joined()
                            receiptContent += transcript.twoColumnField(key: "    Key ID", value: keyIdHex)
                        }
                        
                        if let signedAttrs = signer.signedAttrs {
                            receiptContent += transcript.twoColumnField(key: "    Signed Attrs", value: "\(signedAttrs.count) bytes")
                        }
                    }
                }
                
                // Payload structure analysis
                receiptContent += "\n"
                receiptContent += transcript.twoColumnField(key: "PAYLOAD ANALYSIS", value: "Attempting structure decode...")
                
                // Try to decode payload as ASN.1, CBOR, or plist
                let payload = cms.encapContentInfo.content
                if !payload.isEmpty {
                    // Try ASN.1
                    var asn1Reader = ASN1Reader(payload)
                    if let _ = try? asn1Reader.readTLV() {
                        receiptContent += transcript.twoColumnField(key: "  Structure", value: "ASN.1 DER (nested structure)")
                    }
                    // Try CBOR
                    else if let _ = try? CBORDecoder.decode(payload) {
                        receiptContent += transcript.twoColumnField(key: "  Structure", value: "CBOR (nested structure)")
                    }
                    // Try plist
                    else if let _ = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) {
                        receiptContent += transcript.twoColumnField(key: "  Structure", value: "Property List (plist)")
                    }
                    else {
                        receiptContent += transcript.twoColumnField(key: "  Structure", value: "◻ Opaque (unknown format)")
                    }
                    
                    receiptContent += transcript.twoColumnField(key: "  Note", value: "Apple-signed evidence blob, signature not verified here")
                }
            } else {
                // Not CMS or parse failed - try other formats
                receiptContent += transcript.twoColumnField(key: "CONTAINER TYPE", value: "◻ Unknown (not CMS SignedData)")
                receiptContent += transcript.twoColumnField(key: "RAW SIZE", value: "\(receiptData.count) bytes")
                
                // Try to detect structure
                receiptContent += "\n"
                receiptContent += transcript.twoColumnField(key: "STRUCTURE DETECTION", value: "Attempting format identification...")
                
                // Try ASN.1
                var asn1Reader = ASN1Reader(receiptData)
                if let tlv = try? asn1Reader.readTLV() {
                    let tagName: String
                    switch tlv.tag {
                    case .sequence: tagName = "SEQUENCE"
                    case .octetString: tagName = "OCTET STRING"
                    case .set: tagName = "SET"
                    default: tagName = "Tag 0x\(String(format: "%02X", tlv.tag.raw))"
                    }
                    receiptContent += transcript.twoColumnField(key: "  Detected", value: "ASN.1 DER (\(tagName), \(tlv.length) bytes)")
                    
                    // If it's an OCTET STRING, try to peek inside
                    if tlv.tag == .octetString && tlv.length > 0 {
                        let innerData = receiptData.subdata(in: tlv.valueRange)
                        var innerReader = ASN1Reader(innerData)
                        if let innerTLV = try? innerReader.readTLV() {
                            let innerTagName: String
                            switch innerTLV.tag {
                            case .sequence: innerTagName = "SEQUENCE"
                            default: innerTagName = "Tag 0x\(String(format: "%02X", innerTLV.tag.raw))"
                            }
                            receiptContent += transcript.twoColumnField(key: "  Inner", value: "\(innerTagName) (\(innerTLV.length) bytes)")
                        } else if let _ = try? CBORDecoder.decode(innerData) {
                            receiptContent += transcript.twoColumnField(key: "  Inner", value: "CBOR structure")
                        }
                    }
                }
                // Try CBOR
                else if let _ = try? CBORDecoder.decode(receiptData) {
                    receiptContent += transcript.twoColumnField(key: "  Detected", value: "CBOR (direct encoding)")
                }
                // Try Property List
                else if let _ = try? PropertyListSerialization.propertyList(from: receiptData, options: [], format: nil) {
                    receiptContent += transcript.twoColumnField(key: "  Detected", value: "Property List (binary/XML plist)")
                }
                // Try UTF-8 string
                else if let str = String(data: receiptData, encoding: .utf8), str.count < 200 {
                    receiptContent += transcript.twoColumnField(key: "  Detected", value: "UTF-8 String (preview: \(String(str.prefix(50))))")
                }
                else {
                    receiptContent += transcript.twoColumnField(key: "  Detected", value: "◻ Opaque (no recognizable structure)")
                }
                
                receiptContent += transcript.twoColumnField(key: "NOTE", value: "Receipt present but structure not decodable as CMS/PKCS#7")
            }
            
            output += transcript.boxedSection("RECEIPT", content: receiptContent)
            
            // Raw bytes collected for end (if showRaw)
            transcript.addRawDataBlock(title: "Receipt", data: receiptData, encoding: "DER/CMS")
            
            // If CMS parsed, also collect payload separately
            if let cms = try? CMSSignedData.parse(der: receiptData), !cms.encapContentInfo.content.isEmpty {
                transcript.addRawDataBlock(title: "Receipt Payload", data: cms.encapContentInfo.content, encoding: "OCTET STRING")
            }
        }
        
        // 3. RAW BYTES (only if showRaw=true, at the very end)
        if let rawData = rawData {
            transcript.addRawDataBlock(title: "CBOR RAW PAYLOAD", data: rawData, encoding: "CBOR")
        }
        
        // Add all collected raw data blocks
        output += transcript.renderRawDataSection()
        
        return output
    }
    
    private func transcriptPrintCBORValue(_ value: CBORValue, transcript: inout ForensicTranscriptPrinter, indent: Int) -> String {
        var output = ""
        
        switch value {
        case .unsigned(let u):
            output += transcript.field(name: "type", value: "unsigned", indent: indent)
            output += transcript.field(name: "value", value: "\(u)", indent: indent)
        case .negative(let n):
            output += transcript.field(name: "type", value: "negative", indent: indent)
            output += transcript.field(name: "value", value: "\(n)", indent: indent)
        case .byteString(let data):
            output += transcript.field(name: "type", value: "byteString", indent: indent)
            if data.count > 0 {
                output += transcript.rawDataBlock(title: "value", data: data, encoding: "byte string")
            } else {
                output += transcript.field(name: "value", value: "empty", indent: indent)
            }
        case .textString(let s):
            output += transcript.field(name: "type", value: "textString", indent: indent)
            output += transcript.field(name: "value", value: "\"\(s)\"", indent: indent)
        case .array(let arr):
            output += transcript.field(name: "type", value: "array", indent: indent)
            output += transcript.field(name: "length", value: "\(arr.count)", indent: indent)
            for (index, elem) in arr.enumerated() {
                output += transcript.field(name: "[\(index)]", value: "", indent: indent)
                output += transcriptPrintCBORValue(elem, transcript: &transcript, indent: indent + 2)
            }
        case .map(let pairs):
            output += transcript.field(name: "type", value: "map", indent: indent)
            output += transcript.field(name: "length", value: "\(pairs.count)", indent: indent)
            for (key, val) in pairs {
                let keyStr = keyDescription(key)
                output += transcript.field(name: keyStr, value: "", indent: indent)
                output += transcriptPrintCBORValue(val, transcript: &transcript, indent: indent + 2)
            }
        case .tagged(let tag, let inner):
            output += transcript.field(name: "type", value: "tagged", indent: indent)
            output += transcript.field(name: "tag", value: "\(tag)", indent: indent)
            output += transcript.field(name: "value", value: "", indent: indent)
            output += transcriptPrintCBORValue(inner, transcript: &transcript, indent: indent + 2)
        case .simple(let u):
            output += transcript.field(name: "type", value: "simple", indent: indent)
            output += transcript.field(name: "value", value: "\(u)", indent: indent)
        case .boolean(let b):
            output += transcript.field(name: "type", value: "boolean", indent: indent)
            output += transcript.field(name: "value", value: "\(b)", indent: indent)
        case .null:
            output += transcript.field(name: "type", value: "null", indent: indent)
        case .undefined:
            output += transcript.field(name: "type", value: "undefined", indent: indent)
        }
        
        return output
    }
    
    private func transcriptPrintAppleExtension(_ appleExt: AppleAppAttestExtension, transcript: inout ForensicTranscriptPrinter, indent: Int) -> String {
        var output = ""
        
        // Always show ASN.1 structure first
        output += transcript.bulletPoint("ASN.1 Structure:", indent: indent)
        let structureDesc = describeASN1Structure(data: appleExt.rawValue)
        output += transcript.bulletPoint("  \(structureDesc)", indent: indent + 2)
        
        // Then show decoded semantic content
        output += transcript.bulletPoint("Decoded Content:", indent: indent)
        
        switch appleExt.type {
        case .challenge(let hash):
            output += transcript.bulletPoint("Type: Challenge (Nonce)", indent: indent + 2)
            output += transcript.bulletPoint("Hash Algorithm: SHA-256", indent: indent + 2)
            output += transcript.bulletPoint("Hash Length: \(hash.count) bytes", indent: indent + 2)
            output += transcript.bulletPoint("Hash (hex): \(hash.map { String(format: "%02x", $0) }.joined())", indent: indent + 2)
            output += transcript.bulletPoint("Purpose: SHA256(authenticatorData || clientDataHash) (WebAuthn §6.5.3)", indent: indent + 2)
            transcript.addRawDataBlock(title: "Challenge Hash", data: hash, encoding: "SHA-256")
            
        case .receipt(let receipt):
            output += transcript.bulletPoint("Type: Receipt (CBOR-encoded)", indent: indent + 2)
            // Show CBOR structure
            if case .map(let pairs) = receipt.rawCBOR {
                output += transcript.bulletPoint("CBOR Type: Map (\(pairs.count) entries)", indent: indent + 2)
            } else {
                output += transcript.bulletPoint("CBOR Type: \(describeCBORType(receipt.rawCBOR))", indent: indent + 2)
            }
            
            if let bundleID = receipt.bundleID {
                output += transcript.bulletPoint("Bundle ID: \(bundleID)", indent: indent + 2)
            }
            if let teamID = receipt.teamID {
                output += transcript.bulletPoint("Team ID: \(teamID)", indent: indent + 2)
            }
            if let appVersion = receipt.appVersion {
                output += transcript.bulletPoint("App Version: \(appVersion)", indent: indent + 2)
            }
            if let creationDate = receipt.receiptCreationDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime]
                output += transcript.bulletPoint("Creation Date: \(formatter.string(from: creationDate))", indent: indent + 2)
            }
            if let expirationDate = receipt.receiptExpirationDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime]
                output += transcript.bulletPoint("Expiration Date: \(formatter.string(from: expirationDate))", indent: indent + 2)
            }
            output += transcript.bulletPoint("Purpose: App metadata evidence (Apple proprietary)", indent: indent + 2)
            
        case .keyPurpose(let purpose):
            output += transcript.bulletPoint("Type: Key Purpose", indent: indent + 2)
            output += transcript.bulletPoint("Value: \(purpose)", indent: indent + 2)
            output += transcript.bulletPoint("Purpose: Indicates key usage (e.g., \"app-attest\", \"fraud-receipt-signing\")", indent: indent + 2)
            
        case .environment(let env):
            output += transcript.bulletPoint("Type: Environment", indent: indent + 2)
            output += transcript.bulletPoint("Value: \(env)", indent: indent + 2)
            output += transcript.bulletPoint("Purpose: App Store environment (\"sandbox\" or \"production\")", indent: indent + 2)
            
        case .osVersion(let version):
            output += transcript.bulletPoint("Type: OS Version", indent: indent + 2)
            output += transcript.bulletPoint("Value: \(version)", indent: indent + 2)
            output += transcript.bulletPoint("Purpose: iOS/macOS version string (e.g., \"17.2\", \"26.4\")", indent: indent + 2)
            
        case .deviceClass(let deviceClass):
            output += transcript.bulletPoint("Type: Device Class", indent: indent + 2)
            output += transcript.bulletPoint("Value: \(deviceClass)", indent: indent + 2)
            output += transcript.bulletPoint("Purpose: Device type (e.g., \"iphoneos\", \"ipados\")", indent: indent + 2)
            
        case .unknown(let oid, let raw):
            output += transcript.bulletPoint("Type: Unknown Apple Extension", indent: indent + 2)
            output += transcript.bulletPoint("OID: \(oid)", indent: indent + 2)
            output += transcript.bulletPoint("Raw Length: \(raw.count) bytes", indent: indent + 2)
            output += transcript.bulletPoint("Reason: No public spec available, structure cannot be safely inferred", indent: indent + 2)
            output += transcript.bulletPoint("Raw data preserved for audit", indent: indent + 2)
        }
        
        return output
    }
    
    private func describeASN1Structure(data: Data) -> String {
        guard !data.isEmpty else { return "Empty" }
        
        var reader = ASN1Reader(data)
        do {
            let tlv = try reader.readTLV()
            let tagName: String
            switch tlv.tag {
            case .octetString: tagName = "OCTET STRING"
            case .sequence: tagName = "SEQUENCE"
            case .set: tagName = "SET"
            case .oid: tagName = "OBJECT IDENTIFIER"
            case .utf8String: tagName = "UTF8String"
            case .printableString: tagName = "PrintableString"
            case .ia5String: tagName = "IA5String"
            case .integer: tagName = "INTEGER"
            default:
                tagName = "Tag 0x\(String(format: "%02X", tlv.tag.raw))"
            }
            
            var desc = "\(tagName) (\(tlv.length) bytes)"
            
            // If it's an OCTET STRING, try to peek inside
            if tlv.tag == .octetString && tlv.length > 0 {
                let innerData = data.subdata(in: tlv.valueRange)
                // Try to detect inner structure
                if innerData.count > 0 {
                    var innerReader = ASN1Reader(innerData)
                    if let innerTLV = try? innerReader.readTLV() {
                        let innerTagName: String
                        switch innerTLV.tag {
                        case .sequence: innerTagName = "SEQUENCE"
                        case .set: innerTagName = "SET"
                        case .octetString: innerTagName = "OCTET STRING"
                        default: innerTagName = "Tag 0x\(String(format: "%02X", innerTLV.tag.raw))"
                        }
                        desc += " → contains \(innerTagName) (\(innerTLV.length) bytes)"
                    } else if let _ = try? CBORDecoder.decode(innerData) {
                        desc += " → contains CBOR"
                    } else if let _ = try? PropertyListSerialization.propertyList(from: innerData, options: [], format: nil) {
                        desc += " → contains Property List"
                    }
                }
            }
            
            return desc
        } catch {
            return "Parse Error: \(error)"
        }
    }
    
    private func describeCBORType(_ value: CBORValue) -> String {
        switch value {
        case .unsigned: return "Unsigned Integer"
        case .negative: return "Negative Integer"
        case .byteString: return "Byte String"
        case .textString: return "Text String"
        case .array(let arr): return "Array (\(arr.count) elements)"
        case .map(let pairs): return "Map (\(pairs.count) entries)"
        case .tagged: return "Tagged"
        case .simple: return "Simple Value"
        case .boolean: return "Boolean"
        case .null: return "Null"
        case .undefined: return "Undefined"
        }
    }
    
    private func keyDescription(_ key: CBORValue) -> String {
        switch key {
        case .textString(let s): return "\"\(s)\""
        case .unsigned(let u): return "\(u)"
        case .negative(let n): return "\(n)"
        default: return "\(key)"
        }
    }
    
    private func forensicPrintAuthenticatorData(_ authData: AuthenticatorData, printer: inout ForensicPrinter) -> String {
        var output = ""
        
        // Raw authenticator data
        output += printer.printRawData(name: "raw", data: authData.rawData)
        
        // RP ID Hash
        output += printer.printRawData(name: "rpIdHash", data: authData.rpIdHash)
        
        // Flags
        output += printer.printContainer(name: "flags")
        let flagsRaw = Data([authData.flags.rawValue])
        output += printer.printField(name: "raw", raw: flagsRaw, decoded: "0x\(String(format: "%02x", authData.flags.rawValue)) (\(authData.flags.rawValue))")
        output += printer.printField(name: "userPresent", raw: nil, decoded: "\(authData.flags.userPresent)")
        output += printer.printField(name: "userVerified", raw: nil, decoded: "\(authData.flags.userVerified)")
        output += printer.printField(name: "attestedCredentialData", raw: nil, decoded: "\(authData.flags.attestedCredentialData)")
        output += printer.printField(name: "extensionsIncluded", raw: nil, decoded: "\(authData.flags.extensionsIncluded)")
        output += printer.closeContainer()
        
        // Sign Count
        output += printer.printField(name: "signCount", raw: nil, decoded: "\(authData.signCount)")
        
        // Attested Credential Data
        if let credData = authData.attestedCredentialData {
            output += printer.printContainer(name: "attestedCredentialData")
            output += forensicPrintAttestedCredentialData(credData, printer: &printer)
            output += printer.closeContainer()
        } else {
            output += printer.printField(name: "attestedCredentialData", raw: nil, decoded: "nil")
        }
        
        // Extensions
        if let extensions = authData.extensions {
            output += printer.printContainer(name: "extensions")
            output += forensicPrintCBORValue(extensions, printer: &printer)
            output += printer.closeContainer()
        } else {
            output += printer.printField(name: "extensions", raw: nil, decoded: "nil")
        }
        
        return output
    }
    
    private func forensicPrintAttestedCredentialData(_ credData: AttestedCredentialData, printer: inout ForensicPrinter) -> String {
        var output = ""
        
        // AAGUID
        output += printer.printRawData(name: "aaguid", data: credData.aaguid)
        
        // Credential ID
        output += printer.printRawData(name: "credentialId", data: credData.credentialId)
        
        // Credential Public Key
        output += printer.printContainer(name: "credentialPublicKey")
        output += forensicPrintCBORValue(credData.credentialPublicKey, printer: &printer)
        output += printer.closeContainer()
        
        return output
    }
    
    private func forensicPrintAttStmt(_ attStmt: AttStmt, printer: inout ForensicPrinter) -> String {
        var output = ""
        
        // Raw CBOR structure (decoded)
        // Note: attStmt.rawCBOR is the decoded CBORValue structure
        // To show raw bytes, we'd need to preserve them during attStmt parsing
        output += printer.printContainer(name: "rawCBOR")
        output += forensicPrintCBORValue(attStmt.rawCBOR, printer: &printer)
        output += printer.closeContainer()
        
        // Algorithm
        if let alg = attStmt.alg {
            output += printer.printField(name: "alg", raw: nil, decoded: "\(alg) (ES256)")
        } else {
            output += printer.printField(name: "alg", raw: nil, decoded: "nil")
        }
        
        // Signature (opaque cryptographic value)
        if !attStmt.signature.isEmpty {
            output += printer.printField(
                name: "signature",
                raw: attStmt.signature,
                decoded: nil,
                encoding: "DER-encoded ECDSA",
                opaque: true
            )
        } else {
            output += printer.printField(name: "signature", raw: nil, decoded: "empty")
        }
        
        // Certificate Chain
        output += printer.printContainer(name: "x5c")
        for (index, certDER) in attStmt.x5c.enumerated() {
            output += forensicPrintCertificate(certDER: certDER, index: index, totalCerts: attStmt.x5c.count, printer: &printer)
        }
        output += printer.closeContainer()
        
        return output
    }
    
    private func forensicPrintCertificate(certDER: Data, index: Int, totalCerts: Int, printer: inout ForensicPrinter) -> String {
        var output = ""
        let role = index == 0 ? " (leaf)" : index == totalCerts - 1 ? " (root)" : " (intermediate)"
        
        output += printer.printContainer(name: "[\(index)]\(role)")
        
        // Raw DER
        output += printer.printRawData(name: "rawDER", data: certDER)
        
        // Try to parse
        if let cert = try? X509Certificate.parse(der: certDER) {
            // Subject
            let subjectStr = cert.subject.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.subject.description
            output += printer.printField(name: "subject", raw: nil, decoded: subjectStr)
            
            // Issuer
            let issuerStr = cert.issuer.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.issuer.description
            output += printer.printField(name: "issuer", raw: nil, decoded: issuerStr)
            
            // Serial Number
            output += printer.printField(name: "serialNumber", raw: cert.serialNumber, decoded: nil)
            
            // Validity
            output += printer.printContainer(name: "validity")
            let formatter = ISO8601DateFormatter()
            output += printer.printField(name: "notBefore", raw: nil, decoded: formatter.string(from: cert.validity.notBefore))
            output += printer.printField(name: "notAfter", raw: nil, decoded: formatter.string(from: cert.validity.notAfter))
            output += printer.closeContainer()
            
            // Extensions
            let decodedExts = cert.decodedExtensions
            if !decodedExts.isEmpty {
                output += printer.printContainer(name: "extensions")
                for (oid, ext) in decodedExts.sorted(by: { $0.key < $1.key }) {
                    output += forensicPrintExtension(oid: oid, ext: ext, rawDER: cert.extensions[oid], printer: &printer)
                }
                output += printer.closeContainer()
            }
        } else {
            output += printer.printField(name: "parseError", raw: nil, decoded: "Failed to parse certificate")
        }
        
        output += printer.closeContainer()
        return output
    }
    
    private func forensicPrintExtension(oid: String, ext: X509Extension, rawDER: Data?, printer: inout ForensicPrinter) -> String {
        var output = ""
        let name = X509OID.name(for: oid)
        
        output += printer.printContainer(name: name)
        
        // Raw DER
        if let raw = rawDER {
            output += printer.printRawData(name: "rawDER", data: raw)
        }
        
        // OID
        output += printer.printField(name: "oid", raw: nil, decoded: oid)
        
        // Decoded value
        switch ext {
        case .basicConstraints(let isCA, let pathLength):
            output += printer.printField(name: "isCA", raw: nil, decoded: "\(isCA)")
            if let pathLength = pathLength {
                output += printer.printField(name: "pathLengthConstraint", raw: nil, decoded: "\(pathLength)")
            }
        case .keyUsage(let usages):
            output += printer.printField(name: "usages", raw: nil, decoded: usages.map { $0.name }.joined(separator: ", "))
        case .extendedKeyUsage(let usages):
            output += printer.printField(name: "usages", raw: nil, decoded: usages.map { $0.name }.joined(separator: ", "))
        case .subjectKeyIdentifier(let keyId):
            let keyIdHex = keyId.map { String(format: "%02x", $0) }.joined()
            output += printer.printField(name: "keyIdentifier", raw: keyId, decoded: keyIdHex)
        case .authorityKeyIdentifier(let keyId, let issuer, let serial):
            if let keyId = keyId {
                let keyIdHex = keyId.map { String(format: "%02x", $0) }.joined()
                output += printer.printField(name: "keyIdentifier", raw: keyId, decoded: keyIdHex)
            }
            if let issuer = issuer {
                output += printer.printField(name: "authorityCertIssuer", raw: nil, decoded: issuer)
            }
            if let serial = serial {
                output += printer.printField(name: "authorityCertSerialNumber", raw: serial, decoded: nil)
            }
        case .subjectAlternativeName(let names):
            output += printer.printField(name: "names", raw: nil, decoded: names.map { $0.description }.joined(separator: ", "))
        case .appleOID(_, let appleExt):
            output += forensicPrintAppleExtension(appleExt, printer: &printer)
        case .unknown(_, let raw):
            output += printer.printField(name: "raw", raw: raw, decoded: nil, encoding: "DER", opaque: true)
        }
        
        output += printer.closeContainer()
        return output
    }
    
    private func forensicPrintAppleExtension(_ appleExt: AppleAppAttestExtension, printer: inout ForensicPrinter) -> String {
        var output = ""
        
        // Raw value
        output += printer.printRawData(name: "rawValue", data: appleExt.rawValue)
        
        // Decoded type
        switch appleExt.type {
        case .challenge(let hash):
            output += printer.printField(name: "type", raw: nil, decoded: "challenge")
            output += printer.printField(name: "hash", raw: hash, decoded: nil, encoding: "SHA256")
        case .receipt(let receipt):
            output += printer.printField(name: "type", raw: nil, decoded: "receipt")
            output += printer.printContainer(name: "decoded")
            if let bundleID = receipt.bundleID {
                output += printer.printField(name: "bundleID", raw: nil, decoded: bundleID)
            }
            if let teamID = receipt.teamID {
                output += printer.printField(name: "teamID", raw: nil, decoded: teamID)
            }
            if let appVersion = receipt.appVersion {
                output += printer.printField(name: "appVersion", raw: nil, decoded: appVersion)
            }
            if let creationDate = receipt.receiptCreationDate {
                let formatter = ISO8601DateFormatter()
                output += printer.printField(name: "receiptCreationDate", raw: nil, decoded: formatter.string(from: creationDate))
            }
            if let expirationDate = receipt.receiptExpirationDate {
                let formatter = ISO8601DateFormatter()
                output += printer.printField(name: "receiptExpirationDate", raw: nil, decoded: formatter.string(from: expirationDate))
            }
            // Raw CBOR (receipt.rawCBOR is the decoded CBORValue structure)
            // To show raw bytes, we'd need to preserve them during decoding
            output += printer.printField(name: "rawCBOR", raw: nil, decoded: "CBOR structure (raw bytes preserved in extension rawValue)")
            output += printer.closeContainer()
        case .keyPurpose(let purpose):
            output += printer.printField(name: "type", raw: nil, decoded: "keyPurpose")
            output += printer.printField(name: "purpose", raw: nil, decoded: purpose)
        case .environment(let env):
            output += printer.printField(name: "type", raw: nil, decoded: "environment")
            output += printer.printField(name: "value", raw: nil, decoded: env)
        case .osVersion(let version):
            output += printer.printField(name: "type", raw: nil, decoded: "osVersion")
            output += printer.printField(name: "value", raw: nil, decoded: version)
        case .deviceClass(let deviceClass):
            output += printer.printField(name: "type", raw: nil, decoded: "deviceClass")
            output += printer.printField(name: "value", raw: nil, decoded: deviceClass)
        case .unknown(_, let raw):
            output += printer.printField(name: "type", raw: nil, decoded: "unknown")
            output += printer.printField(name: "raw", raw: raw, decoded: nil, encoding: "DER", opaque: true)
        }
        
        return output
    }
    
    private func forensicPrintCBORValue(_ value: CBORValue, printer: inout ForensicPrinter) -> String {
        var output = ""
        
        // Note: Raw CBOR bytes are not preserved in CBORValue structure
        // They would need to be captured during decoding
        // For now, show decoded structure
        output += printer.printContainer(name: "decoded")
        output += printCBORValueStructure(value, printer: &printer)
        output += printer.closeContainer()
        
        return output
    }
    
    private func printCBORValueStructure(_ value: CBORValue, printer: inout ForensicPrinter) -> String {
        var output = ""
        
        switch value {
        case .unsigned(let u):
            output += printer.printField(name: "type", raw: nil, decoded: "unsigned")
            output += printer.printField(name: "value", raw: nil, decoded: "\(u)")
        case .negative(let n):
            output += printer.printField(name: "type", raw: nil, decoded: "negative")
            output += printer.printField(name: "value", raw: nil, decoded: "\(n)")
        case .byteString(let data):
            output += printer.printField(name: "type", raw: nil, decoded: "byteString")
            if data.count > 0 {
                output += printer.printRawData(name: "value", data: data)
            } else {
                output += printer.printField(name: "value", raw: nil, decoded: "empty")
            }
        case .textString(let s):
            output += printer.printField(name: "type", raw: nil, decoded: "textString")
            output += printer.printField(name: "value", raw: nil, decoded: "\"\(s)\"")
        case .array(let arr):
            output += printer.printField(name: "type", raw: nil, decoded: "array")
            output += printer.printField(name: "length", raw: nil, decoded: "\(arr.count)")
            output += printer.printContainer(name: "elements")
            for (index, elem) in arr.enumerated() {
                output += printer.printContainer(name: "[\(index)]")
                output += printCBORValueStructure(elem, printer: &printer)
                output += printer.closeContainer()
            }
            output += printer.closeContainer()
        case .map(let pairs):
            output += printer.printField(name: "type", raw: nil, decoded: "map")
            output += printer.printField(name: "length", raw: nil, decoded: "\(pairs.count)")
            output += printer.printContainer(name: "pairs")
            for (key, val) in pairs {
                let keyStr = keyDescription(key)
                output += printer.printContainer(name: keyStr)
                output += printCBORValueStructure(val, printer: &printer)
                output += printer.closeContainer()
            }
            output += printer.closeContainer()
        case .tagged(let tag, let inner):
            output += printer.printField(name: "type", raw: nil, decoded: "tagged")
            output += printer.printField(name: "tag", raw: nil, decoded: "\(tag)")
            output += printer.printContainer(name: "value")
            output += printCBORValueStructure(inner, printer: &printer)
            output += printer.closeContainer()
        case .simple(let u):
            output += printer.printField(name: "type", raw: nil, decoded: "simple")
            output += printer.printField(name: "value", raw: nil, decoded: "\(u)")
        case .boolean(let b):
            output += printer.printField(name: "type", raw: nil, decoded: "boolean")
            output += printer.printField(name: "value", raw: nil, decoded: "\(b)")
        case .null:
            output += printer.printField(name: "type", raw: nil, decoded: "null")
        case .undefined:
            output += printer.printField(name: "type", raw: nil, decoded: "undefined")
        }
        
        return output
    }
    
}

// Note: CBOR encoding is not implemented
// Raw CBOR bytes should be preserved during decoding, not re-encoded
