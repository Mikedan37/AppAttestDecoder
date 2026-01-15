//
//  X509Extension.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// Decoded X.509 certificate extension
/// 
/// This enum represents the decoded value of a certificate extension.
/// Unknown extensions are preserved with their raw data for audit purposes.
public enum X509Extension {
    // MARK: - Standard Extensions
    
    /// Basic Constraints (2.5.29.19)
    /// Indicates whether the subject is a CA and maximum path length
    case basicConstraints(isCA: Bool, pathLengthConstraint: Int?)
    
    /// Key Usage (2.5.29.15)
    /// Defines the purpose of the key
    case keyUsage([KeyUsage])
    
    /// Extended Key Usage (2.5.29.37)
    /// Additional key purposes beyond basic key usage
    case extendedKeyUsage([ExtendedKeyUsage])
    
    /// Subject Alternative Name (2.5.29.17)
    case subjectAlternativeName([SubjectAlternativeName])
    
    /// Authority Key Identifier (2.5.29.35)
    case authorityKeyIdentifier(keyIdentifier: Data?, authorityCertIssuer: String?, authorityCertSerialNumber: Data?)
    
    /// Subject Key Identifier (2.5.29.14)
    case subjectKeyIdentifier(Data)
    
    // MARK: - Apple Extensions
    
    /// Apple proprietary extension with decoded value
    case appleOID(oid: String, decoded: AppleAppAttestExtension)
    
    /// Unknown extension (preserved with raw data for audit)
    case unknown(oid: String, raw: Data)
    
    // MARK: - Decode
    
    /// Decode an extension from its OID and raw DER value
    /// - Parameters:
    ///   - oid: The extension OID
    ///   - rawValue: The raw DER bytes of the extension value
    /// - Returns: Decoded extension, or unknown if decoding fails
    /// - Note: Always returns a valid extension (never crashes). Unknown or failed decodings are preserved.
    public static func decode(oid: String, rawValue: Data) -> X509Extension {
        // Defensive: validate inputs
        guard !oid.isEmpty else {
            return .unknown(oid: "", raw: rawValue)
        }
        
        // Defensive: limit raw value size to prevent DoS (max 10 MB)
        guard rawValue.count <= 10 * 1024 * 1024 else {
            return .unknown(oid: oid, raw: Data())  // Preserve OID but truncate huge raw data
        }
        
        do {
            switch oid {
            case X509OID.basicConstraints:
                return try decodeBasicConstraints(rawValue)
            case X509OID.keyUsage:
                return try decodeKeyUsage(rawValue)
            case X509OID.extendedKeyUsage:
                return try decodeExtendedKeyUsage(rawValue)
            case X509OID.subjectAlternativeName:
                return try decodeSubjectAlternativeName(rawValue)
            case X509OID.authorityKeyIdentifier:
                return try decodeAuthorityKeyIdentifier(rawValue)
            case X509OID.subjectKeyIdentifier:
                return try decodeSubjectKeyIdentifier(rawValue)
            default:
                if X509OID.isAppleOID(oid) {
                    return try decodeAppleExtension(oid: oid, rawValue: rawValue)
                }
                return .unknown(oid: oid, raw: rawValue)
            }
        } catch {
            // If decoding fails, preserve as unknown with raw data
            // This ensures we never lose information, even if parsing fails
            return .unknown(oid: oid, raw: rawValue)
        }
    }
    
    // MARK: - Standard Extension Decoders
    
    private static func decodeBasicConstraints(_ data: Data) throws -> X509Extension {
        var reader = ASN1Reader(data)
        let seq = try reader.expectTag(.sequence)
        var isCA = false
        var pathLength: Int? = nil
        
        try reader.withValueReader(seq) { r in
            // Optional cA BOOLEAN (defaults to FALSE)
            if r.remaining > 0 {
                if let boolTLV = try? r.expectTag(.boolean) {
                    let boolBytes = r.data.subdata(in: boolTLV.valueRange)
                    isCA = !boolBytes.isEmpty && boolBytes[0] != 0
                }
            }
            
            // Optional pathLenConstraint INTEGER
            if r.remaining > 0 {
                if let intTLV = try? r.expectTag(.integer) {
                    let intBytes = r.data.subdata(in: intTLV.valueRange)
                    if !intBytes.isEmpty {
                        var value: Int = 0
                        for byte in intBytes {
                            value = (value << 8) | Int(byte)
                        }
                        // Handle signed integers (two's complement)
                        if intBytes[0] & 0x80 != 0 {
                            // Negative - not typical for path length, but handle it
                            let mask = (1 << (intBytes.count * 8)) - 1
                            value = value - mask - 1
                        }
                        pathLength = value
                    }
                }
            }
        }
        
        return .basicConstraints(isCA: isCA, pathLengthConstraint: pathLength)
    }
    
    private static func decodeKeyUsage(_ data: Data) throws -> X509Extension {
        var reader = ASN1Reader(data)
        let bitString = try reader.expectTag(.bitString)
        
        // First byte is "unused bits" count
        let bitStringData = reader.data.subdata(in: bitString.valueRange)
        guard bitStringData.count >= 1 else {
            throw ASN1Error.truncated
        }
        
        let unusedBits = Int(bitStringData[0])
        let bits = bitStringData.dropFirst()
        
        var usages: [KeyUsage] = []
        var bitPosition = 0
        
        for byte in bits {
            for bitOffset in 0..<8 {
                if bitPosition >= 9 { break } // Key Usage has 9 defined bits
                if unusedBits > 0 && bitPosition == (bits.count * 8 - unusedBits) {
                    break
                }
                
                if (byte & (1 << (7 - bitOffset))) != 0 {
                    if let usage = KeyUsage(rawValue: bitPosition) {
                        usages.append(usage)
                    }
                }
                bitPosition += 1
            }
        }
        
        return .keyUsage(usages)
    }
    
    private static func decodeExtendedKeyUsage(_ data: Data) throws -> X509Extension {
        var reader = ASN1Reader(data)
        let seq = try reader.expectTag(.sequence)
        var usages: [ExtendedKeyUsage] = []
        
        try reader.withValueReader(seq) { r in
            while r.remaining > 0 {
                let oid = try r.readOID()
                if let usage = ExtendedKeyUsage.fromOID(oid) {
                    usages.append(usage)
                } else {
                    // Unknown EKU OID - preserve it
                    usages.append(.unknown(oid: oid))
                }
            }
        }
        
        return .extendedKeyUsage(usages)
    }
    
    private static func decodeSubjectAlternativeName(_ data: Data) throws -> X509Extension {
        var reader = ASN1Reader(data)
        // SAN is a GeneralNames, which is a SEQUENCE OF GeneralName
        let seq = try reader.expectTag(.sequence)
        var names: [SubjectAlternativeName] = []
        let readerData = reader.data  // Copy to avoid overlapping access
        
        try reader.withValueReader(seq) { r in
            while r.remaining > 0 {
                // GeneralName is a CHOICE, tagged with context-specific tags
                let tlv = try r.readTLV()
                let tag = tlv.tag
                
                // Context-specific tags: [0] otherName, [1] rfc822Name, [2] dNSName, etc.
                if tag.tagClass == 0b1000_0000 { // Context-specific
                    let nameType = Int(tag.number)
                    let valueData = readerData.subdata(in: tlv.valueRange)
                    
                    switch nameType {
                    case 2: // dNSName (IA5String)
                        if let str = String(data: valueData, encoding: .ascii) {
                            names.append(.dnsName(str))
                        }
                    case 4: // directoryName (Name)
                        // For now, just store as raw
                        names.append(.directoryName(valueData))
                    case 6: // uniformResourceIdentifier (IA5String)
                        if let str = String(data: valueData, encoding: .ascii) {
                            names.append(.uri(str))
                        }
                    case 7: // iPAddress (OCTET STRING)
                        names.append(.ipAddress(valueData))
                    default:
                        names.append(.other(nameType, valueData))
                    }
                }
            }
        }
        
        return .subjectAlternativeName(names)
    }
    
    private static func decodeAuthorityKeyIdentifier(_ data: Data) throws -> X509Extension {
        var reader = ASN1Reader(data)
        let seq = try reader.expectTag(.sequence)
        var keyIdentifier: Data? = nil
        var authorityCertIssuer: String? = nil
        var authorityCertSerialNumber: Data? = nil
        
        try reader.withValueReader(seq) { r in
            while r.remaining > 0 {
                let tlv = try r.readTLV()
                // Context-specific tags: [0] keyIdentifier, [1] authorityCertIssuer, [2] authorityCertSerialNumber
                if tlv.tag.tagClass == 0b1000_0000 {
                    let number = tlv.tag.number
                    
                    switch number {
                    case 0: // keyIdentifier (OCTET STRING)
                        var octReader = ASN1Reader(r.data.subdata(in: tlv.valueRange))
                        let oct = try octReader.expectTag(.octetString)
                        keyIdentifier = octReader.data.subdata(in: oct.valueRange)
                    case 1: // authorityCertIssuer (GeneralNames)
                        // For now, skip complex parsing
                        authorityCertIssuer = "GeneralNames"
                    case 2: // authorityCertSerialNumber (INTEGER)
                        var intReader = ASN1Reader(r.data.subdata(in: tlv.valueRange))
                        let intBytes = try intReader.readIntegerBytes()
                        authorityCertSerialNumber = intBytes
                    default:
                        break
                    }
                }
            }
        }
        
        return .authorityKeyIdentifier(
            keyIdentifier: keyIdentifier,
            authorityCertIssuer: authorityCertIssuer,
            authorityCertSerialNumber: authorityCertSerialNumber
        )
    }
    
    private static func decodeSubjectKeyIdentifier(_ data: Data) throws -> X509Extension {
        var reader = ASN1Reader(data)
        let oct = try reader.expectTag(.octetString)
        let identifier = reader.data.subdata(in: oct.valueRange)
        return .subjectKeyIdentifier(identifier)
    }
    
    // MARK: - Apple Extension Decoder
    
    private static func decodeAppleExtension(oid: String, rawValue: Data) throws -> X509Extension {
        let decoded = try AppleAppAttestExtension.decode(oid: oid, rawValue: rawValue)
        return .appleOID(oid: oid, decoded: decoded)
    }
}

// MARK: - Supporting Types

/// Key Usage flags (RFC 5280)
public enum KeyUsage: Int, CaseIterable {
    case digitalSignature = 0
    case contentCommitment = 1
    case keyEncipherment = 2
    case dataEncipherment = 3
    case keyAgreement = 4
    case keyCertSign = 5
    case cRLSign = 6
    case encipherOnly = 7
    case decipherOnly = 8
    
    public var name: String {
        switch self {
        case .digitalSignature: return "Digital Signature"
        case .contentCommitment: return "Content Commitment"
        case .keyEncipherment: return "Key Encipherment"
        case .dataEncipherment: return "Data Encipherment"
        case .keyAgreement: return "Key Agreement"
        case .keyCertSign: return "Key Cert Sign"
        case .cRLSign: return "CRL Sign"
        case .encipherOnly: return "Encipher Only"
        case .decipherOnly: return "Decipher Only"
        }
    }
}

/// Extended Key Usage OIDs
public enum ExtendedKeyUsage {
    case serverAuth
    case clientAuth
    case codeSigning
    case emailProtection
    case timeStamping
    case ocspSigning
    case unknown(oid: String)
    
    public static func fromOID(_ oid: String) -> ExtendedKeyUsage? {
        switch oid {
        case "1.3.6.1.5.5.7.3.1": return .serverAuth
        case "1.3.6.1.5.5.7.3.2": return .clientAuth
        case "1.3.6.1.5.5.7.3.3": return .codeSigning
        case "1.3.6.1.5.5.7.3.4": return .emailProtection
        case "1.3.6.1.5.5.7.3.8": return .timeStamping
        case "1.3.6.1.5.5.7.3.9": return .ocspSigning
        default: return nil
        }
    }
    
    public var name: String {
        switch self {
        case .serverAuth: return "Server Authentication"
        case .clientAuth: return "Client Authentication"
        case .codeSigning: return "Code Signing"
        case .emailProtection: return "Email Protection"
        case .timeStamping: return "Time Stamping"
        case .ocspSigning: return "OCSP Signing"
        case .unknown(let oid): return "Unknown EKU (\(oid))"
        }
    }
}

/// Subject Alternative Name types
public enum SubjectAlternativeName {
    case dnsName(String)
    case directoryName(Data)
    case uri(String)
    case ipAddress(Data)
    case other(Int, Data)
    
    public var description: String {
        switch self {
        case .dnsName(let name): return "DNS: \(name)"
        case .directoryName(let data): return "DirectoryName: [\(data.count) bytes]"
        case .uri(let uri): return "URI: \(uri)"
        case .ipAddress(let data): return "IP: \(data.map { String(format: "%02x", $0) }.joined(separator: ":"))"
        case .other(let tag, let data): return "Other[\(tag)]: [\(data.count) bytes]"
        }
    }
}

// MARK: - ASN1Reader Extensions
