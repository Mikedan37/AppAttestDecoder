//
//  ForensicJSONEncoder.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/14/26.
//
//  Lossless JSON encoder for forensic export
//  Every field includes: path, type, raw, decoded (optional), encoding, length
//

import Foundation

/// Lossless JSON representation for forensic export
public struct ForensicJSONEncoder {
    
    /// Encode attestation object to lossless JSON
    public static func encode(_ attestation: AttestationObject) -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Top-level metadata
        json["type"] = "attestation"
        json["format"] = attestation.format
        
        // Raw CBOR
        if let rawData = attestation.rawData {
            json["rawCBOR"] = [
                "base64": rawData.base64EncodedString(),
                "length": rawData.count,
                "hex": formatHex(rawData)
            ]
        }
        
        // Authenticator Data
        json["authenticatorData"] = encodeAuthenticatorData(attestation.authenticatorData)
        
        // Attestation Statement
        json["attestationStatement"] = encodeAttStmt(attestation.attestationStatement)
        
        return json
    }
    
    // MARK: - Authenticator Data
    
    private static func encodeAuthenticatorData(_ authData: AuthenticatorData) -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Raw bytes
        json["raw"] = [
            "base64": authData.rawData.base64EncodedString(),
            "length": authData.rawData.count,
            "hex": formatHex(authData.rawData)
        ]
        
        // RP ID Hash
        json["rpIdHash"] = encodeDataField(authData.rpIdHash, encoding: "SHA256(bundleID)")
        
        // Flags
        var flags: [String: Any] = [:]
        flags["raw"] = [
            "byte": authData.flags.rawValue,
            "hex": String(format: "0x%02x", authData.flags.rawValue)
        ]
        flags["decoded"] = [
            "userPresent": authData.flags.userPresent,
            "userVerified": authData.flags.userVerified,
            "attestedCredentialData": authData.flags.attestedCredentialData,
            "extensionsIncluded": authData.flags.extensionsIncluded
        ]
        json["flags"] = flags
        
        // Sign Count
        json["signCount"] = authData.signCount
        
        // Attested Credential Data
        if let credData = authData.attestedCredentialData {
            json["attestedCredentialData"] = encodeAttestedCredentialData(credData)
        } else {
            json["attestedCredentialData"] = NSNull()
        }
        
        // Extensions
        if let extensions = authData.extensions {
            json["extensions"] = encodeCBORValue(extensions, path: "authenticatorData.extensions")
        } else {
            json["extensions"] = NSNull()
        }
        
        return json
    }
    
    private static func encodeAttestedCredentialData(_ credData: AttestedCredentialData) -> [String: Any] {
        var json: [String: Any] = [:]
        
        json["aaguid"] = encodeDataField(credData.aaguid)
        json["credentialId"] = encodeDataField(credData.credentialId)
        json["credentialPublicKey"] = encodeCBORValue(credData.credentialPublicKey, path: "authenticatorData.attestedCredentialData.credentialPublicKey")
        
        return json
    }
    
    // MARK: - Attestation Statement
    
    private static func encodeAttStmt(_ attStmt: AttStmt) -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Algorithm
        if let alg = attStmt.alg {
            json["alg"] = [
                "value": alg,
                "name": "ES256"
            ]
        } else {
            json["alg"] = NSNull()
        }
        
        // Signature (opaque)
        if !attStmt.signature.isEmpty {
            json["signature"] = [
                "base64": attStmt.signature.base64EncodedString(),
                "length": attStmt.signature.count,
                "hex": formatHex(attStmt.signature),
                "encoding": "DER-encoded ECDSA",
                "opaque": true
            ]
        } else {
            json["signature"] = [
                "length": 0,
                "opaque": false
            ]
        }
        
        // Certificate Chain
        var certificates: [[String: Any]] = []
        for (index, certDER) in attStmt.x5c.enumerated() {
            let role = index == 0 ? "leaf" : index == attStmt.x5c.count - 1 ? "root" : "intermediate"
            var certJSON: [String: Any] = [
                "index": index,
                "role": role
            ]
            
            // Raw DER
            certJSON["rawDER"] = [
                "base64": certDER.base64EncodedString(),
                "length": certDER.count,
                "hex": formatHex(certDER)
            ]
            
            // Try to parse
            if let cert = try? X509Certificate.parse(der: certDER) {
                certJSON["parsed"] = encodeCertificate(cert)
            } else {
                certJSON["parseError"] = "Failed to parse certificate"
            }
            
            certificates.append(certJSON)
        }
        json["x5c"] = certificates
        
        // Raw CBOR structure
        json["rawCBOR"] = encodeCBORValue(attStmt.rawCBOR, path: "attestationStatement.rawCBOR")
        
        return json
    }
    
    // MARK: - Certificate
    
    private static func encodeCertificate(_ cert: X509Certificate) -> [String: Any] {
        var json: [String: Any] = [:]
        
        // Subject
        var subject: [String: Any] = [:]
        for attr in cert.subject.attributes {
            subject[attr.oid] = attr.value
        }
        json["subject"] = subject
        
        // Issuer
        var issuer: [String: Any] = [:]
        for attr in cert.issuer.attributes {
            issuer[attr.oid] = attr.value
        }
        json["issuer"] = issuer
        
        // Serial Number
        json["serialNumber"] = encodeDataField(cert.serialNumber)
        
        // Validity
        let formatter = ISO8601DateFormatter()
        json["validity"] = [
            "notBefore": formatter.string(from: cert.validity.notBefore),
            "notAfter": formatter.string(from: cert.validity.notAfter)
        ]
        
        // Signature Algorithm
        json["signatureAlgorithm"] = cert.signatureAlgorithmOID
        
        // Subject Public Key Info
        if let spkiAlg = cert.subjectPublicKeyAlgorithmOID {
            json["subjectPublicKeyAlgorithm"] = spkiAlg
        }
        if let spkiBits = cert.subjectPublicKeyBits {
            json["subjectPublicKeyBits"] = encodeDataField(spkiBits)
        }
        
        // Extensions
        var extensions: [[String: Any]] = []
        let decodedExts = cert.decodedExtensions
        for (oid, ext) in decodedExts.sorted(by: { $0.key < $1.key }) {
            var extJSON: [String: Any] = [:]
            extJSON["oid"] = oid
            extJSON["name"] = X509OID.name(for: oid)
            
            // Raw DER
            if let rawDER = cert.extensions[oid] {
                extJSON["rawDER"] = [
                    "base64": rawDER.base64EncodedString(),
                    "length": rawDER.count,
                    "hex": formatHex(rawDER)
                ]
            }
            
            // Decoded value
            extJSON["decoded"] = encodeExtension(ext)
            
            extensions.append(extJSON)
        }
        json["extensions"] = extensions
        
        return json
    }
    
    // MARK: - Extension
    
    private static func encodeExtension(_ ext: X509Extension) -> [String: Any] {
        var json: [String: Any] = [:]
        
        switch ext {
        case .basicConstraints(let isCA, let pathLength):
            json["type"] = "basicConstraints"
            json["isCA"] = isCA
            if let pathLength = pathLength {
                json["pathLengthConstraint"] = pathLength
            }
            
        case .keyUsage(let usages):
            json["type"] = "keyUsage"
            json["usages"] = usages.map { $0.name }
            
        case .extendedKeyUsage(let usages):
            json["type"] = "extendedKeyUsage"
            json["usages"] = usages.map { $0.name }
            
        case .appleOID(_, let appleExt):
            json["type"] = "appleOID"
            json["appleExtension"] = encodeAppleExtension(appleExt)
            
        case .unknown(_, let raw):
            json["type"] = "unknown"
            json["opaque"] = true
            json["raw"] = [
                "base64": raw.base64EncodedString(),
                "length": raw.count,
                "hex": formatHex(raw)
            ]
        }
        
        return json
    }
    
    private static func encodeAppleExtension(_ appleExt: AppleAppAttestExtension) -> [String: Any] {
        var json: [String: Any] = [:]
        
        json["oid"] = appleExt.oid
        json["rawValue"] = [
            "base64": appleExt.rawValue.base64EncodedString(),
            "length": appleExt.rawValue.count,
            "hex": formatHex(appleExt.rawValue)
        ]
        
        switch appleExt.type {
        case .challenge(let hash):
            json["extensionType"] = "challenge"
            json["hash"] = encodeDataField(hash, encoding: "SHA256")
            
        case .receipt(let receipt):
            json["extensionType"] = "receipt"
            var receiptJSON: [String: Any] = [:]
            if let bundleID = receipt.bundleID {
                receiptJSON["bundleID"] = bundleID
            }
            if let teamID = receipt.teamID {
                receiptJSON["teamID"] = teamID
            }
            if let appVersion = receipt.appVersion {
                receiptJSON["appVersion"] = appVersion
            }
            if let creationDate = receipt.receiptCreationDate {
                receiptJSON["receiptCreationDate"] = ISO8601DateFormatter().string(from: creationDate)
            }
            if let expirationDate = receipt.receiptExpirationDate {
                receiptJSON["receiptExpirationDate"] = ISO8601DateFormatter().string(from: expirationDate)
            }
            // Raw CBOR structure
            receiptJSON["rawCBOR"] = encodeCBORValue(receipt.rawCBOR, path: "receipt.rawCBOR")
            json["receipt"] = receiptJSON
            
        case .keyPurpose(let purpose):
            json["extensionType"] = "keyPurpose"
            json["purpose"] = purpose
            
        case .environment(let env):
            json["extensionType"] = "environment"
            json["value"] = env
            
        case .osVersion(let version):
            json["extensionType"] = "osVersion"
            json["value"] = version
            
        case .deviceClass(let deviceClass):
            json["extensionType"] = "deviceClass"
            json["value"] = deviceClass
            
        case .unknown(_, let raw):
            json["extensionType"] = "unknown"
            json["opaque"] = true
            json["raw"] = encodeDataField(raw)
        }
        
        return json
    }
    
    // MARK: - CBOR Value
    
    private static func encodeCBORValue(_ value: CBORValue, path: String) -> [String: Any] {
        var json: [String: Any] = [:]
        json["path"] = path
        
        switch value {
        case .unsigned(let u):
            json["type"] = "unsigned"
            json["value"] = u
            
        case .negative(let n):
            json["type"] = "negative"
            json["value"] = n
            
        case .byteString(let data):
            json["type"] = "byteString"
            json["value"] = encodeDataField(data)
            
        case .textString(let s):
            json["type"] = "textString"
            json["value"] = s
            
        case .array(let arr):
            json["type"] = "array"
            json["length"] = arr.count
            var elements: [[String: Any]] = []
            for (index, elem) in arr.enumerated() {
                elements.append(encodeCBORValue(elem, path: "\(path)[\(index)]"))
            }
            json["elements"] = elements
            
        case .map(let pairs):
            json["type"] = "map"
            json["length"] = pairs.count
            var mapPairs: [[String: Any]] = []
            for (key, val) in pairs {
                let keyStr = keyDescription(key)
                var pair: [String: Any] = [:]
                pair["key"] = encodeCBORValue(key, path: "\(path).key")
                pair["value"] = encodeCBORValue(val, path: "\(path).\(keyStr)")
                mapPairs.append(pair)
            }
            json["pairs"] = mapPairs
            
        case .tagged(let tag, let inner):
            json["type"] = "tagged"
            json["tag"] = tag
            json["value"] = encodeCBORValue(inner, path: "\(path).value")
            
        case .simple(let u):
            json["type"] = "simple"
            json["value"] = u
            
        case .boolean(let b):
            json["type"] = "boolean"
            json["value"] = b
            
        case .null:
            json["type"] = "null"
            
        case .undefined:
            json["type"] = "undefined"
        }
        
        return json
    }
    
    // MARK: - Helpers
    
    private static func encodeDataField(_ data: Data, encoding: String? = nil) -> [String: Any] {
        var json: [String: Any] = [:]
        json["base64"] = data.base64EncodedString()
        json["length"] = data.count
        json["hex"] = formatHex(data)
        if let encoding = encoding {
            json["encoding"] = encoding
        }
        return json
    }
    
    private static func formatHex(_ data: Data, bytesPerGroup: Int = 4) -> String {
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
    
    private static func keyDescription(_ key: CBORValue) -> String {
        switch key {
        case .textString(let s): return s
        case .unsigned(let u): return "\(u)"
        case .negative(let n): return "\(n)"
        default: return "\(key)"
        }
    }
}
