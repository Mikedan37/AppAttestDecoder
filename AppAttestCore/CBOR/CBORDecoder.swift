//
//  CBORDecoder.swift
//  AppAttestDecoderCLI
//

import Foundation

public enum CBORDecodingError: Error, CustomStringConvertible {
    case truncated(expected: Int, remaining: Int, atOffset: Int)
    case invalidInitialByte
    case unsupportedType
    case invalidMapKey
    
    public var description: String {
        switch self {
        case .truncated(let expected, let remaining, let offset):
            return "CBOR data truncated: expected \(expected) bytes, but only \(remaining) remaining at offset \(offset)"
        case .invalidInitialByte:
            return "Invalid CBOR initial byte"
        case .unsupportedType:
            return "Unsupported CBOR type"
        case .invalidMapKey:
            return "Invalid CBOR map key"
        }
    }
}

public final class CBORDecoder {

    public static func decode(_ data: Data) throws -> CBORValue {
        guard !data.isEmpty else {
            throw CBORDecodingError.truncated(
                expected: 1,
                remaining: 0,
                atOffset: 0
            )
        }
        return try CBORDecoder(data).decodeValue()
    }

    private let data: Data
    private var offset: Int = 0

    private init(_ data: Data) {
        // Defensive check: ensure data is not empty
        guard !data.isEmpty else {
            // This should never happen if called correctly, but be defensive
            self.data = Data()
            return
        }
        self.data = data
    }

    // MARK: - Entry

    private func decodeValue() throws -> CBORValue {
        let initial = try readByte()
        let major = initial >> 5
        let info = initial & 0x1f

        switch major {
        case 0: return .unsigned(try readUInt(info))
        case 1: return .negative(-1 - Int64(try readUInt(info)))
        case 2: return .byteString(try readBytes(info))
        case 3: return .textString(String(decoding: try readBytes(info), as: UTF8.self))
        case 4: return .array(try readArray(info))
        case 5: return .map(try readMap(info))
        case 6:
            let tag = try readUInt(info)
            let value = try decodeValue()
            return .tagged(tag, value)
        case 7:
            if info == 20 { return .boolean(false) }
            if info == 21 { return .boolean(true) }
            if info == 22 { return .null }
            if info == 23 { return .undefined }
            return .simple(info)
        default:
            throw CBORDecodingError.invalidInitialByte
        }
    }

    // MARK: - Containers

    private func readArray(_ info: UInt8) throws -> [CBORValue] {
        let count = try readUInt(info)
        var out: [CBORValue] = []
        out.reserveCapacity(Int(count))
        for _ in 0..<count {
            out.append(try decodeValue())
        }
        return out
    }

    private func readMap(_ info: UInt8) throws -> [(CBORValue, CBORValue)] {
        let count = try readUInt(info)
        var out: [(CBORValue, CBORValue)] = []
        out.reserveCapacity(Int(count))
        for _ in 0..<count {
            let key = try decodeValue()
            let val = try decodeValue()
            out.append((key, val))
        }
        return out
    }

    // MARK: - Primitives

    private func readUInt(_ info: UInt8) throws -> UInt64 {
        switch info {
        case 0...23: return UInt64(info)
        case 24: return UInt64(try readByte())
        case 25: return UInt64(try readUInt16())
        case 26: return UInt64(try readUInt32())
        case 27: return try readUInt64()
        default:
            throw CBORDecodingError.unsupportedType
        }
    }

    private func readBytes(_ info: UInt8) throws -> Data {
        let length = Int(try readUInt(info))
        guard offset + length <= data.count else {
            throw CBORDecodingError.truncated(
                expected: length,
                remaining: data.count - offset,
                atOffset: offset
            )
        }
        let slice = data[offset..<(offset + length)]
        offset += length
        return Data(slice)
    }

    // MARK: - Reads

    private func readByte() throws -> UInt8 {
        // Defensive checks
        guard !data.isEmpty else {
            throw CBORDecodingError.truncated(
                expected: 1,
                remaining: 0,
                atOffset: 0
            )
        }
        guard offset >= 0 && offset < data.count else {
            throw CBORDecodingError.truncated(
                expected: 1,
                remaining: max(0, data.count - offset),
                atOffset: offset
            )
        }
        // Safe access - we've verified bounds above
        // Access via subscript after bounds check
        let byte = data[offset]
        offset += 1
        return byte
    }

    private func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else {
            throw CBORDecodingError.truncated(
                expected: 2,
                remaining: data.count - offset,
                atOffset: offset
            )
        }
        defer { offset += 2 }
        // Read bytes manually to avoid alignment issues
        let byte0 = UInt16(data[offset])
        let byte1 = UInt16(data[offset + 1])
        return (byte0 << 8) | byte1
    }

    private func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw CBORDecodingError.truncated(
                expected: 4,
                remaining: data.count - offset,
                atOffset: offset
            )
        }
        defer { offset += 4 }
        // Read bytes manually to avoid alignment issues
        let byte0 = UInt32(data[offset])
        let byte1 = UInt32(data[offset + 1])
        let byte2 = UInt32(data[offset + 2])
        let byte3 = UInt32(data[offset + 3])
        return (byte0 << 24) | (byte1 << 16) | (byte2 << 8) | byte3
    }

    private func readUInt64() throws -> UInt64 {
        guard offset + 8 <= data.count else {
            throw CBORDecodingError.truncated(
                expected: 8,
                remaining: data.count - offset,
                atOffset: offset
            )
        }
        defer { offset += 8 }
        // Read bytes manually to avoid alignment issues
        let byte0 = UInt64(data[offset])
        let byte1 = UInt64(data[offset + 1])
        let byte2 = UInt64(data[offset + 2])
        let byte3 = UInt64(data[offset + 3])
        let byte4 = UInt64(data[offset + 4])
        let byte5 = UInt64(data[offset + 5])
        let byte6 = UInt64(data[offset + 6])
        let byte7 = UInt64(data[offset + 7])
        return (byte0 << 56) | (byte1 << 48) | (byte2 << 40) | (byte3 << 32) |
               (byte4 << 24) | (byte5 << 16) | (byte6 << 8) | byte7
    }
}
