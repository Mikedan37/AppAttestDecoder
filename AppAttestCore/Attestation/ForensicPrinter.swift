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
    
    private func formatHex(_ data: Data, bytesPerGroup: Int = 4) -> String {
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
    private func forensicPrintTranscript(colorized: Bool) -> String {
        var transcript = ForensicTranscriptPrinter(colorized: colorized)
        var output = ""
        
        // 1. Header (orientation)
        output += transcript.sectionHeader("APP ATTEST FORENSIC TRANSCRIPT")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let decodedAt = dateFormatter.string(from: Date())
        
        if let rawData = rawData {
            output += transcript.field(name: "CBOR length", value: "\(rawData.count) bytes")
        }
        output += transcript.field(name: "Decoded at", value: decodedAt)
        output += transcript.field(name: "Tool mode", value: "forensic/full")
        output += transcript.field(name: "Format", value: format)
        output += "\n"
        
        // 2. Raw CBOR (all of it)
        if let rawData = rawData {
            output += transcript.rawDataBlock(title: "CBOR RAW PAYLOAD", data: rawData, encoding: "CBOR")
        }
        
        // 3. Structural walkthrough
        output += transcript.sectionHeader("CBOR STRUCTURE WALKTHROUGH")
        output += "Map (2 entries):\n\n"
        output += "1. \"authenticatorData\"\n"
        output += "   Raw length: \(authenticatorData.rawData.count) bytes\n"
        output += "   Encoding: WebAuthn Authenticator Data\n\n"
        
        // Authenticator Data - Raw
        output += transcript.rawDataBlock(title: "AUTHENTICATOR DATA — RAW", data: authenticatorData.rawData, encoding: "WebAuthn Authenticator Data")
        
        // Authenticator Data - Decoded
        output += transcript.subsectionHeader("AUTHENTICATOR DATA — DECODED")
        
        output += transcript.fieldWithRaw(
            name: "rpIdHash",
            decoded: "SHA-256(bundleID)",
            raw: authenticatorData.rpIdHash,
            encoding: "SHA256"
        )
        
        output += transcript.field(name: "flags", value: "0x\(String(format: "%02x", authenticatorData.flags.rawValue)) (\(authenticatorData.flags.rawValue))")
        output += transcript.field(name: "  userPresent", value: "\(authenticatorData.flags.userPresent)", indent: 2)
        output += transcript.field(name: "  userVerified", value: "\(authenticatorData.flags.userVerified)", indent: 2)
        output += transcript.field(name: "  attestedCredentialData", value: "\(authenticatorData.flags.attestedCredentialData)", indent: 2)
        output += transcript.field(name: "  extensionsIncluded", value: "\(authenticatorData.flags.extensionsIncluded)", indent: 2)
        
        output += transcript.field(name: "signCount", value: "\(authenticatorData.signCount)")
        
        // Attested Credential Data
        if let credData = authenticatorData.attestedCredentialData {
            output += transcript.subsectionHeader("ATTESTED CREDENTIAL DATA")
            
            output += transcript.rawDataBlock(title: "AAGUID", data: credData.aaguid, encoding: "UUID")
            
            output += transcript.rawDataBlock(title: "CREDENTIAL ID", data: credData.credentialId, encoding: "byte string")
            
            // Credential Public Key (CBOR)
            output += transcript.subsectionHeader("CREDENTIAL PUBLIC KEY")
            output += "Encoding: COSE_Key (CBOR)\n"
            output += transcriptPrintCBORValue(credData.credentialPublicKey, transcript: &transcript, indent: 0)
        }
        
        // Extensions
        if let extensions = authenticatorData.extensions {
            output += transcript.subsectionHeader("EXTENSIONS")
            output += transcriptPrintCBORValue(extensions, transcript: &transcript, indent: 0)
        }
        
        // Attestation Statement
        output += transcript.sectionHeader("ATTESTATION STATEMENT")
        
        output += "2. \"attestationStatement\"\n"
        output += "   Format: \(format)\n\n"
        
        if let alg = attestationStatement.alg {
            output += transcript.field(name: "Algorithm", value: "\(alg) (ES256)")
            output += transcript.field(name: "  COSE alg", value: "\(alg)", indent: 2)
            output += transcript.field(name: "  Meaning", value: "ES256", indent: 2)
        } else {
            output += transcript.field(name: "Algorithm", value: "nil")
        }
        
        if !attestationStatement.signature.isEmpty {
            output += transcript.rawDataBlock(title: "SIGNATURE", data: attestationStatement.signature, encoding: "ECDSA")
            output += transcript.field(name: "Status", value: "[OPAQUE] (not interpreted)")
        } else {
            output += transcript.field(name: "Signature", value: "empty")
        }
        
        // Certificate Chain
        if !attestationStatement.x5c.isEmpty {
            output += transcript.sectionHeader("CERTIFICATE CHAIN")
            
            for (index, certDER) in attestationStatement.x5c.enumerated() {
                let role = index == 0 ? "Leaf" : index == attestationStatement.x5c.count - 1 ? "Root" : "Intermediate"
                output += transcript.subsectionHeader("Certificate [\(index)] — \(role)")
                
                output += transcript.field(name: "DER length", value: "\(certDER.count) bytes")
                output += "\n"
                
                // Raw DER
                output += transcript.rawDataBlock(title: "RAW DER", data: certDER, encoding: "DER")
                
                // Parsed certificate
                if let cert = try? X509Certificate.parse(der: certDER) {
                    output += transcript.subsectionHeader("TBSCertificate")
                    
                    let subjectStr = cert.subject.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.subject.description
                    output += transcript.field(name: "Subject", value: subjectStr)
                    
                    let issuerStr = cert.issuer.attributes.first(where: { $0.oid == "2.5.4.3" })?.value ?? cert.issuer.description
                    output += transcript.field(name: "Issuer", value: issuerStr)
                    
                    if !cert.serialNumber.isEmpty {
                        output += transcript.fieldWithRaw(
                            name: "Serial Number",
                            decoded: "\(cert.serialNumber.map { String(format: "%02x", $0) }.joined())",
                            raw: cert.serialNumber,
                            encoding: "integer"
                        )
                    }
                    
                    output += transcript.field(name: "Validity", value: "")
                    let formatter = ISO8601DateFormatter()
                    output += transcript.field(name: "  Not Before", value: formatter.string(from: cert.validity.notBefore), indent: 2)
                    output += transcript.field(name: "  Not After", value: formatter.string(from: cert.validity.notAfter), indent: 2)
                    
                    // Extensions
                    let decodedExts = cert.decodedExtensions
                    if !decodedExts.isEmpty {
                        output += transcript.subsectionHeader("Extensions")
                        
                        for (oid, ext) in decodedExts.sorted(by: { $0.key < $1.key }) {
                            let extName = X509OID.name(for: oid)
                            output += transcript.field(name: "OID", value: oid)
                            output += transcript.field(name: "Name", value: extName)
                            
                            if let rawDER = cert.extensions[oid] {
                                output += transcript.rawDataBlock(title: "Raw DER", data: rawDER, encoding: "DER")
                            }
                            
                            // Decoded value
                            output += transcript.field(name: "Decoded", value: "")
                            switch ext {
                            case .basicConstraints(let isCA, let pathLength):
                                output += transcript.field(name: "  isCA", value: "\(isCA)", indent: 2)
                                if let pathLength = pathLength {
                                    output += transcript.field(name: "  pathLengthConstraint", value: "\(pathLength)", indent: 2)
                                }
                            case .keyUsage(let usages):
                                let usageNames = usages.map { $0.name }.joined(separator: ", ")
                                output += transcript.field(name: "  usages", value: usageNames, indent: 2)
                            case .extendedKeyUsage(let usages):
                                let usageNames = usages.map { $0.name }.joined(separator: ", ")
                                output += transcript.field(name: "  usages", value: usageNames, indent: 2)
                            case .appleOID(_, let appleExt):
                                output += transcriptPrintAppleExtension(appleExt, transcript: &transcript, indent: 2)
                            case .unknown(_, let raw):
                                output += transcript.field(name: "  [OPAQUE]", value: "Unknown extension", indent: 2)
                                output += transcript.rawDataBlock(title: "Raw Value", data: raw, encoding: "DER")
                            }
                            output += "\n"
                        }
                    }
                } else {
                    output += transcript.field(name: "Parse Error", value: "Failed to parse certificate")
                }
                
                output += "\n"
            }
        }
        
        // Receipt (if present in rawCBOR)
        if case .map(let mapPairs) = attestationStatement.rawCBOR,
           let receiptValue = mapPairs.first(where: { key, _ in
               if case .textString("receipt") = key { return true }
               return false
           })?.1,
           case .byteString(let receiptData) = receiptValue {
            output += transcript.sectionHeader("RECEIPT")
            output += transcript.rawDataBlock(title: "RECEIPT RAW", data: receiptData, encoding: "CBOR")
        }
        
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
            output += transcript.field(name: "type", value: "challenge", indent: indent)
            output += transcript.fieldWithRaw(name: "hash", decoded: "SHA-256", raw: hash, encoding: "SHA256", indent: indent)
        case .receipt(let receipt):
            output += transcript.field(name: "type", value: "receipt", indent: indent)
            if let bundleID = receipt.bundleID {
                output += transcript.field(name: "bundleID", value: bundleID, indent: indent)
            }
            if let teamID = receipt.teamID {
                output += transcript.field(name: "teamID", value: teamID, indent: indent)
            }
            if let appVersion = receipt.appVersion {
                output += transcript.field(name: "appVersion", value: appVersion, indent: indent)
            }
            if let creationDate = receipt.receiptCreationDate {
                let formatter = ISO8601DateFormatter()
                output += transcript.field(name: "receiptCreationDate", value: formatter.string(from: creationDate), indent: indent)
            }
            if let expirationDate = receipt.receiptExpirationDate {
                let formatter = ISO8601DateFormatter()
                output += transcript.field(name: "receiptExpirationDate", value: formatter.string(from: expirationDate), indent: indent)
            }
        case .keyPurpose(let purpose):
            output += transcript.field(name: "type", value: "keyPurpose", indent: indent)
            output += transcript.field(name: "purpose", value: purpose, indent: indent)
        case .environment(let env):
            output += transcript.field(name: "type", value: "environment", indent: indent)
            output += transcript.field(name: "value", value: env, indent: indent)
        case .osVersion(let version):
            output += transcript.field(name: "type", value: "osVersion", indent: indent)
            output += transcript.field(name: "value", value: version, indent: indent)
        case .deviceClass(let deviceClass):
            output += transcript.field(name: "type", value: "deviceClass", indent: indent)
            output += transcript.field(name: "value", value: deviceClass, indent: indent)
        case .unknown(_, let raw):
            output += transcript.field(name: "type", value: "unknown", indent: indent)
            output += transcript.rawDataBlock(title: "Raw Value", data: raw, encoding: "DER")
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
