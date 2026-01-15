//
//  AttestationSemanticModel.swift
//  AppAttestDecoderCLI
//
//  Semantic intermediate representation for attestation objects
//  Separates decoding from presentation
//

import Foundation

/// Semantic model representing decoded attestation meaning
/// This is the intermediate representation between decoding and presentation
public struct AttestationSemanticModel {
    /// Executive summary (orientation)
    public let summary: SummarySection
    
    /// Identity and authentication context
    public let identity: IdentitySection
    
    /// Credential binding information
    public let credential: CredentialSection?
    
    /// Certificate trust chain
    public let trustChain: TrustChainSection
    
    /// Platform claims (environment, OS, device)
    public let platformClaims: PlatformClaimsSection
    
    /// Receipt information (if present)
    public let receipt: ReceiptSection?
    
    /// Raw evidence (all bytes, structures, offsets)
    public let rawEvidence: RawEvidenceSection
    
    // MARK: - Sections
    
    public struct SummarySection {
        public let format: String
        public let certificateChainLength: Int
        public let receiptPresent: Bool
        public let attestedCredentialPresent: Bool
        public let environment: String?
        public let extensionCount: (decoded: Int, opaque: Int)
    }
    
    public struct IdentitySection {
        public let rpIdHash: HashInfo
        public let flags: FlagsInfo
        public let signCount: SignCountInfo
    }
    
    public struct HashInfo {
        public let algorithm: String
        public let hex: String
        public let base64: String
        public let length: Int
        public let raw: Data
    }
    
    public struct FlagsInfo {
        public let rawByte: UInt8
        public let userPresent: Bool
        public let userVerified: Bool
        public let attestedCredentialData: Bool
        public let extensionsIncluded: Bool
        public let raw: Data
    }
    
    public struct SignCountInfo {
        public let value: UInt32
        public let formatted: String
        public let significance: String
    }
    
    public struct CredentialSection {
        public let aaguid: AAGUIDInfo
        public let credentialId: CredentialIDInfo
        public let publicKey: COSEKeyInfo
    }
    
    public struct AAGUIDInfo {
        public let uuid: String?
        public let hex: String
        public let length: Int
        public let raw: Data
    }
    
    public struct CredentialIDInfo {
        public let hex: String
        public let base64: String
        public let length: Int
        public let raw: Data
    }
    
    public struct COSEKeyInfo {
        public let keyType: String?
        public let algorithm: String?
        public let curve: String?
        public let xCoordinate: CoordinateInfo?
        public let yCoordinate: CoordinateInfo?
        public let unknownParameters: [(label: String, value: String)]
        public let rawCBOR: CBORValue
    }
    
    public struct CoordinateInfo {
        public let length: Int
        public let hex: String
        public let raw: Data
    }
    
    public struct TrustChainSection {
        public let certificates: [CertificateInfo]
        public let chainStructure: String
    }
    
    public struct CertificateInfo {
        public let role: String // "Leaf", "Intermediate", "Root"
        public let index: Int
        public let subject: DistinguishedNameInfo
        public let issuer: DistinguishedNameInfo
        public let serialNumber: String // hex
        public let signatureAlgorithm: AlgorithmInfo
        public let publicKey: PublicKeyInfo
        public let validity: ValidityInfo
        public let extensions: [ExtensionInfo]
        public let rawDER: Data
    }
    
    public struct DistinguishedNameInfo {
        public let fullDN: String
        public let attributes: [AttributeInfo]
    }
    
    public struct AttributeInfo {
        public let oid: String
        public let name: String
        public let value: String
    }
    
    public struct AlgorithmInfo {
        public let oid: String
        public let name: String
    }
    
    public struct PublicKeyInfo {
        public let algorithm: String
        public let type: String?
        public let curve: String?
        public let keySize: Int?
        public let rawLength: Int
    }
    
    public struct ValidityInfo {
        public let notBefore: Date
        public let notAfter: Date
        public let durationDays: Int
        public let formatted: (notBefore: String, notAfter: String)
    }
    
    public struct ExtensionInfo {
        public let oid: String
        public let name: String
        public let critical: Bool
        public let decoded: DecodedExtension?
        public let rawDER: Data
        public let rawLength: Int
    }
    
    public enum DecodedExtension {
        case basicConstraints(isCA: Bool, pathLength: Int?)
        case keyUsage([KeyUsageFlag])
        case extendedKeyUsage([ExtendedKeyUsageOID])
        case subjectKeyIdentifier(Data)
        case authorityKeyIdentifier(keyId: Data?, issuer: String?, serial: Data?)
        case subjectAlternativeName([SubjectAlternativeName])
        case appleChallenge(Data)
        case appleReceipt(AppleReceiptInfo)
        case appleKeyPurpose(String)
        case appleEnvironment(String)
        case appleOSVersion(String)
        case appleDeviceClass(String)
    }
    
    public struct KeyUsageFlag {
        public let name: String
        public let bit: Int
    }
    
    public struct ExtendedKeyUsageOID {
        public let oid: String
        public let name: String
    }
    
    public enum SubjectAlternativeName {
        case dnsName(String)
        case directoryName(Data)
        case uri(String)
        case ipAddress(Data)
        case other(Int, Data)
        
        public var description: String {
            switch self {
            case .dnsName(let s): return "DNS: \(s)"
            case .directoryName: return "Directory Name (DER)"
            case .uri(let s): return "URI: \(s)"
            case .ipAddress: return "IP Address (binary)"
            case .other(let tag, _): return "Other [\(tag)]"
            }
        }
    }
    
    public struct AppleReceiptInfo {
        public let bundleID: String?
        public let teamID: String?
        public let appVersion: String?
        public let receiptCreationDate: Date?
        public let receiptExpirationDate: Date?
        public let rawCBOR: CBORValue
    }
    
    public struct PlatformClaimsSection {
        public let environment: String?
        public let osVersion: String?
        public let deviceClass: String?
        public let keyPurpose: String?
    }
    
    public struct ReceiptSection {
        public let containerType: String
        public let structure: ReceiptStructure
        public let rawData: Data
    }
    
    public enum ReceiptStructure {
        case cms(CMSSignedDataInfo)
        case cbor(CBORStructureInfo)
        case asn1(ASN1StructureInfo)
        case plist(PropertyListInfo)
        case opaque(reason: String)
    }
    
    public struct CMSSignedDataInfo {
        public let version: Int
        public let digestAlgorithms: [String]
        public let contentType: String
        public let contentTypeName: String
        public let payloadSize: Int
        public let certificates: [CertificateInfo]
        public let signers: [SignerInfo]
        public let payloadStructure: PayloadStructure?
    }
    
    public struct SignerInfo {
        public let version: Int
        public let identifier: SignerIdentifier
        public let digestAlgorithm: String
        public let signatureAlgorithm: String
        public let signatureLength: Int
        public let signedAttrsLength: Int?
    }
    
    public enum SignerIdentifier {
        case issuerAndSerialNumber(issuer: DistinguishedNameInfo, serial: String)
        case subjectKeyIdentifier(String)
    }
    
    public enum PayloadStructure {
        case asn1(String)
        case cbor(String)
        case plist(String)
        case opaque(String)
    }
    
    public struct CBORStructureInfo {
        public let majorType: String
        public let structure: String
        public let decoded: CBORValue?
    }
    
    public struct ASN1StructureInfo {
        public let tag: String
        public let tagClass: String
        public let constructed: Bool
        public let length: Int
        public let description: String
    }
    
    public struct PropertyListInfo {
        public let format: String // "binary" or "XML"
        public let rootType: String
    }
    
    public struct RawEvidenceSection {
        public let attestationObjectCBOR: Data
        public let authenticatorData: Data
        public let attestationStatement: AttestationStatementRaw
        public let certificates: [Data]
        public let extensions: [ExtensionRaw]
        public let receipt: Data?
    }
    
    public struct AttestationStatementRaw {
        public let rawCBOR: Data
        public let signature: Data?
        public let algorithm: String?
    }
    
    public struct ExtensionRaw {
        public let oid: String
        public let critical: Bool
        public let rawDER: Data
        public let asn1Tree: ASN1TreeNode?
    }
    
    public struct ASN1TreeNode {
        public let tag: ASN1TagInfo
        public let length: Int
        public let offset: Int
        public let children: [ASN1TreeNode]
        public let raw: Data
    }
    
    public struct ASN1TagInfo {
        public let raw: UInt8
        public let tagClass: String // "Universal", "Application", "Context-specific", "Private"
        public let number: UInt8
        public let constructed: Bool
        public let name: String?
    }
}
