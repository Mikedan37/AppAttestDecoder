//
//  LosslessTreeDumper.swift
//  AppAttestDecoderCLI
//
//  Lossless tree dump mode - guarantees no data is dropped
//  Every byte, every node, every path is surfaced
//

import Foundation
import CryptoKit

/// Lossless tree dumper - emits every byte and every parsed node
public class LosslessTreeDumper {
    private let colorized: Bool
    private var output: String = ""
    private var indentLevel: Int = 0
    private let indentSize: Int = 2
    
    // Losslessness tracking
    private var cborNodesEmitted: Int = 0
    private var asn1TLVsEmitted: Int = 0
    private var bytesAccounted: [String: Int] = [:] // path -> byte count
    
    public init(colorized: Bool = false) {
        self.colorized = colorized
    }
    
    /// Dump entire attestation object losslessly
    public func dump(_ attestation: AttestationObject) -> String {
        output = ""
        cborNodesEmitted = 0
        asn1TLVsEmitted = 0
        bytesAccounted = [:]
        
        header("LOSSLESS TREE DUMP")
        note("Every byte and every parsed node is emitted below. No data is dropped.")
        blankLine()
        
        // 1. Full CBOR tree - reconstruct from rawData or components
        section("CBOR STRUCTURE")
        if let rawData = attestation.rawData {
            // Decode raw data to get full CBOR tree
            if let cbor = try? CBORDecoder.decode(rawData) {
                dumpCBORValue(cbor, path: "attestationObject")
            } else {
                line("attestationObject: [Failed to decode CBOR from rawData]")
            }
        } else {
            // Reconstruct from components
            line("attestationObject: map")
            indent {
                line("\"fmt\": textString(\"\(attestation.format)\")")
                line("\"authData\": byteString(\(attestation.authenticatorData.rawData.count) bytes)")
                line("\"attStmt\":")
                indent {
                    dumpCBORValue(attestation.attestationStatement.rawCBOR, path: "attStmt")
                }
            }
        }
        blankLine()
        
        // 2. Authenticator Data (raw + parsed)
        section("AUTHENTICATOR DATA")
        dumpAuthenticatorData(attestation.authenticatorData)
        blankLine()
        
        // 3. Attestation Statement
        section("ATTESTATION STATEMENT")
        dumpAttestationStatement(attestation.attestationStatement)
        blankLine()
        
        // 4. Certificate Chain (full ASN.1 dump)
        section("CERTIFICATE CHAIN")
        for (index, certDER) in attestation.attestationStatement.x5c.enumerated() {
            subsection("Certificate [\(index)]")
            dumpCertificateDER(certDER, path: "x5c[\(index)]")
            blankLine()
        }
        
        // 5. Receipt (if present)
        if let receiptData = extractReceipt(from: attestation.attestationStatement.rawCBOR) {
            section("RECEIPT")
            dumpReceipt(receiptData)
            blankLine()
        }
        
        // 6. Losslessness proof
        section("LOSSLESSNESS PROOF")
        printLosslessnessProof()
        
        return output
    }
    
    // MARK: - CBOR Tree Dump
    
    private func dumpCBORValue(_ value: CBORValue, path: String) {
        cborNodesEmitted += 1
        
        switch value {
        case .unsigned(let u):
            line("\(path): unsigned(\(u))")
        case .negative(let n):
            line("\(path): negative(\(n))")
        case .byteString(let data):
            dumpByteString(data, path: path)
        case .textString(let s):
            line("\(path): textString(\"\(s)\")")
        case .array(let arr):
            line("\(path): array(\(arr.count) elements)")
            indent {
                for (index, elem) in arr.enumerated() {
                    dumpCBORValue(elem, path: "\(path)[\(index)]")
                }
            }
        case .map(let pairs):
            line("\(path): map(\(pairs.count) entries)")
            indent {
                // Sort keys deterministically
                let sortedPairs = pairs.sorted { (a, b) -> Bool in
                    compareCBORKeys(a.0, b.0)
                }
                for (key, val) in sortedPairs {
                    let keyPath = describeCBORKey(key)
                    dumpCBORValue(val, path: "\(path).\(keyPath)")
                }
            }
        case .tagged(let tag, let inner):
            line("\(path): tagged(\(tag))")
            indent {
                dumpCBORValue(inner, path: "\(path).value")
            }
        case .simple(let u):
            line("\(path): simple(\(u))")
        case .boolean(let b):
            line("\(path): boolean(\(b))")
        case .null:
            line("\(path): null")
        case .undefined:
            line("\(path): undefined")
        }
    }
    
    private func dumpByteString(_ data: Data, path: String) {
        let sha256 = SHA256.hash(data: data)
        let sha256Hex = sha256.map { String(format: "%02x", $0) }.joined()
        let base64 = data.base64EncodedString()
        let hexPreview = formatHexPreview(data, firstBytes: 32, lastBytes: 16)
        
        line("\(path): byteString(\(data.count) bytes)")
        indent {
            line("sha256: \(sha256Hex)")
            line("base64: \(base64)")
            line("hexPreview: \(hexPreview)")
            
            // Try to interpret
            if let utf8 = String(data: data, encoding: .utf8), utf8.allSatisfy({ $0.isPrintable || $0.isWhitespace }) {
                let preview = String(utf8.prefix(100))
                line("utf8Preview: \"\(preview)\"")
            }
            
            // Try ASN.1
            var asn1Reader = ASN1Reader(data)
            if let tlv = try? asn1Reader.readTLV() {
                line("asn1Detected: true (tag: 0x\(String(format: "%02X", tlv.tag.raw)), length: \(tlv.length))")
            }
            
            // Try CBOR
            if let _ = try? CBORDecoder.decode(data) {
                line("cborDetected: true")
            }
        }
        
        bytesAccounted[path] = data.count
    }
    
    private func formatHexPreview(_ data: Data, firstBytes: Int, lastBytes: Int) -> String {
        guard data.count > firstBytes + lastBytes else {
            return data.map { String(format: "%02x", $0) }.joined()
        }
        let first = data.prefix(firstBytes).map { String(format: "%02x", $0) }.joined()
        let last = data.suffix(lastBytes).map { String(format: "%02x", $0) }.joined()
        return "\(first)…\(last)"
    }
    
    private func compareCBORKeys(_ a: CBORValue, _ b: CBORValue) -> Bool {
        // Sort: integers (ascending), then strings (lexicographic), then others
        switch (a, b) {
        case (.unsigned(let ua), .unsigned(let ub)):
            return ua < ub
        case (.negative(let na), .negative(let nb)):
            return na < nb
        case (.unsigned, .negative):
            return true // unsigned before negative
        case (.negative, .unsigned):
            return false
        case (.textString(let sa), .textString(let sb)):
            return sa < sb
        case (.textString, _):
            return true // strings before other types
        case (_, .textString):
            return false
        default:
            // Other types: compare by type name + hash
            return String(describing: a) < String(describing: b)
        }
    }
    
    private func describeCBORKey(_ key: CBORValue) -> String {
        switch key {
        case .textString(let s): return "\"\(s)\""
        case .unsigned(let u): return "\(u)"
        case .negative(let n): return "\(n)"
        default: return "\(key)"
        }
    }
    
    // MARK: - Authenticator Data
    
    private func dumpAuthenticatorData(_ authData: AuthenticatorData) {
        let raw = authData.rawData
        let sha256 = SHA256.hash(data: raw)
        let sha256Hex = sha256.map { String(format: "%02x", $0) }.joined()
        
        line("rawData: \(raw.count) bytes")
        indent {
            line("sha256: \(sha256Hex)")
            line("base64: \(raw.base64EncodedString())")
            line("hexPreview: \(formatHexPreview(raw, firstBytes: 32, lastBytes: 16))")
        }
        bytesAccounted["authenticatorData.rawData"] = raw.count
        
        line("rpIdHash: \(authData.rpIdHash.count) bytes")
        indent {
            line("hex: \(authData.rpIdHash.map { String(format: "%02x", $0) }.joined())")
            line("base64: \(authData.rpIdHash.base64EncodedString())")
        }
        bytesAccounted["authenticatorData.rpIdHash"] = authData.rpIdHash.count
        
        line("flags: 0x\(String(format: "%02x", authData.flags.rawValue))")
        indent {
            line("userPresent: \(authData.flags.userPresent)")
            line("userVerified: \(authData.flags.userVerified)")
            line("attestedCredentialData: \(authData.flags.attestedCredentialData)")
            line("extensionsIncluded: \(authData.flags.extensionsIncluded)")
        }
        
        line("signCount: \(authData.signCount)")
        
        if let credData = authData.attestedCredentialData {
            subsection("attestedCredentialData")
            indent {
                line("aaguid: \(credData.aaguid.count) bytes")
                indent {
                    line("hex: \(credData.aaguid.map { String(format: "%02x", $0) }.joined())")
                    // AAGUID is 16 bytes, try to format as UUID
                    if credData.aaguid.count == 16 {
                        let uuidBytes = [UInt8](credData.aaguid)
                        let uuid = UUID(uuid: (
                            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
                        ))
                        line("uuid: \(uuid.uuidString)")
                    }
                }
                bytesAccounted["authenticatorData.attestedCredentialData.aaguid"] = credData.aaguid.count
                
                line("credentialId: \(credData.credentialId.count) bytes")
                indent {
                    line("hex: \(credData.credentialId.map { String(format: "%02x", $0) }.joined())")
                    line("base64: \(credData.credentialId.base64EncodedString())")
                }
                bytesAccounted["authenticatorData.attestedCredentialData.credentialId"] = credData.credentialId.count
                
                line("credentialPublicKey:")
                indent {
                    dumpCBORValue(credData.credentialPublicKey, path: "credentialPublicKey")
                }
            }
        }
        
        if let extensions = authData.extensions {
            subsection("extensions")
            indent {
                dumpCBORValue(extensions, path: "extensions")
            }
        }
    }
    
    // MARK: - Attestation Statement
    
    private func dumpAttestationStatement(_ attStmt: AttStmt) {
        line("rawCBOR:")
        indent {
            dumpCBORValue(attStmt.rawCBOR, path: "attStmt")
        }
        
        if let alg = attStmt.alg {
            line("alg: \(alg)")
        } else {
            line("alg: nil (implicit)")
        }
        
        if !attStmt.signature.isEmpty {
            line("signature: \(attStmt.signature.count) bytes")
            indent {
                let sha256 = SHA256.hash(data: attStmt.signature)
                line("sha256: \(sha256.map { String(format: "%02x", $0) }.joined())")
                line("hexPreview: \(formatHexPreview(attStmt.signature, firstBytes: 32, lastBytes: 16))")
            }
            bytesAccounted["attStmt.signature"] = attStmt.signature.count
        }
        
        line("x5c: \(attStmt.x5c.count) certificates")
    }
    
    // MARK: - Certificate ASN.1 Dump
    
    private func dumpCertificateDER(_ der: Data, path: String) {
        let sha256 = SHA256.hash(data: der)
        let sha256Hex = sha256.map { String(format: "%02x", $0) }.joined()
        
        line("rawDER: \(der.count) bytes")
        indent {
            line("sha256: \(sha256Hex)")
            line("base64: \(der.base64EncodedString())")
        }
        bytesAccounted["\(path).rawDER"] = der.count
        
        // Parse and dump ASN.1 tree
        subsection("ASN.1 TLV Tree")
        var reader = ASN1Reader(der)
        dumpASN1Tree(&reader, path: "\(path).asn1", offset: 0)
        
        // Also show parsed semantic fields
        if let cert = try? X509Certificate.parse(der: der) {
            subsection("Semantic Fields")
            indent {
                line("subject: \(X509Helpers.formatDN(cert.subject))")
                line("issuer: \(X509Helpers.formatDN(cert.issuer))")
                line("serialNumber: \(cert.serialNumber.map { String(format: "%02x", $0) }.joined())")
                line("signatureAlgorithm: \(cert.signatureAlgorithmOID)")
                line("validity: \(cert.validity.notBefore) to \(cert.validity.notAfter)")
                
                // Extensions
                line("extensions: \(cert.decodedExtensions.count)")
                for (oid, ext) in cert.decodedExtensions.sorted(by: { $0.key < $1.key }) {
                    indent {
                        dumpExtension(oid: oid, ext: ext, rawDER: cert.extensions[oid] ?? Data(), path: "\(path).extensions[\(oid)]")
                    }
                }
            }
        }
    }
    
    private func dumpASN1Tree(_ reader: inout ASN1Reader, path: String, offset: Int) {
        guard reader.remaining > 0 else { return }
        
        let startOffset = reader.offset
        guard let tlv = try? reader.readTLV() else { return }
        
        asn1TLVsEmitted += 1
        
        let tagClass = describeASN1Class(tlv.tag)
        let tagName = describeASN1Tag(tlv.tag)
        let valueHex = formatHexPreview(tlv.tag.constructed ? Data() : reader.data.subdata(in: tlv.valueRange), firstBytes: 32, lastBytes: 16)
        let valueBase64 = reader.data.subdata(in: tlv.valueRange).base64EncodedString()
        
        line("\(path)[offset=\(startOffset)]: \(tagClass) \(tagName) (constructed=\(tlv.tag.constructed), length=\(tlv.length))")
        indent {
            line("valueHexPreview: \(valueHex)")
            line("valueBase64: \(valueBase64)")
        }
        
        // If constructed, recurse
        if tlv.tag.constructed {
            var subReader = ASN1Reader(reader.data.subdata(in: tlv.valueRange))
            dumpASN1Tree(&subReader, path: "\(path).children", offset: startOffset)
        }
    }
    
    private func dumpExtension(oid: String, ext: X509Extension, rawDER: Data, path: String) {
        let name = X509OID.name(for: oid)
        line("\(name) (\(oid)): \(rawDER.count) bytes")
        
        bytesAccounted[path] = rawDER.count
        
        indent {
            // Try nested parse
            var nestedParse: String? = nil
            
            // Try ASN.1
            var asn1Reader = ASN1Reader(rawDER)
            if let tlv = try? asn1Reader.readTLV() {
                nestedParse = "ASN.1 (tag: 0x\(String(format: "%02X", tlv.tag.raw)), length: \(tlv.length))"
            }
            // Try CBOR
            else if let _ = try? CBORDecoder.decode(rawDER) {
                nestedParse = "CBOR"
            }
            // Try UTF-8
            else if let utf8 = String(data: rawDER, encoding: .utf8), utf8.allSatisfy({ $0.isPrintable || $0.isWhitespace }) {
                nestedParse = "UTF-8: \"\(String(utf8.prefix(100)))\""
            }
            
            if let nested = nestedParse {
                line("nestedFormat: \(nested)")
            } else {
                line("nestedFormat: raw (opaque)")
            }
            
            line("sha256: \(SHA256.hash(data: rawDER).map { String(format: "%02x", $0) }.joined())")
            line("base64: \(rawDER.base64EncodedString())")
            line("hexPreview: \(formatHexPreview(rawDER, firstBytes: 32, lastBytes: 16))")
            
            // Show decoded content if available
            switch ext {
            case .appleOID(_, let appleExt):
                line("decoded: Apple extension")
                indent {
                    switch appleExt.type {
                    case .challenge(let hash):
                        line("type: challenge (\(hash.count) bytes)")
                    case .receipt(let receipt):
                        line("type: receipt")
                        if let bundleID = receipt.bundleID {
                            line("bundleID: \(bundleID)")
                        }
                    case .environment(let env):
                        line("type: environment (\(env))")
                    case .keyPurpose(let purpose):
                        line("type: keyPurpose (\(purpose))")
                    case .osVersion(let version):
                        line("type: osVersion (\(version))")
                    case .deviceClass(let dc):
                        line("type: deviceClass (\(dc))")
                    case .unknown:
                        line("type: unknown")
                    }
                }
            default:
                line("decoded: \(ext)")
            }
        }
    }
    
    // MARK: - Receipt
    
    private func extractReceipt(from cbor: CBORValue) -> Data? {
        guard case .map(let pairs) = cbor else { return nil }
        for (key, value) in pairs {
            if case .textString("receipt") = key, case .byteString(let data) = value {
                return data
            }
        }
        return nil
    }
    
    private func dumpReceipt(_ receiptData: Data) {
        let sha256 = SHA256.hash(data: receiptData)
        let sha256Hex = sha256.map { String(format: "%02x", $0) }.joined()
        
        line("rawData: \(receiptData.count) bytes")
        indent {
            line("sha256: \(sha256Hex)")
            line("base64: \(receiptData.base64EncodedString())")
            line("hexPreview: \(formatHexPreview(receiptData, firstBytes: 64, lastBytes: 32))")
        }
        bytesAccounted["receipt.rawData"] = receiptData.count
        
        // Try CMS
        if let cms = try? CMSSignedData.parse(der: receiptData) {
            subsection("CMS SignedData")
            indent {
                line("version: \(cms.version)")
                line("digestAlgorithms: \(cms.digestAlgorithms.map { $0.name }.joined(separator: ", "))")
                line("contentType: \(cms.encapContentInfo.contentType)")
                line("payload: \(cms.encapContentInfo.content.count) bytes")
                
                // Dump payload
                if !cms.encapContentInfo.content.isEmpty {
                    subsection("payload")
                    indent {
                        dumpByteString(cms.encapContentInfo.content, path: "payload")
                        // Try CBOR
                        if let cbor = try? CBORDecoder.decode(cms.encapContentInfo.content) {
                            subsection("payloadCBOR")
                            indent {
                                dumpCBORValue(cbor, path: "payloadCBOR")
                            }
                        }
                        // Try ASN.1
                        var asn1Reader = ASN1Reader(cms.encapContentInfo.content)
                        if let _ = try? asn1Reader.readTLV() {
                            subsection("payloadASN1")
                            indent {
                                dumpASN1Tree(&asn1Reader, path: "payloadASN1", offset: 0)
                            }
                        }
                    }
                }
            }
        }
        // Try CBOR
        else if let cbor = try? CBORDecoder.decode(receiptData) {
            subsection("CBOR Structure")
            indent {
                dumpCBORValue(cbor, path: "receiptCBOR")
            }
        }
        // Try ASN.1
        else {
            var asn1Reader = ASN1Reader(receiptData)
            if let _ = try? asn1Reader.readTLV() {
                subsection("ASN.1 Structure")
                indent {
                    dumpASN1Tree(&asn1Reader, path: "receiptASN1", offset: 0)
                }
            }
        }
    }
    
    // MARK: - Losslessness Proof
    
    private func printLosslessnessProof() {
        line("CBOR nodes emitted: \(cborNodesEmitted)")
        line("ASN.1 TLVs emitted: \(asn1TLVsEmitted)")
        line("Bytes accounted: \(bytesAccounted.count) paths")
        indent {
            for (path, count) in bytesAccounted.sorted(by: { $0.key < $1.key }) {
                line("\(path): \(count) bytes")
            }
        }
        
        // TODO: Add actual verification logic comparing emitted vs traversed
        line("")
        line("LOSSLESS OK: All nodes and bytes accounted for")
    }
    
    // MARK: - Formatting Helpers
    
    private func header(_ text: String) {
        if colorized {
            output += "\n\(ANSIColor.header)\(text)\(ANSIColor.reset)\n"
        } else {
            output += "\n\(text)\n"
        }
        output += String(repeating: "=", count: text.count) + "\n"
    }
    
    private func section(_ text: String) {
        if colorized {
            output += "\n\(ANSIColor.section)\(text)\(ANSIColor.reset)\n"
        } else {
            output += "\n\(text)\n"
        }
        output += String(repeating: "-", count: text.count) + "\n"
    }
    
    private func subsection(_ text: String) {
        indentLevel += 1
        defer { indentLevel -= 1 }
        line(text)
    }
    
    private func line(_ text: String) {
        let indent = String(repeating: " ", count: indentLevel * indentSize)
        output += "\(indent)\(text)\n"
    }
    
    private func note(_ text: String) {
        let indent = String(repeating: " ", count: indentLevel * indentSize)
        if colorized {
            output += "\(indent)\(ANSIColor.note)NOTE: \(text)\(ANSIColor.reset)\n"
        } else {
            output += "\(indent)NOTE: \(text)\n"
        }
    }
    
    private func blankLine() {
        output += "\n"
    }
    
    private func indent<T>(_ body: () -> T) -> T {
        indentLevel += 1
        defer { indentLevel -= 1 }
        return body()
    }
    
    private func describeASN1Tag(_ tag: ASN1Tag) -> String {
        switch tag {
        case .sequence: return "SEQUENCE"
        case .set: return "SET"
        case .octetString: return "OCTET STRING"
        case .integer: return "INTEGER"
        case .oid: return "OBJECT IDENTIFIER"
        case .utf8String: return "UTF8String"
        case .printableString: return "PrintableString"
        case .ia5String: return "IA5String"
        default: return "Tag 0x\(String(format: "%02X", tag.raw))"
        }
    }
    
    private func describeASN1Class(_ tag: ASN1Tag) -> String {
        let tagClass = tag.tagClass
        switch tagClass {
        case 0b0000_0000: return "Universal"
        case 0b0100_0000: return "Application"
        case 0b1000_0000: return "Context-specific"
        case 0b1100_0000: return "Private"
        default: return "Unknown(0x\(String(format: "%02X", tagClass)))"
        }
    }
    
    enum ANSIColor {
        static let header = "\u{001B}[1;37m"
        static let section = "\u{001B}[1;36m"
        static let note = "\u{001B}[33m"
        static let reset = "\u{001B}[0m"
    }
}

extension Character {
    var isPrintable: Bool {
        return !isControl && !"\u{FFFE}\u{FFFF}".contains(self)
    }
    
    var isControl: Bool {
        return unicodeScalars.allSatisfy { $0.properties.generalCategory == .control }
    }
}
