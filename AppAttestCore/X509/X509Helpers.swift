//
//  X509Helpers.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/14/26.
//

import Foundation

/// Helper functions for X.509 certificate display and decoding
public enum X509Helpers {
    
    // MARK: - Signature Algorithm OIDs
    
    /// Common signature algorithm OIDs
    public static func signatureAlgorithmName(for oid: String) -> String {
        switch oid {
        case "1.2.840.10045.4.3.2": return "ECDSA-SHA256 (ecdsa-with-SHA256)"
        case "1.2.840.10045.4.3.3": return "ECDSA-SHA384 (ecdsa-with-SHA384)"
        case "1.2.840.10045.4.3.4": return "ECDSA-SHA512 (ecdsa-with-SHA512)"
        case "1.2.840.113549.1.1.11": return "RSA-SHA256 (sha256WithRSAEncryption)"
        case "1.2.840.113549.1.1.12": return "RSA-SHA384 (sha384WithRSAEncryption)"
        case "1.2.840.113549.1.1.13": return "RSA-SHA512 (sha512WithRSAEncryption)"
        default:
            if oid.hasPrefix("1.2.840.10045.4.3") { return "ECDSA variant (\(oid))" }
            if oid.hasPrefix("1.2.840.113549.1.1") { return "RSA variant (\(oid))" }
            return "Unknown signature algorithm (\(oid))"
        }
    }
    
    // MARK: - Public Key Algorithm OIDs
    
    /// Common public key algorithm OIDs
    public static func publicKeyAlgorithmName(for oid: String?) -> String {
        guard let oid = oid else { return "Unknown" }
        switch oid {
        case "1.2.840.10045.2.1": return "EC (Elliptic Curve, RFC 5480)"
        case "1.2.840.113549.1.1.1": return "RSA (RSA Encryption, PKCS#1)"
        default:
            if oid.hasPrefix("1.2.840.10045") { return "EC variant (\(oid))" }
            if oid.hasPrefix("1.2.840.113549") { return "RSA variant (\(oid))" }
            return "Unknown public key algorithm (\(oid))"
        }
    }
    
    // MARK: - Distinguished Name Attribute OIDs
    
    /// Common DN attribute OIDs (RFC 4519, RFC 2256)
    public static func dnAttributeName(for oid: String) -> String {
        switch oid {
        case "2.5.4.3": return "CN"  // Common Name
        case "2.5.4.4": return "SN"  // Surname
        case "2.5.4.5": return "SERIALNUMBER"
        case "2.5.4.6": return "C"   // Country
        case "2.5.4.7": return "L"   // Locality
        case "2.5.4.8": return "ST"  // State/Province
        case "2.5.4.10": return "O"  // Organization
        case "2.5.4.11": return "OU" // Organizational Unit
        case "2.5.4.12": return "T"  // Title
        case "2.5.4.13": return "DESCRIPTION"
        case "2.5.4.15": return "BUSINESSCATEGORY"
        case "2.5.4.17": return "POSTALCODE"
        case "2.5.4.42": return "GIVENNAME"
        case "2.5.4.43": return "INITIALS"
        case "2.5.4.44": return "GENERATIONQUALIFIER"
        case "2.5.4.46": return "DNQUALIFIER"
        case "2.5.4.65": return "PSEUDONYM"
        case "1.2.840.113549.1.9.1": return "EMAILADDRESS" // Email (PKCS#9)
        default:
            return oid
        }
    }
    
    /// Format a Distinguished Name for display
    public static func formatDN(_ name: X509Name) -> String {
        var parts: [String] = []
        for attr in name.attributes {
            let attrName = dnAttributeName(for: attr.oid)
            parts.append("\(attrName)=\(attr.value)")
        }
        return parts.isEmpty ? "<empty>" : parts.joined(separator: ", ")
    }
    
    /// Format a Distinguished Name with attribute breakdown
    public static func formatDNDetailed(_ name: X509Name) -> [(name: String, value: String)] {
        return name.attributes.map { attr in
            (name: dnAttributeName(for: attr.oid), value: attr.value)
        }
    }
    
    // MARK: - Public Key Details
    
    /// Extract public key details from subjectPublicKeyBits
    public static func publicKeyDetails(algorithmOID: String?, keyBits: Data?) -> (type: String, curve: String?, keySize: Int?) {
        guard let algOID = algorithmOID, let bits = keyBits else {
            return (type: "Unknown", curve: nil, keySize: nil)
        }
        
        if algOID == "1.2.840.10045.2.1" {
            // EC public key - try to extract curve and key size
            // EC public key is typically 0x04 || x || y (uncompressed point)
            if bits.count >= 1 && bits[0] == 0x04 {
                let keySize = (bits.count - 1) / 2
                // P-256 = 32 bytes per coordinate = 64 bytes total + 1 byte prefix = 65 bytes
                // P-384 = 48 bytes per coordinate = 96 bytes total + 1 byte prefix = 97 bytes
                // P-521 = 66 bytes per coordinate = 132 bytes total + 1 byte prefix = 133 bytes
                let curve: String?
                switch keySize {
                case 32: curve = "P-256 (secp256r1)"
                case 48: curve = "P-384 (secp384r1)"
                case 66: curve = "P-521 (secp521r1)"
                default: curve = "Unknown curve (key size: \(keySize) bytes)"
                }
                return (type: "EC", curve: curve, keySize: keySize * 8) // Convert to bits
            }
            return (type: "EC", curve: "Unknown format", keySize: nil)
        } else if algOID == "1.2.840.113549.1.1.1" {
            // RSA public key - key size is typically in the modulus
            // This is a simplified extraction
            return (type: "RSA", curve: nil, keySize: bits.count * 8) // Rough estimate
        }
        
        return (type: "Unknown", curve: nil, keySize: nil)
    }
    
    // MARK: - Validity Duration
    
    /// Calculate validity duration in days
    public static func validityDurationDays(notBefore: Date, notAfter: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: notBefore, to: notAfter)
        return components.day ?? 0
    }
}
