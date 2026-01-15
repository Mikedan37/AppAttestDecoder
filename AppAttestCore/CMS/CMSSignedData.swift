//
//  CMSSignedData.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/14/26.
//

import Foundation

/// CMS SignedData structure (RFC 5652, PKCS#7)
/// This parser extracts the structure but does NOT verify signatures.
public struct CMSSignedData {
    /// CMS Version (typically 1)
    public let version: Int
    
    /// Digest algorithms used
    public let digestAlgorithms: [DigestAlgorithm]
    
    /// Encapsulated content information
    public let encapContentInfo: EncapsulatedContentInfo
    
    /// Certificates (optional)
    public let certificates: [Data]
    
    /// Signer information
    public let signerInfos: [SignerInfo]
    
    /// Raw DER bytes
    public let der: Data
    
    public struct DigestAlgorithm {
        public let oid: String
        public let name: String
        
        public static func name(for oid: String) -> String {
            switch oid {
            case "2.16.840.1.101.3.4.2.1": return "SHA-256"
            case "2.16.840.1.101.3.4.2.2": return "SHA-384"
            case "2.16.840.1.101.3.4.2.3": return "SHA-512"
            case "1.3.14.3.2.26": return "SHA-1"
            default:
                if oid.hasPrefix("2.16.840.1.101.3.4.2") { return "SHA variant (\(oid))" }
                return "Unknown digest algorithm (\(oid))"
            }
        }
    }
    
    public struct EncapsulatedContentInfo {
        /// Content type OID
        public let contentType: String
        
        /// Content type name
        public let contentTypeName: String
        
        /// Encapsulated content (OCTET STRING)
        public let content: Data
        
        public static func name(for oid: String) -> String {
            switch oid {
            case "1.2.840.113549.1.7.1": return "Data"
            case "1.2.840.113549.1.7.2": return "SignedData"
            case "1.2.840.113549.1.7.3": return "EnvelopedData"
            case "1.2.840.113549.1.7.4": return "SignedAndEnvelopedData"
            case "1.2.840.113549.1.7.5": return "DigestedData"
            case "1.2.840.113549.1.7.6": return "EncryptedData"
            default:
                if oid.hasPrefix("1.2.840.113549.1.7") { return "PKCS#7 variant (\(oid))" }
                return "Unknown content type (\(oid))"
            }
        }
    }
    
    public struct SignerInfo {
        /// SignerInfo version
        public let version: Int
        
        /// Issuer and serial number
        public let sid: SignerIdentifier
        
        /// Digest algorithm
        public let digestAlgorithm: DigestAlgorithm
        
        /// Signed attributes (optional)
        public let signedAttrs: Data?
        
        /// Signature algorithm
        public let signatureAlgorithm: String
        
        /// Signature algorithm name
        public let signatureAlgorithmName: String
        
        /// Signature value
        public let signature: Data
        
        public struct SignerIdentifier {
            public enum IDType {
                case issuerAndSerialNumber(issuer: X509Name, serialNumber: Data)
                case subjectKeyIdentifier(Data)
            }
            public let type: IDType
        }
    }
    
    /// Parse CMS SignedData from DER
    public static func parse(der: Data) throws -> CMSSignedData {
        var reader = ASN1Reader(der)
        let seq = try reader.expectTag(.sequence)
        
        // Check if this is wrapped in ContentInfo or direct SignedData
        var signedDataSeq: ASN1TLV = seq
        do {
            try reader.withValueReader(seq) { r in
                // Check if first element is OID (ContentInfo structure)
                if r.remaining > 0 {
                    let firstByte = try r.peekByte()
                    if firstByte == 0x06 { // OID tag
                        let contentTypeOID = try r.readOID()
                        if contentTypeOID == "1.2.840.113549.1.7.2" {
                            // This is ContentInfo, next is [0] IMPLICIT SignedData
                            let signedDataTLV = try r.readTLV()
                            if signedDataTLV.tag.tagClass == 0b1000_0000 && signedDataTLV.tag.number == 0 {
                                signedDataSeq = signedDataTLV
                            }
                        }
                    }
                }
            }
        } catch {
            // If parsing fails, assume direct SignedData
            signedDataSeq = seq
        }
        
        // Now parse SignedData structure
        return try reader.withValueReader(signedDataSeq) { r in
            // version CMSVersion
            let versionTLV = try r.expectTag(.integer)
            let versionBytes = r.data.subdata(in: versionTLV.valueRange)
            var version: Int = 0
            for byte in versionBytes {
                version = (version << 8) | Int(byte)
            }
            
            // digestAlgorithms DigestAlgorithmIdentifiers
            let digestAlgsTLV = try r.expectTag(.set)
            var digestAlgorithms: [DigestAlgorithm] = []
            try r.withValueReader(digestAlgsTLV) { da in
                while da.remaining > 0 {
                    let algSeq = try da.expectTag(.sequence)
                    try da.withValueReader(algSeq) { alg in
                        let oid = try alg.readOID()
                        digestAlgorithms.append(DigestAlgorithm(
                            oid: oid,
                            name: DigestAlgorithm.name(for: oid)
                        ))
                    }
                }
            }
            
            // encapContentInfo EncapsulatedContentInfo
            let encapContentTLV = try r.expectTag(.sequence)
            let encapContentInfo = try r.withValueReader(encapContentTLV) { eci -> EncapsulatedContentInfo in
                // eContentType ContentType
                let contentTypeOID = try eci.readOID()
                
                // [0] IMPLICIT eContent OCTET STRING OPTIONAL
                var content = Data()
                if eci.remaining > 0 {
                    let contentTLV = try eci.readTLV()
                    if contentTLV.tag == .octetString {
                        content = eci.data.subdata(in: contentTLV.valueRange)
                    }
                }
                
                return EncapsulatedContentInfo(
                    contentType: contentTypeOID,
                    contentTypeName: EncapsulatedContentInfo.name(for: contentTypeOID),
                    content: content
                )
            }
            
            // certificates [0] IMPLICIT CertificateSet OPTIONAL
            var certificates: [Data] = []
            if r.remaining > 0 {
                let tlv = try r.readTLV()
                // Context-specific tag [0]
                if tlv.tag.tagClass == 0b1000_0000 && tlv.tag.number == 0 {
                    try r.withValueReader(tlv) { certs in
                        while certs.remaining > 0 {
                            let certTLV = try certs.expectTag(.sequence)
                            let certDER = certs.data.subdata(in: certTLV.valueRange)
                            certificates.append(certDER)
                        }
                    }
                } else {
                    // Not certificates, put it back (we'll need to handle this differently)
                    // For now, skip
                }
            }
            
            // crls [1] IMPLICIT RevocationInfoChoices OPTIONAL (skip for now)
            
            // signerInfos SignerInfos
            let signerInfosTLV = try r.expectTag(.set)
            var signerInfos: [SignerInfo] = []
            try r.withValueReader(signerInfosTLV) { si in
                while si.remaining > 0 {
                        let siSeq = try si.expectTag(.sequence)
                        try si.withValueReader(siSeq) { signer in
                            // version
                            let versionTLV = try signer.expectTag(.integer)
                            let versionBytes = signer.data.subdata(in: versionTLV.valueRange)
                            var signerVersion: Int = 0
                            for byte in versionBytes {
                                signerVersion = (signerVersion << 8) | Int(byte)
                            }
                            
                            // sid SignerIdentifier
                            let sidTLV = try signer.readTLV()
                            var sid: SignerInfo.SignerIdentifier
                            if sidTLV.tag.tagClass == 0b1000_0000 && sidTLV.tag.number == 0 {
                                // issuerAndSerialNumber [0] IMPLICIT
                                var sidReader = ASN1Reader(signer.data.subdata(in: sidTLV.valueRange))
                                // issuerAndSerialNumber is SEQUENCE { issuer Name, serialNumber CertificateSerialNumber }
                                let issuer = try X509Certificate.readName(&sidReader)
                                let serialTLV = try sidReader.expectTag(.integer)
                                let serial = sidReader.data.subdata(in: serialTLV.valueRange)
                                sid = SignerInfo.SignerIdentifier(type: .issuerAndSerialNumber(issuer: issuer, serialNumber: serial))
                            } else {
                                // subjectKeyIdentifier [1] IMPLICIT (simplified)
                                let keyId = signer.data.subdata(in: sidTLV.valueRange)
                                sid = SignerInfo.SignerIdentifier(type: .subjectKeyIdentifier(keyId))
                            }
                            
                            // digestAlgorithm
                            let digestAlgSeq = try signer.expectTag(.sequence)
                            var digestOID: String = ""
                            try signer.withValueReader(digestAlgSeq) { da in
                                digestOID = try da.readOID()
                            }
                            let digestAlg = DigestAlgorithm(oid: digestOID, name: DigestAlgorithm.name(for: digestOID))
                            
                            // signedAttrs [0] IMPLICIT Attributes OPTIONAL
                            var signedAttrs: Data? = nil
                            if signer.remaining > 0 {
                                let attrsTLV = try signer.readTLV()
                                if attrsTLV.tag.tagClass == 0b1000_0000 && attrsTLV.tag.number == 0 {
                                    signedAttrs = signer.data.subdata(in: attrsTLV.valueRange)
                                } else {
                                    // Not signedAttrs, need to handle differently
                                    // For now, we'll need to backtrack
                                }
                            }
                            
                            // signatureAlgorithm
                            let sigAlgSeq = try signer.expectTag(.sequence)
                            var sigAlgOID: String = ""
                            try signer.withValueReader(sigAlgSeq) { sa in
                                sigAlgOID = try sa.readOID()
                            }
                            let sigAlgName = X509Helpers.signatureAlgorithmName(for: sigAlgOID)
                            
                            // signature SignatureValue
                            let sigTLV = try signer.expectTag(.octetString)
                            let signature = signer.data.subdata(in: sigTLV.valueRange)
                            
                            signerInfos.append(SignerInfo(
                                version: signerVersion,
                                sid: sid,
                                digestAlgorithm: digestAlg,
                                signedAttrs: signedAttrs,
                                signatureAlgorithm: sigAlgOID,
                                signatureAlgorithmName: sigAlgName,
                                signature: signature
                            ))
                        }
                }
            }
            
            return CMSSignedData(
                version: version,
                digestAlgorithms: digestAlgorithms,
                encapContentInfo: encapContentInfo,
                certificates: certificates,
                signerInfos: signerInfos,
                der: der
            )
        }
    }
}

public enum CMSError: Error, CustomStringConvertible {
    case invalidContentType
    case invalidStructure
    case truncated
    
    public var description: String {
        switch self {
        case .invalidContentType:
            return "CMS ContentInfo does not contain SignedData"
        case .invalidStructure:
            return "Invalid CMS SignedData structure"
        case .truncated:
            return "CMS SignedData is truncated or malformed"
        }
    }
}
