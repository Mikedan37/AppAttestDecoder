//
//  X509Extension.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

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
    case basicConstraints(isCA: Bool, pathLengthConstraint: Int?)
    
    /// Key Usage (2.5.29.15)
    case keyUsage([KeyUsage])
    
    /// Extended Key Usage (2.5.29.37)
    case extendedKeyUsage([ExtendedKeyUsage])
    
    /// Apple proprietary extension with decoded value
    case appleOID(oid: String, decoded: AppleAppAttestExtension)
    
    /// Unknown extension (preserved with raw data for audit)
    case unknown(oid: String, raw: Data)
    
    // MARK: - Decode
    
    /// Decode an extension from its OID and raw DER value
    public static func decode(oid: String, rawValue: Data) -> X509Extension {
        do {
            switch oid {
            case X509OID.basicConstraints:
                return try decodeBasicConstraints(rawValue)
            case X509OID.keyUsage:
                return try decodeKeyUsage(rawValue)
            case X509OID.extendedKeyUsage:
                return try decodeExtendedKeyUsage(rawValue)
            default:
                if X509OID.isAppleOID(oid) {
                    return try decodeAppleExtension(oid: oid, rawValue: rawValue)
                }
                return .unknown(oid: oid, raw: rawValue)
            }
        } catch {
            // If decoding fails, preserve as unknown with raw data
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
                if bitPosition >= 9 { break }
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
                    usages.append(.unknown(oid: oid))
                }
            }
        }
        
        return .extendedKeyUsage(usages)
    }
    
    // MARK: - Apple Extension Decoder
    
    private static func decodeAppleExtension(oid: String, rawValue: Data) throws -> X509Extension {
        let decoded = try AppleAppAttestExtension.decode(oid: oid, rawValue: rawValue)
        return .appleOID(oid: oid, decoded: decoded)
    }
}

// MARK: - Supporting Types

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
