//
//  AppAttestInspector.swift
//  AppAttestInspectorCore
//
//  Core inspection logic for App Attest artifacts.
//  No UI dependencies. Returns structured data only.
//

import Foundation
import AppAttestCore
import CryptoKit

public enum InspectionError: Error, CustomStringConvertible {
    case invalidCBOR
    case invalidInput
    case unsupportedArtifactType
    
    public var description: String {
        switch self {
        case .invalidCBOR:
            return "Invalid CBOR encoding"
        case .invalidInput:
            return "Invalid input data"
        case .unsupportedArtifactType:
            return "Unsupported artifact type"
        }
    }
}

public struct AppAttestInspector {
    
    /// Inspect an App Attest artifact (attestation or assertion)
    /// - Parameters:
    ///   - data: Raw artifact bytes
    ///   - context: Optional external context (keyID, clientDataHash, publicKey)
    /// - Returns: InspectionResult with all decoded and reconstructed data
    /// - Throws: InspectionError if input is invalid
    nonisolated public static func inspect(
        data: Data,
        context: InspectionContext? = nil
    ) throws -> InspectionResult {
        guard !data.isEmpty else {
            throw InspectionError.invalidInput
        }
        
        // Decode CBOR
        let cborValue: CBORValue
        do {
            cborValue = try CBORDecoder.decode(data)
        } catch {
            throw InspectionError.invalidCBOR
        }
        
        // Detect artifact type and extract fields
        var artifactType: InspectionResult.ArtifactType = .unknown
        var authenticatorDataBytes: Data?
        var signatureBytes: Data?
        var warnings: [InspectorWarning] = []
        var missingContext: [String] = []
        
        // Try to detect assertion (CBOR map with authenticatorData and signature)
        if case .map(let map) = cborValue {
            var foundAuthData = false
            var foundSignature = false
            
            for (key, value) in map {
                if case .textString("authenticatorData") = key,
                   case .byteString(let bytes) = value {
                    authenticatorDataBytes = bytes
                    foundAuthData = true
                }
                if case .textString("signature") = key,
                   case .byteString(let bytes) = value {
                    signatureBytes = bytes
                    foundSignature = true
                }
            }
            
            if foundAuthData && foundSignature {
                artifactType = .assertion
            }
        }
        
        // Try to detect attestation (CBOR map with fmt, authData, attStmt)
        if artifactType == .unknown,
           case .map(let map) = cborValue {
            var hasFmt = false
            var hasAuthData = false
            var hasAttStmt = false
            
            for (key, _) in map {
                if case .textString("fmt") = key { hasFmt = true }
                if case .textString("authData") = key { hasAuthData = true }
                if case .textString("attStmt") = key { hasAttStmt = true }
            }
            
            if hasFmt && hasAuthData && hasAttStmt {
                artifactType = .attestation
                // For attestations, extract authData from the map
                for (key, value) in map {
                    if case .textString("authData") = key,
                       case .byteString(let bytes) = value {
                        authenticatorDataBytes = bytes
                    }
                }
            }
        }
        
        // Parse authenticator data
        var parsedAuthData: ParsedAuthData?
        if let authDataBytes = authenticatorDataBytes {
            parsedAuthData = parseAuthenticatorData(authDataBytes)
            if let parsed = parsedAuthData {
                warnings.append(contentsOf: parsed.warnings)
            }
        }
        
        // Reconstruct virtual COSE for assertions
        var virtualCOSE: VirtualCOSESign1?
        if artifactType == .assertion,
           let authDataBytes = authenticatorDataBytes,
           let sigBytes = signatureBytes {
            virtualCOSE = reconstructVirtualCOSE(
                authenticatorData: authDataBytes,
                signature: sigBytes,
                clientDataHash: context?.clientDataHash
            )
            
            // Check for missing context
            if context?.clientDataHash == nil {
                missingContext.append("clientDataHash (required for full payload reconstruction)")
            }
            if context?.publicKey == nil {
                missingContext.append("publicKey (required for signature verification)")
            }
        }
        
        // Determine decode status
        let decodeStatus: InspectionResult.DecodeStatus
        if parsedAuthData != nil && signatureBytes != nil {
            decodeStatus = .success
        } else if authenticatorDataBytes != nil || signatureBytes != nil {
            decodeStatus = .partial(reason: "Some fields extracted but parsing incomplete")
        } else {
            decodeStatus = .failed(error: "Could not extract authenticatorData or signature")
        }
        
        let canFullyInspect = missingContext.isEmpty && 
            (decodeStatus == .success)
        
        return InspectionResult(
            rawData: data,
            artifactType: artifactType,
            decodeStatus: decodeStatus,
            cborValue: cborValue,
            parsedAuthData: parsedAuthData,
            authenticatorDataBytes: authenticatorDataBytes,
            signatureBytes: signatureBytes,
            virtualCOSE: virtualCOSE,
            warnings: warnings,
            missingContext: missingContext,
            canFullyInspect: canFullyInspect
        )
    }
    
    // MARK: - Authenticator Data Parsing
    
    /// Parse authenticator data with flag sanity checking
    /// Makes length authoritative, not flags
    nonisolated private static func parseAuthenticatorData(_ bytes: Data) -> ParsedAuthData? {
        guard let authData = try? AuthenticatorData(rawData: bytes) else {
            return nil
        }
        
        let length = bytes.count
        let hasATFlag = authData.flags.attestedCredentialData
        let hasATPayload = length > 37
        let hasEDFlag = authData.flags.extensionsIncluded
        let hasEDPayload = length > 37 && authData.extensions != nil
        
        let attestedCredentialDataPresent = hasATFlag && hasATPayload
        let extensionsPresent = hasEDFlag && hasEDPayload
        
        var warnings: [InspectorWarning] = []
        if hasATFlag && !hasATPayload {
            warnings.append(InspectorWarning(
                "AT flag set but attested credential data not present. Treating authenticatorData as assertion-only structure."
            ))
        }
        if hasEDFlag && !hasEDPayload {
            warnings.append(InspectorWarning(
                "ED flag set but extensions not present."
            ))
        }
        
        return ParsedAuthData(
            authenticatorData: authData,
            rawBytes: bytes,
            warnings: warnings,
            attestedCredentialDataPresent: attestedCredentialDataPresent,
            extensionsPresent: extensionsPresent,
            hasATFlag: hasATFlag,
            hasATPayload: hasATPayload,
            hasEDFlag: hasEDFlag,
            hasEDPayload: hasEDPayload
        )
    }
    
    // MARK: - Virtual COSE Reconstruction
    
    /// Reconstruct virtual COSE envelope from assertion data
    nonisolated private static func reconstructVirtualCOSE(
        authenticatorData: Data,
        signature: Data,
        clientDataHash: Data? = nil
    ) -> VirtualCOSESign1 {
        // Protected headers: alg = ES256 (-7)
        let protectedHeaders: [String: Any] = ["alg": -7]  // ES256
        
        // Unprotected headers: empty
        let unprotectedHeaders: [String: Any] = [:]
        
        // Payload: authenticatorData || clientDataHash
        let payload: Data?
        let hasCompletePayload: Bool
        if let clientDataHash = clientDataHash {
            payload = authenticatorData + clientDataHash
            hasCompletePayload = true
        } else {
            payload = nil
            hasCompletePayload = false
        }
        
        // Build Sig_structure and compute hash
        let (sigStructureCBOR, sigStructureHash) = buildSigStructure(
            protectedHeaders: protectedHeaders,
            payload: payload
        )
        
        return VirtualCOSESign1(
            protectedHeaders: protectedHeaders,
            unprotectedHeaders: unprotectedHeaders,
            payload: payload,
            payloadComponents: (authenticatorData: authenticatorData, clientDataHash: clientDataHash),
            signature: signature,
            hasCompletePayload: hasCompletePayload,
            sigStructureCBOR: sigStructureCBOR,
            sigStructureHash: sigStructureHash
        )
    }
    
    /// Build COSE_Sign1 Sig_structure and compute SHA256 hash
    private static func buildSigStructure(
        protectedHeaders: [String: Any],
        payload: Data?
    ) -> (cbor: Data?, hash: Data?) {
        guard let payload = payload else {
            return (nil, nil)
        }
        
        // Encode protected headers: {1: -7} (alg: ES256)
        // CBOR map with 1 item: 0xa1 (map(1)) || 0x01 (unsigned 1) || 0x26 (negative -7)
        var protectedHeadersCBOR = Data()
        protectedHeadersCBOR.append(0xa1) // map(1)
        protectedHeadersCBOR.append(0x01)  // unsigned(1) - key
        protectedHeadersCBOR.append(0x26)  // negative(-7) - value (ES256)
        
        // Build Sig_structure array: ["Signature1", protected, external_aad, payload]
        var sigStructureCBOR = Data()
        sigStructureCBOR.append(0x84) // array(4)
        
        // Item 0: "Signature1" (text string, 10 bytes)
        sigStructureCBOR.append(0x6a) // text string(10)
        sigStructureCBOR.append("Signature1".data(using: .utf8)!)
        
        // Item 1: protected (byte string, 3 bytes)
        sigStructureCBOR.append(0x43) // byte string(3)
        sigStructureCBOR.append(protectedHeadersCBOR)
        
        // Item 2: external_aad (byte string, 0 bytes)
        sigStructureCBOR.append(0x40) // byte string(0)
        
        // Item 3: payload (byte string, variable length)
        if payload.count < 24 {
            sigStructureCBOR.append(0x40 + UInt8(payload.count)) // byte string(N) where N < 24
        } else if payload.count < 256 {
            sigStructureCBOR.append(0x58) // byte string, 1-byte length follows
            sigStructureCBOR.append(UInt8(payload.count))
        } else if payload.count < 65536 {
            sigStructureCBOR.append(0x59) // byte string, 2-byte length follows
            let lengthBytes = withUnsafeBytes(of: UInt16(payload.count).bigEndian) { Data($0) }
            sigStructureCBOR.append(lengthBytes)
        } else {
            sigStructureCBOR.append(0x5a) // byte string, 4-byte length follows
            let lengthBytes = withUnsafeBytes(of: UInt32(payload.count).bigEndian) { Data($0) }
            sigStructureCBOR.append(lengthBytes)
        }
        sigStructureCBOR.append(payload)
        
        let sigStructureHash = Data(SHA256.hash(data: sigStructureCBOR))
        
        return (sigStructureCBOR, sigStructureHash)
    }
}
