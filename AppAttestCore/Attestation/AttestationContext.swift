//
//  AttestationContext.swift
//  AppAttestCore
//
//  This file defines execution context types for App Attest research.
//  It enables comparison of App Attest artifacts across different iOS execution contexts
//  (main app, extensions) while maintaining research-grade isolation.
//
//  This is a research tool. It does not validate trust or make security claims.
//  Context annotation is metadata only; the attestation structure remains identical.
//

import Foundation

/// Execution context where an App Attest artifact was generated.
/// Used for research and comparison of artifacts across different iOS execution contexts.
/// 
/// **Important**: Apple App Attest does NOT define separate attestation formats for extensions.
/// Extensions share the same App ID prefix and Team ID as the container app.
/// The attestation object structure is identical across all contexts.
/// 
/// This enum is for research purposes only - to study where trust signals originate,
/// not to imply different cryptographic guarantees.
public enum AttestationContext: String, Codable, CaseIterable {
    /// Main application execution context
    case mainApp = "main"
    
    /// Action extension execution context
    case actionExtension = "action"
    
    /// UI extension execution context
    case uiExtension = "ui"
    
    /// App SSO extension execution context
    case appSSOExtension = "sso"
    
    /// Other extension types (e.g., notification service, widget)
    case otherExtension = "other"
    
    /// Human-readable description of the context
    public var description: String {
        switch self {
        case .mainApp:
            return "Main Application"
        case .actionExtension:
            return "Action Extension"
        case .uiExtension:
            return "UI Extension"
        case .appSSOExtension:
            return "App SSO Extension"
        case .otherExtension:
            return "Other Extension"
        }
    }
}

/// A decoded App Attest attestation sample with execution context metadata.
/// 
/// This model wraps a decoded attestation object with research metadata to enable
/// comparison across different iOS execution contexts.
/// 
/// **Research Use**: This enables studying:
/// - RP ID hash consistency across contexts
/// - Certificate chain characteristics
/// - Authenticator flags patterns
/// - Key reuse vs regeneration behavior
/// - Timing differences (if available)
/// 
/// **Important**: This does NOT validate trust or make security claims.
/// All validation must be performed separately.
public struct AttestationSample: Codable {
    /// Execution context where this attestation was generated
    public let context: AttestationContext
    
    /// Bundle identifier of the app/extension
    public let bundleID: String
    
    /// Apple Team ID
    public let teamID: String
    
    /// App Attest key ID (base64-encoded)
    public let keyID: String
    
    /// Base64-encoded attestation object (original artifact)
    public let attestationObjectBase64: String
    
    /// Timestamp when the attestation was generated
    public let timestamp: Date
    
    /// Decoded attestation object (parsed structure)
    /// This is computed on-demand and not stored in the Codable representation
    public var attestationObject: AttestationObject? {
        guard let data = Data(base64Encoded: attestationObjectBase64) else {
            return nil
        }
        return try? AppAttestDecoder(teamID: teamID).decodeAttestation(data)
    }
    
    /// Initialize an AttestationSample from raw data
    /// - Parameters:
    ///   - context: Execution context where attestation was generated
    ///   - bundleID: Bundle identifier
    ///   - teamID: Apple Team ID
    ///   - keyID: App Attest key ID (base64-encoded)
    ///   - attestationObjectBase64: Base64-encoded attestation object
    ///   - timestamp: When the attestation was generated (defaults to now)
    public init(
        context: AttestationContext,
        bundleID: String,
        teamID: String,
        keyID: String,
        attestationObjectBase64: String,
        timestamp: Date = Date()
    ) {
        self.context = context
        self.bundleID = bundleID
        self.teamID = teamID
        self.keyID = keyID
        self.attestationObjectBase64 = attestationObjectBase64
        self.timestamp = timestamp
    }
    
    /// Initialize from decoded attestation object
    /// - Parameters:
    ///   - context: Execution context
    ///   - bundleID: Bundle identifier
    ///   - teamID: Apple Team ID
    ///   - keyID: App Attest key ID (base64-encoded)
    ///   - attestationObject: Decoded attestation object
    ///   - rawData: Original raw bytes (must match attestationObject)
    ///   - timestamp: When generated (defaults to now)
    public init?(
        context: AttestationContext,
        bundleID: String,
        teamID: String,
        keyID: String,
        attestationObject: AttestationObject,
        rawData: Data,
        timestamp: Date = Date()
    ) {
        self.context = context
        self.bundleID = bundleID
        self.teamID = teamID
        self.keyID = keyID
        self.attestationObjectBase64 = rawData.base64EncodedString()
        self.timestamp = timestamp
    }
}

/// Analysis results comparing multiple AttestationSample entries
public struct AttestationComparison: Codable {
    /// All samples being compared
    public let samples: [AttestationSample]
    
    /// RP ID hash values across all samples (should be consistent for same bundle ID)
    public let rpIdHashes: [AttestationContext: Data]
    
    /// Certificate chain lengths across contexts
    public let certificateChainLengths: [AttestationContext: Int]
    
    /// Authenticator flags across contexts
    public let flags: [AttestationContext: AuthenticatorData.Flags]
    
    /// Whether all samples share the same RP ID hash (expected for same bundle ID)
    public var rpIdHashConsistent: Bool {
        let hashes = rpIdHashes.values
        guard let first = hashes.first else { return true }
        return hashes.allSatisfy { $0 == first }
    }
    
    /// Whether certificate chain lengths are consistent
    public var certificateChainLengthConsistent: Bool {
        let lengths = certificateChainLengths.values
        guard let first = lengths.first else { return true }
        return lengths.allSatisfy { $0 == first }
    }
    
    /// Coding keys for Codable conformance
    enum CodingKeys: String, CodingKey {
        case samples
        case rpIdHashes
        case certificateChainLengths
        case flags
        case rpIdHashConsistent
        case certificateChainLengthConsistent
    }
    
    public init(samples: [AttestationSample]) throws {
        self.samples = samples
        
        var rpIdHashes: [AttestationContext: Data] = [:]
        var chainLengths: [AttestationContext: Int] = [:]
        var flags: [AttestationContext: AuthenticatorData.Flags] = [:]
        
        for sample in samples {
            guard let attestation = sample.attestationObject else {
                continue
            }
            
            rpIdHashes[sample.context] = attestation.authenticatorData.rpIdHash
            chainLengths[sample.context] = attestation.attestationStatement.certificates.count
            flags[sample.context] = attestation.authenticatorData.flags
        }
        
        self.rpIdHashes = rpIdHashes
        self.certificateChainLengths = chainLengths
        self.flags = flags
    }
    
    // Custom Codable implementation to handle Dictionary keys
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        samples = try container.decode([AttestationSample].self, forKey: .samples)
        
        // Decode dictionaries with string keys, then convert to AttestationContext keys
        let rpIdHashStrings = try container.decode([String: Data].self, forKey: .rpIdHashes)
        rpIdHashes = Dictionary(uniqueKeysWithValues: rpIdHashStrings.compactMap { key, value in
            guard let context = AttestationContext(rawValue: key) else { return nil }
            return (context, value)
        })
        
        let chainLengthStrings = try container.decode([String: Int].self, forKey: .certificateChainLengths)
        certificateChainLengths = Dictionary(uniqueKeysWithValues: chainLengthStrings.compactMap { key, value in
            guard let context = AttestationContext(rawValue: key) else { return nil }
            return (context, value)
        })
        
        let flagsStrings = try container.decode([String: AuthenticatorData.Flags].self, forKey: .flags)
        flags = Dictionary(uniqueKeysWithValues: flagsStrings.compactMap { key, value in
            guard let context = AttestationContext(rawValue: key) else { return nil }
            return (context, value)
        })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(samples, forKey: .samples)
        
        // Encode dictionaries with string keys
        let rpIdHashStrings = Dictionary(uniqueKeysWithValues: rpIdHashes.map { ($0.key.rawValue, $0.value) })
        try container.encode(rpIdHashStrings, forKey: .rpIdHashes)
        
        let chainLengthStrings = Dictionary(uniqueKeysWithValues: certificateChainLengths.map { ($0.key.rawValue, $0.value) })
        try container.encode(chainLengthStrings, forKey: .certificateChainLengths)
        
        let flagsStrings = Dictionary(uniqueKeysWithValues: flags.map { ($0.key.rawValue, $0.value) })
        try container.encode(flagsStrings, forKey: .flags)
        
        try container.encode(rpIdHashConsistent, forKey: .rpIdHashConsistent)
        try container.encode(certificateChainLengthConsistent, forKey: .certificateChainLengthConsistent)
    }
}

