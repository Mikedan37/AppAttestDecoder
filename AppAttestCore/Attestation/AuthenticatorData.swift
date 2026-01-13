import Foundation

public struct AuthenticatorData {

    // MARK: - Core fields
    public let rpIdHash: Data          // 32 bytes
    public let flags: Flags
    public let signCount: UInt32

    // MARK: - Optional sections
    public let attestedCredentialData: AttestedCredentialData?
    public let extensions: CBORValue?

    // MARK: - Raw
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
        if flags.attestedCredentialData {
            self.attestedCredentialData = try AttestedCredentialData(from: rawData, cursor: &cursor)
        } else {
            self.attestedCredentialData = nil
        }

        // extensions (decoded separately if needed)
        self.extensions = extensions
    }
}

// MARK: - Flags
extension AuthenticatorData {

    public struct Flags: Equatable {
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
public struct AttestedCredentialData {

    public let aaguid: Data            // 16 bytes
    public let credentialId: Data
    public let credentialPublicKey: CBORValue

    public init(from data: Data, cursor: inout Int) throws {

        func read(_ length: Int) -> Data {
            precondition(cursor + length <= data.count, "AttestedCredentialData: out-of-bounds read")
            defer { cursor += length }
            return data.subdata(in: cursor ..< cursor + length)
        }

        // AAGUID (16 bytes)
        self.aaguid = read(16)

        // Credential ID length (2 bytes, big endian)
        let idLenData = read(2)
        let idLength = idLenData.withUnsafeBytes {
            $0.load(as: UInt16.self).bigEndian
        }

        // Credential ID
        self.credentialId = read(Int(idLength))

        // Credential public key (CBOR map)
        let remaining = data.suffix(from: cursor)
        self.credentialPublicKey = try CBORDecoder.decode(remaining)
    }
}
