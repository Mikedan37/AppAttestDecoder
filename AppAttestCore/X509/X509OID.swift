//
//  X509OID.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// X.509 Object Identifiers (OIDs) used in certificate extensions
public enum X509OID {
    // MARK: - Standard X.509 Extensions
    
    /// Basic Constraints (2.5.29.19)
    /// Indicates whether the subject is a CA and maximum path length
    public static let basicConstraints = "2.5.29.19"
    
    /// Key Usage (2.5.29.15)
    /// Defines the purpose of the key (signing, encryption, etc.)
    public static let keyUsage = "2.5.29.15"
    
    /// Extended Key Usage (2.5.29.37)
    /// Additional key purposes beyond basic key usage
    public static let extendedKeyUsage = "2.5.29.37"
    
    /// Subject Alternative Name (2.5.29.17)
    public static let subjectAlternativeName = "2.5.29.17"
    
    /// Authority Key Identifier (2.5.29.35)
    public static let authorityKeyIdentifier = "2.5.29.35"
    
    /// Subject Key Identifier (2.5.29.14)
    public static let subjectKeyIdentifier = "2.5.29.14"
    
    // MARK: - Apple Proprietary OIDs
    
    /// Apple App Attest Root OID (1.2.840.113635)
    public static let appleRoot = "1.2.840.113635"
    
    /// Apple App Attest Challenge Extension (1.2.840.113635.100.8.2)
    /// Contains the nonce/challenge used for replay attack prevention
    public static let appleAppAttestChallenge = "1.2.840.113635.100.8.2"
    
    /// Apple App Attest Receipt Extension (1.2.840.113635.100.8.5)
    /// Contains CBOR-encoded receipt with app metadata
    public static let appleAppAttestReceipt = "1.2.840.113635.100.8.5"
    
    /// Apple App Attest Key Purpose Extension (1.2.840.113635.100.8.6)
    /// Indicates the purpose of the key (app-attest, fraud-receipt-signing, etc.)
    public static let appleAppAttestKeyPurpose = "1.2.840.113635.100.8.6"
    
    /// Apple App Attest Environment Extension (1.2.840.113635.100.8.7)
    /// Indicates sandbox vs production environment
    public static let appleAppAttestEnvironment = "1.2.840.113635.100.8.7"
    
    /// Apple App Attest OS Version Extension (1.2.840.113635.100.8.8)
    /// Contains iOS version information
    public static let appleAppAttestOSVersion = "1.2.840.113635.100.8.8"
    
    /// Apple App Attest Device Class Extension (1.2.840.113635.100.8.9)
    /// Indicates device type (iPhone, iPad, etc.)
    public static let appleAppAttestDeviceClass = "1.2.840.113635.100.8.9"
    
    // MARK: - Helper Methods
    
    /// Check if an OID is an Apple proprietary extension
    /// - Parameter oid: The OID string to check
    /// - Returns: `true` if the OID is an Apple extension, `false` otherwise
    /// - Note: Returns `false` for empty or invalid OIDs (defensive)
    public static func isAppleOID(_ oid: String) -> Bool {
        guard !oid.isEmpty else { return false }
        guard oid.count <= 256 else { return false }  // Defensive: prevent DoS
        return oid.hasPrefix(appleRoot)
    }
    
    /// Get human-readable name for a standard OID
    public static func name(for oid: String) -> String {
        switch oid {
        case basicConstraints:
            return "Basic Constraints"
        case keyUsage:
            return "Key Usage"
        case extendedKeyUsage:
            return "Extended Key Usage"
        case subjectAlternativeName:
            return "Subject Alternative Name"
        case authorityKeyIdentifier:
            return "Authority Key Identifier"
        case subjectKeyIdentifier:
            return "Subject Key Identifier"
        case appleAppAttestChallenge:
            return "Apple App Attest Challenge"
        case appleAppAttestReceipt:
            return "Apple App Attest Receipt"
        case appleAppAttestKeyPurpose:
            return "Apple App Attest Key Purpose"
        case appleAppAttestEnvironment:
            return "Apple App Attest Environment"
        case appleAppAttestOSVersion:
            return "Apple App Attest OS Version"
        case appleAppAttestDeviceClass:
            return "Apple App Attest Device Class"
        default:
            if isAppleOID(oid) {
                return "Apple Proprietary Extension (\(oid))"
            }
            return "Unknown Extension (\(oid))"
        }
    }
}