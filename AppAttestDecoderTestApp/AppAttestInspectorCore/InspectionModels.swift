//
//  InspectionModels.swift
//  AppAttestInspectorCore
//
//  Models for App Attest inspection results and context.
//

import Foundation
import AppAttestCore

// MARK: - Input Encoding

public enum InputEncoding {
    case base64
    case base64URL
    case hex
    case raw
}

// MARK: - Inspection Context

/// External context that may be required for full inspection
public struct InspectionContext {
    /// Key ID (Base64) for context lookup
    public let keyID: String?
    
    /// Client data hash (32 bytes) for assertion verification context
    public let clientDataHash: Data?
    
    /// Public key (raw bytes) for signature verification
    public let publicKey: Data?
    
    public init(keyID: String? = nil, clientDataHash: Data? = nil, publicKey: Data? = nil) {
        self.keyID = keyID
        self.clientDataHash = clientDataHash
        self.publicKey = publicKey
    }
}

// MARK: - Inspector Warning

/// Warning about inspection results (inconsistencies, missing context, etc.)
public struct InspectorWarning: Equatable {
    public let message: String
    public let severity: Severity
    
    public enum Severity: Equatable {
        case info
        case warning
        case error
    }
    
    public init(_ message: String, severity: Severity = .warning) {
        self.message = message
        self.severity = severity
    }
}

// MARK: - Parsed Authenticator Data

/// Normalized parsed authenticator data with flag sanity checking
public struct ParsedAuthData {
    public let authenticatorData: AuthenticatorData
    public let rawBytes: Data
    public let warnings: [InspectorWarning]
    public let attestedCredentialDataPresent: Bool
    public let extensionsPresent: Bool
    public let hasATFlag: Bool
    public let hasATPayload: Bool
    public let hasEDFlag: Bool
    public let hasEDPayload: Bool
    
    internal init(
        authenticatorData: AuthenticatorData,
        rawBytes: Data,
        warnings: [InspectorWarning],
        attestedCredentialDataPresent: Bool,
        extensionsPresent: Bool,
        hasATFlag: Bool,
        hasATPayload: Bool,
        hasEDFlag: Bool,
        hasEDPayload: Bool
    ) {
        self.authenticatorData = authenticatorData
        self.rawBytes = rawBytes
        self.warnings = warnings
        self.attestedCredentialDataPresent = attestedCredentialDataPresent
        self.extensionsPresent = extensionsPresent
        self.hasATFlag = hasATFlag
        self.hasATPayload = hasATPayload
        self.hasEDFlag = hasEDFlag
        self.hasEDPayload = hasEDPayload
    }
    
    /// Create from AuthenticatorData and raw bytes (for backward compatibility)
    internal static func from(_ authData: AuthenticatorData, rawBytes: Data) -> ParsedAuthData {
        let length = rawBytes.count
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
            rawBytes: rawBytes,
            warnings: warnings,
            attestedCredentialDataPresent: attestedCredentialDataPresent,
            extensionsPresent: extensionsPresent,
            hasATFlag: hasATFlag,
            hasATPayload: hasATPayload,
            hasEDFlag: hasEDFlag,
            hasEDPayload: hasEDPayload
        )
    }
}

// MARK: - Virtual COSE Envelope

/// Virtual COSE_Sign1 envelope reconstructed from assertion data
public struct VirtualCOSESign1 {
    public let protectedHeaders: [String: Any]
    public let unprotectedHeaders: [String: Any]
    public let payload: Data?
    public let payloadComponents: (authenticatorData: Data, clientDataHash: Data?)
    public let signature: Data
    public let hasCompletePayload: Bool
    
    /// CBOR-encoded Sig_structure bytes
    public let sigStructureCBOR: Data?
    
    /// SHA256 hash of Sig_structure
    public let sigStructureHash: Data?
    
    internal init(
        protectedHeaders: [String: Any],
        unprotectedHeaders: [String: Any],
        payload: Data?,
        payloadComponents: (authenticatorData: Data, clientDataHash: Data?),
        signature: Data,
        hasCompletePayload: Bool,
        sigStructureCBOR: Data?,
        sigStructureHash: Data?
    ) {
        self.protectedHeaders = protectedHeaders
        self.unprotectedHeaders = unprotectedHeaders
        self.payload = payload
        self.payloadComponents = payloadComponents
        self.signature = signature
        self.hasCompletePayload = hasCompletePayload
        self.sigStructureCBOR = sigStructureCBOR
        self.sigStructureHash = sigStructureHash
    }
}

// MARK: - Inspection Result

/// Complete inspection result for an App Attest artifact
nonisolated public struct InspectionResult {
    /// Type of artifact inspected
    nonisolated public enum ArtifactType {
        case attestation
        case assertion
        case unknown
    }
    
    /// Decode status
    nonisolated public enum DecodeStatus: Equatable {
        case success
        case partial(reason: String)
        case failed(error: String)
    }
    
    /// Raw input data
    public let rawData: Data
    
    /// Detected artifact type
    public let artifactType: ArtifactType
    
    /// Decode status
    public let decodeStatus: DecodeStatus
    
    /// Parsed CBOR structure
    public let cborValue: CBORValue?
    
    /// Parsed authenticator data (if available)
    public let parsedAuthData: ParsedAuthData?
    
    /// Authenticator data raw bytes (if parsing failed)
    public let authenticatorDataBytes: Data?
    
    /// Signature bytes
    public let signatureBytes: Data?
    
    /// Virtual COSE envelope (for assertions)
    public let virtualCOSE: VirtualCOSESign1?
    
    /// All warnings generated during inspection
    public let warnings: [InspectorWarning]
    
    /// Missing context requirements
    public let missingContext: [String]
    
    /// Whether full inspection is possible with current context
    public let canFullyInspect: Bool
    
    nonisolated public init(
        rawData: Data,
        artifactType: ArtifactType,
        decodeStatus: DecodeStatus,
        cborValue: CBORValue?,
        parsedAuthData: ParsedAuthData?,
        authenticatorDataBytes: Data?,
        signatureBytes: Data?,
        virtualCOSE: VirtualCOSESign1?,
        warnings: [InspectorWarning],
        missingContext: [String],
        canFullyInspect: Bool
    ) {
        self.rawData = rawData
        self.artifactType = artifactType
        self.decodeStatus = decodeStatus
        self.cborValue = cborValue
        self.parsedAuthData = parsedAuthData
        self.authenticatorDataBytes = authenticatorDataBytes
        self.signatureBytes = signatureBytes
        self.virtualCOSE = virtualCOSE
        self.warnings = warnings
        self.missingContext = missingContext
        self.canFullyInspect = canFullyInspect
    }
}
