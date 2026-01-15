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
                case .basicConstraints, .keyUsage, .extendedKeyUsage:
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
        let flagsDesc = authenticatorData.flags.attestedCredentialData ? "ACD" : ""
        authDataContent += transcript.twoColumnField(key: "RP ID HASH", value: "SHA256(\(format))")
        authDataContent += transcript.twoColumnField(key: "FLAGS", value: "0x\(String(format: "%02x", authenticatorData.flags.rawValue)) (\(flagsDesc))")
        authDataContent += transcript.twoColumnField(key: "USER PRESENT", value: "\(authenticatorData.flags.userPresent)")
        authDataContent += transcript.twoColumnField(key: "USER VERIFIED", value: "\(authenticatorData.flags.userVerified)")
        authDataContent += transcript.twoColumnField(key: "ATTESTED CREDENTIAL", value: "\(authenticatorData.flags.attestedCredentialData)")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let signCountFormatted = formatter.string(from: NSNumber(value: authenticatorData.signCount)) ?? "\(authenticatorData.signCount)"
        authDataContent += transcript.twoColumnField(key: "SIGN COUNT", value: "\(signCountFormatted) (anti-replay counter)")
        
        output += transcript.boxedSection("AUTHENTICATOR DATA", content: authDataContent)
        
        // Attested Credential Data
        if let credData = authenticatorData.attestedCredentialData {
            var credDataContent = ""
            credDataContent += transcript.twoColumnField(key: "AAGUID", value: "[\(credData.aaguid.count) bytes]")
            credDataContent += transcript.twoColumnField(key: "CREDENTIAL ID", value: "[\(credData.credentialId.count) bytes]")
            
            // Credential Public Key (COSE Key - decoded)
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
                
                credDataContent += "\n"
                credDataContent += transcript.twoColumnField(key: "kty", value: kty ?? "unknown")
                if let alg = alg {
                    credDataContent += transcript.twoColumnField(key: "alg", value: alg)
                }
                if let crv = crv {
                    credDataContent += transcript.twoColumnField(key: "crv", value: crv)
                }
                if let x = x {
                    credDataContent += transcript.twoColumnField(key: "x", value: "[\(x.count) bytes]")
                }
                if let y = y {
                    credDataContent += transcript.twoColumnField(key: "y", value: "[\(y.count) bytes]")
                }
            }
            
            output += transcript.boxedSection("ATTESTED CREDENTIAL DATA", content: credDataContent)
            
            // Raw bytes collected for end (if showRaw)
            transcript.addRawDataBlock(title: "AAGUID", data: credData.aaguid, encoding: "UUID")
            transcript.addRawDataBlock(title: "CREDENTIAL ID", data: credData.credentialId, encoding: "byte string")
        }
        
        // Extensions
        if let extensions = authenticatorData.extensions {
            let extContent = transcript.twoColumnField(key: "EXTENSIONS", value: "present (CBOR-encoded)")
            output += transcript.boxedSection("EXTENSIONS", content: extContent)
        }
        
        // Attestation Statement
        var attStmtContent = ""
        
        // Algorithm
        if let alg = attestationStatement.alg {
            attStmtContent += transcript.twoColumnField(key: "ALGORITHM", value: "\(alg) (ES256)")
        } else {
            attStmtContent += transcript.twoColumnField(key: "ALGORITHM", value: "Implicit (certificate-based attestation)")
        }
        
        // Signature
        if !attestationStatement.signature.isEmpty {
            attStmtContent += transcript.twoColumnField(key: "SIGNATURE", value: "🔒 ECDSA signature (opaque, not interpreted)")
            attStmtContent += transcript.bulletPoint("Location: attStmt map (extracted)", indent: 2)
            attStmtContent += transcript.bulletPoint("Purpose: ECDSA signature over authenticatorData || clientDataHash", indent: 2)
            attStmtContent += transcript.bulletPoint("Verification: requires validated certificate chain (not performed here)", indent: 2)
        } else {
            attStmtContent += transcript.twoColumnField(key: "SIGNATURE", value: "◻ Not present (certificate-based attestation)")
        }
        
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
                    
                    // Summary (two-column)
                    let subjectStr = cert.subject.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.subject.description
                    certContent += transcript.twoColumnField(key: "SUBJECT", value: subjectStr)
                    
                    let issuerStr = cert.issuer.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.issuer.description
                    certContent += transcript.twoColumnField(key: "ISSUER", value: issuerStr)
                    
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                    certContent += transcript.twoColumnField(key: "NOT BEFORE", value: formatter.string(from: cert.validity.notBefore))
                    certContent += transcript.twoColumnField(key: "NOT AFTER", value: formatter.string(from: cert.validity.notAfter))
                    
                    // Extensions (Decoded) - with visual indicators
                    let decodedExts = cert.decodedExtensions
                    if !decodedExts.isEmpty {
                        certContent += "\n"
                        for (oid, ext) in decodedExts.sorted(by: { $0.key < $1.key }) {
                            let extName = X509OID.name(for: oid)
                            let symbol: String
                            switch ext {
                            case .appleOID, .basicConstraints, .keyUsage, .extendedKeyUsage:
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
                            case .keyUsage(let usages):
                                for usage in usages {
                                    certContent += transcript.bulletPoint(usage.name, indent: 2)
                                }
                            case .extendedKeyUsage(let usages):
                                for usage in usages {
                                    certContent += transcript.bulletPoint(usage.name, indent: 2)
                                }
                            case .appleOID(_, let appleExt):
                                certContent += transcriptPrintAppleExtension(appleExt, transcript: &transcript, indent: 2)
                            case .unknown(_, _):
                                certContent += transcript.bulletPoint("Opaque (raw DER preserved)", indent: 2)
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
            let receiptContent = transcript.twoColumnField(key: "RECEIPT", value: "present (\(receiptData.count) bytes)")
            output += transcript.boxedSection("RECEIPT", content: receiptContent)
            // Raw bytes collected for end (if showRaw)
            transcript.addRawDataBlock(title: "Receipt", data: receiptData, encoding: "CBOR")
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
        
        switch appleExt.type {
        case .challenge(let hash):
            output += transcript.bulletPoint("hash: SHA-256 (\(hash.count) bytes)", indent: indent)
        case .receipt(let receipt):
            if let bundleID = receipt.bundleID {
                output += transcript.bulletPoint("bundleID: \(bundleID)", indent: indent)
            }
            if let teamID = receipt.teamID {
                output += transcript.bulletPoint("teamID: \(teamID)", indent: indent)
            }
            if let appVersion = receipt.appVersion {
                output += transcript.bulletPoint("appVersion: \(appVersion)", indent: indent)
            }
            if let creationDate = receipt.receiptCreationDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                output += transcript.bulletPoint("receiptCreationDate: \(formatter.string(from: creationDate))", indent: indent)
            }
            if let expirationDate = receipt.receiptExpirationDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                output += transcript.bulletPoint("receiptExpirationDate: \(formatter.string(from: expirationDate))", indent: indent)
            }
        case .keyPurpose(let purpose):
            output += transcript.bulletPoint("purpose: \(purpose)", indent: indent)
        case .environment(let env):
            output += transcript.bulletPoint("environment: \(env)", indent: indent)
        case .osVersion(let version):
            output += transcript.bulletPoint("osVersion: \(version)", indent: indent)
        case .deviceClass(let deviceClass):
            output += transcript.bulletPoint("deviceClass: \(deviceClass)", indent: indent)
        case .unknown(_, let raw):
            output += transcript.bulletPoint("Opaque (\(raw.count) bytes, raw DER preserved)", indent: indent)
        }
        
        return output
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
            let usageNames = usages.map { $0.name }.joined(separator: ", ")
            output += printer.printField(name: "usages", raw: nil, decoded: usageNames)
        case .extendedKeyUsage(let usages):
            let usageNames = usages.map { $0.name }.joined(separator: ", ")
            output += printer.printField(name: "usages", raw: nil, decoded: usageNames)
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
