//
//  ASN1Node.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// Represents a single ASN.1 node decoded from DER.
public struct ASN1Node: CustomStringConvertible {

    public enum TagClass: UInt8 {
        case universal       = 0b00
        case application     = 0b01
        case contextSpecific = 0b10
        case `private`       = 0b11
    }

    public enum Construction {
        case primitive
        case constructed
    }

    /// Universal ASN.1 tag numbers we actually care about
    public enum UniversalTag: UInt8 {
        case boolean            = 1
        case integer            = 2
        case bitString          = 3
        case octetString        = 4
        case null               = 5
        case objectIdentifier   = 6
        case sequence           = 16
        case set                = 17
        case printableString    = 19
        case utf8String         = 12
        case ia5String          = 22
        case utcTime            = 23
        case generalizedTime    = 24
    }

    // MARK: - Core Properties

    public let tagClass: TagClass
    public let tagNumber: UInt64
    public let construction: Construction
    public let length: Int
    public let rawValue: Data
    public let children: [ASN1Node]

    // MARK: - Convenience

    public var universalTag: UniversalTag? {
        guard tagClass == .universal else { return nil }
        return UniversalTag(rawValue: UInt8(tagNumber))
    }

    public var isConstructed: Bool {
        construction == .constructed
    }

    // MARK: - Typed Accessors

    public var integerValue: Int? {
        guard universalTag == .integer else { return nil }
        return rawValue.reduce(0) { ($0 << 8) | Int($1) }
    }

    public var stringValue: String? {
        switch universalTag {
        case .utf8String, .printableString, .ia5String:
            return String(data: rawValue, encoding: .utf8)
        default:
            return nil
        }
    }

    public var oidValue: [UInt64]? {
        guard universalTag == .objectIdentifier, rawValue.count > 0 else { return nil }

        var result: [UInt64] = []
        let first = rawValue[0]
        result.append(UInt64(first / 40))
        result.append(UInt64(first % 40))

        var value: UInt64 = 0
        for byte in rawValue.dropFirst() {
            value = (value << 7) | UInt64(byte & 0x7F)
            if (byte & 0x80) == 0 {
                result.append(value)
                value = 0
            }
        }
        return result
    }

    // MARK: - Debug

    public var description: String {
        var parts: [String] = []
        parts.append("class=\(tagClass)")
        parts.append("tag=\(tagNumber)")
        parts.append(isConstructed ? "constructed" : "primitive")
        parts.append("len=\(length)")
        if let u = universalTag {
            parts.append("universal=\(u)")
        }
        return "ASN1Node(\(parts.joined(separator: ", ")))"
    }
}
