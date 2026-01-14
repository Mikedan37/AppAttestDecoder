//
//  AppleAppAttestExtension.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// Decoded Apple App Attest certificate extension
/// 
/// Apple uses proprietary OIDs (1.2.840.113635.*) to encode App Attest metadata.
/// This struct decodes the known extensions into human-readable fields.
public struct AppleAppAttestExtension {
    /// The OID of this extension
    public let oid: String
    
    /// Decoded extension type
    public let type: ExtensionType
    
    /// Raw DER bytes (preserved for audit)
    public let rawValue: Data
    
    public enum ExtensionType {
        /// Challenge/Nonce extension (1.2.840.113635.100.8.2)
        /// Contains the SHA256 hash of (authenticatorData || clientDataHash)
        case challenge(Data)
        
        /// Receipt extension (1.2.840.113635.100.8.5)
        /// Contains CBOR-encoded receipt with app metadata
        case receipt(AppleAppAttestReceipt)
        
        /// Key Purpose extension (1.2.840.113635.100.8.6)
        /// Indicates key purpose: "app-attest", "fraud-receipt-signing", etc.
        case keyPurpose(String)
        
        /// Environment extension (1.2.840.113635.100.8.7)
        /// "sandbox" or "production"
        case environment(String)
        
        /// OS Version extension (1.2.840.113635.100.8.8)
        /// iOS version string (e.g., "17.2")
        case osVersion(String)
        
        /// Device Class extension (1.2.840.113635.100.8.9)
        /// Device type: "iphoneos", "ipados", etc.
        case deviceClass(String)
        
        /// Unknown Apple extension
        case unknown(oid: String, raw: Data)
    }
    
    /// Decode an Apple extension from OID and raw value
    public static func decode(oid: String, rawValue: Data) throws -> AppleAppAttestExtension {
        let type: ExtensionType
        
        switch oid {
        case X509OID.appleAppAttestChallenge:
            type = try decodeChallenge(rawValue)
        case X509OID.appleAppAttestReceipt:
            type = try decodeReceipt(rawValue)
        case X509OID.appleAppAttestKeyPurpose:
            type = try decodeKeyPurpose(rawValue)
        case X509OID.appleAppAttestEnvironment:
            type = try decodeEnvironment(rawValue)
        case X509OID.appleAppAttestOSVersion:
            type = try decodeOSVersion(rawValue)
        case X509OID.appleAppAttestDeviceClass:
            type = try decodeDeviceClass(rawValue)
        default:
            type = .unknown(oid: oid, raw: rawValue)
        }
        
        return AppleAppAttestExtension(oid: oid, type: type, rawValue: rawValue)
    }
    
    // MARK: - Decoders
    
    private static func decodeChallenge(_ data: Data) throws -> ExtensionType {
        // Challenge is typically an OCTET STRING containing the hash
        var reader = ASN1Reader(data)
        let oct = try reader.expectTag(.octetString)
        let hash = reader.data.subdata(in: oct.valueRange)
        return .challenge(hash)
    }
    
    private static func decodeReceipt(_ data: Data) throws -> ExtensionType {
        // Receipt is an OCTET STRING containing CBOR-encoded receipt
        var reader = ASN1Reader(data)
        let oct = try reader.expectTag(.octetString)
        let cborData = reader.data.subdata(in: oct.valueRange)
        
        // Decode CBOR receipt
        let receipt = try AppleAppAttestReceipt.decode(cborData: cborData)
        return .receipt(receipt)
    }
    
    private static func decodeKeyPurpose(_ data: Data) throws -> ExtensionType {
        // Key purpose is typically an OCTET STRING containing UTF-8 string
        var reader = ASN1Reader(data)
        let oct = try reader.expectTag(.octetString)
        let purposeData = reader.data.subdata(in: oct.valueRange)
        
        if let purpose = String(data: purposeData, encoding: .utf8) {
            return .keyPurpose(purpose)
        }
        throw ASN1Error.invalidData
    }
    
    private static func decodeEnvironment(_ data: Data) throws -> ExtensionType {
        var reader = ASN1Reader(data)
        let oct = try reader.expectTag(.octetString)
        let envData = reader.data.subdata(in: oct.valueRange)
        
        if let env = String(data: envData, encoding: .utf8) {
            return .environment(env)
        }
        throw ASN1Error.invalidData
    }
    
    private static func decodeOSVersion(_ data: Data) throws -> ExtensionType {
        var reader = ASN1Reader(data)
        let oct = try reader.expectTag(.octetString)
        let versionData = reader.data.subdata(in: oct.valueRange)
        
        if let version = String(data: versionData, encoding: .utf8) {
            return .osVersion(version)
        }
        throw ASN1Error.invalidData
    }
    
    private static func decodeDeviceClass(_ data: Data) throws -> ExtensionType {
        var reader = ASN1Reader(data)
        let oct = try reader.expectTag(.octetString)
        let classData = reader.data.subdata(in: oct.valueRange)
        
        if let deviceClass = String(data: classData, encoding: .utf8) {
            return .deviceClass(deviceClass)
        }
        throw ASN1Error.invalidData
    }
}

/// Apple App Attest Receipt (CBOR-encoded)
/// 
/// The receipt contains app metadata extracted from the certificate extension.
public struct AppleAppAttestReceipt {
    /// Bundle identifier
    public let bundleID: String?
    
    /// Apple Team ID
    public let teamID: String?
    
    /// App version
    public let appVersion: String?
    
    /// Receipt creation date
    public let receiptCreationDate: Date?
    
    /// Receipt expiration date
    public let receiptExpirationDate: Date?
    
    /// Raw CBOR value (for inspection)
    public let rawCBOR: CBORValue
    
    /// Decode receipt from CBOR data
    public static func decode(cborData: Data) throws -> AppleAppAttestReceipt {
        let cbor = try CBORDecoder.decode(cborData)
        
        guard case .map(let pairs) = cbor else {
            throw ASN1Error.invalidData
        }
        
        var bundleID: String? = nil
        var teamID: String? = nil
        var appVersion: String? = nil
        var receiptCreationDate: Date? = nil
        var receiptExpirationDate: Date? = nil
        
        // Apple uses specific CBOR keys in the receipt
        // These are typically negative integers (COSE-style)
        for (key, value) in pairs {
            // Extract key as integer
            var keyInt: Int? = nil
            switch key {
            case .unsigned(let u): keyInt = Int(u)
            case .negative(let n): keyInt = Int(n)
            default: continue
            }
            
            guard let k = keyInt else { continue }
            
            // Apple receipt keys (observed values, not documented)
            // Key 4: Bundle ID (text string)
            // Key 5: Team ID (text string)
            // Key 12: Receipt creation date (text string, ISO 8601)
            // Key 21: Receipt expiration date (text string, ISO 8601)
            switch k {
            case 4:
                if case .textString(let str) = value {
                    bundleID = str
                }
            case 5:
                if case .textString(let str) = value {
                    teamID = str
                }
            case 12:
                if case .textString(let str) = value {
                    receiptCreationDate = parseISO8601Date(str)
                }
            case 21:
                if case .textString(let str) = value {
                    receiptExpirationDate = parseISO8601Date(str)
                }
            default:
                // Unknown key - preserve in raw CBOR
                break
            }
        }
        
        return AppleAppAttestReceipt(
            bundleID: bundleID,
            teamID: teamID,
            appVersion: appVersion,
            receiptCreationDate: receiptCreationDate,
            receiptExpirationDate: receiptExpirationDate,
            rawCBOR: cbor
        )
    }
    
    private static func parseISO8601Date(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: str) ?? formatter.date(from: str.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
    }
}

// MARK: - ASN1Error Extension

extension ASN1Error {
    static let invalidData = ASN1Error.expected("invalid extension data")
}
