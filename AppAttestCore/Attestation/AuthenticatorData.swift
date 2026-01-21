import Foundation

public struct AuthenticatorData {

    // MARK: - Core fields
    
    /// RP ID hash (32 bytes). SHA256 of the relying party identifier (typically bundle ID).
    /// This value is parsed but NOT validated. Consumers must verify it matches expected RP ID.
    public let rpIdHash: Data
    
    /// Authenticator flags byte. Parsed into individual flag properties.
    /// Flags are parsed but NOT interpreted. Consumers must apply their own policy.
    public let flags: Flags
    
    /// Signature counter (4 bytes, big-endian). Monotonically increasing counter.
    /// This value is parsed but NOT validated. Consumers must verify counter increments.
    public let signCount: UInt32

    // MARK: - Optional sections
    
    /// Attested credential data (present if flags.attestedCredentialData is set).
    /// Contains AAGUID, credential ID, and COSE public key. All fields are parsed but NOT validated.
    public let attestedCredentialData: AttestedCredentialData?
    
    /// Extensions (CBOR-encoded). Present if flags.extensionsIncluded is set.
    /// This value is parsed but NOT validated. Consumers must parse and validate extensions separately.
    public let extensions: CBORValue?

    // MARK: - Raw
    
    /// Raw authenticator data bytes as received from the attestation/assertion.
    /// This is the exact byte sequence that validators need for signature verification.
    public let rawData: Data

    public init(rawData: Data, extensions: CBORValue? = nil) throws {
        self.rawData = rawData

        var cursor = 0

        func read(_ length: Int) -> Data {
            precondition(cursor + length <= rawData.count, "AuthenticatorData: out-of-bounds read")
            defer { cursor += length }
            return rawData.subdata(in: cursor ..< cursor + length)
        }

        // rpIdHash (32 bytes)
        self.rpIdHash = read(32)

        // flags (1 byte)
        let flagsByte = read(1)[0]
        self.flags = Flags(rawValue: flagsByte)

        // signCount (4 bytes, big endian)
        let counterData = read(4)
        self.signCount = counterData.withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }

        // attested credential data (if present)
        // For assertions, this flag is typically NOT set (assertions don't include attested credential data)
        // Only attestations include this data
        if flags.attestedCredentialData {
            // Check if we have enough data remaining before attempting to read
            let remainingBytes = rawData.count - cursor
            if remainingBytes > 0 {
                // Try to read attested credential data, but handle gracefully if data is incomplete
                do {
                    self.attestedCredentialData = try AttestedCredentialData(from: rawData, cursor: &cursor)
                } catch {
                    // If reading fails (e.g., incomplete data), set to nil
                    // This can happen with malformed or truncated authenticatorData
                    self.attestedCredentialData = nil
                }
            } else {
                // Flag is set but no data remains - this is invalid, but don't crash
                self.attestedCredentialData = nil
            }
        } else {
            self.attestedCredentialData = nil
        }

        // extensions (decoded separately if needed)
        self.extensions = extensions
    }
}

// MARK: - Flags
extension AuthenticatorData {

    public struct Flags: Equatable, Codable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public var userPresent: Bool { rawValue & 0x01 != 0 }
        public var userVerified: Bool { rawValue & 0x04 != 0 }
        public var attestedCredentialData: Bool { rawValue & 0x40 != 0 }
        public var extensionsIncluded: Bool { rawValue & 0x80 != 0 }
    }
}

// MARK: - Attested Credential Data

/// Attested credential data from authenticator data.
/// All fields are parsed but NOT validated. Consumers must verify AAGUID, credential ID, and public key.
public struct AttestedCredentialData {

    /// AAGUID (16 bytes). Authenticator Attestation Globally Unique Identifier.
    /// This value is parsed but NOT validated. Consumers must verify AAGUID matches expected authenticator.
    public let aaguid: Data
    
    /// Credential ID (variable length). Unique identifier for this credential.
    /// This value is parsed but NOT validated. Consumers must track credential IDs for key management.
    public let credentialId: Data
    
    /// Credential public key (CBOR-encoded COSE key structure).
    /// This value is decoded but NOT validated. Consumers must parse COSE key and verify key type/parameters.
    public let credentialPublicKey: CBORValue

    public init(from data: Data, cursor: inout Int) throws {

        func read(_ length: Int) throws -> Data {
            guard cursor + length <= data.count else {
                throw AuthenticatorDataError.insufficientData(
                    requested: length,
                    available: data.count - cursor,
                    atOffset: cursor
                )
            }
            defer { cursor += length }
            return data.subdata(in: cursor ..< cursor + length)
        }

        // AAGUID (16 bytes)
        self.aaguid = try read(16)

        // Credential ID length (2 bytes, big endian)
        let idLenData = try read(2)
        let idLength = idLenData.withUnsafeBytes {
            $0.load(as: UInt16.self).bigEndian
        }

        // Credential ID
        self.credentialId = try read(Int(idLength))

        // Credential public key (CBOR map)
        guard cursor < data.count else {
            throw AuthenticatorDataError.insufficientData(
                requested: 1,
                available: 0,
                atOffset: cursor
            )
        }
        let remaining = data.suffix(from: cursor)
        self.credentialPublicKey = try CBORDecoder.decode(remaining)
    }
}

// MARK: - Errors

public enum AuthenticatorDataError: Error, CustomStringConvertible {
    case insufficientData(requested: Int, available: Int, atOffset: Int)
    
    public var description: String {
        switch self {
        case .insufficientData(let requested, let available, let offset):
            return "AuthenticatorData: insufficient data at offset \(offset) - requested \(requested) bytes, but only \(available) available"
        }
    }
}
