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
    public static let basicConstraints = "2.5.29.19"
    
    /// Key Usage (2.5.29.15)
    public static let keyUsage = "2.5.29.15"
    
    /// Extended Key Usage (2.5.29.37)
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
    public static let appleAppAttestChallenge = "1.2.840.113635.100.8.2"
    
    /// Apple App Attest Receipt Extension (1.2.840.113635.100.8.5)
    public static let appleAppAttestReceipt = "1.2.840.113635.100.8.5"
    
    /// Apple App Attest Key Purpose Extension (1.2.840.113635.100.8.6)
    public static let appleAppAttestKeyPurpose = "1.2.840.113635.100.8.6"
    
    /// Apple App Attest Environment Extension (1.2.840.113635.100.8.7)
    public static let appleAppAttestEnvironment = "1.2.840.113635.100.8.7"
    
    /// Apple App Attest OS Version Extension (1.2.840.113635.100.8.8)
    public static let appleAppAttestOSVersion = "1.2.840.113635.100.8.8"
    
    /// Apple App Attest Device Class Extension (1.2.840.113635.100.8.9)
    public static let appleAppAttestDeviceClass = "1.2.840.113635.100.8.9"
    
    // MARK: - Helper Methods
    
    public static func isAppleOID(_ oid: String) -> Bool {
        return oid.hasPrefix(appleRoot)
    }
    
    public static func name(for oid: String) -> String {
        switch oid {
        case basicConstraints: return "Basic Constraints"
        case keyUsage: return "Key Usage"
        case extendedKeyUsage: return "Extended Key Usage"
        case subjectAlternativeName: return "Subject Alternative Name"
        case authorityKeyIdentifier: return "Authority Key Identifier"
        case subjectKeyIdentifier: return "Subject Key Identifier"
        case appleAppAttestChallenge: return "Apple App Attest Challenge"
        case appleAppAttestReceipt: return "Apple App Attest Receipt"
        case appleAppAttestKeyPurpose: return "Apple App Attest Key Purpose"
        case appleAppAttestEnvironment: return "Apple App Attest Environment"
        case appleAppAttestOSVersion: return "Apple App Attest OS Version"
        case appleAppAttestDeviceClass: return "Apple App Attest Device Class"
        default:
            if isAppleOID(oid) {
                return "Apple Proprietary Extension (\(oid))"
            }
            return "Unknown Extension (\(oid))"
        }
    }
}
