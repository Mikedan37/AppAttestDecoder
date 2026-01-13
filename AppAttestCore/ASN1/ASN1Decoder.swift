//
//  ASN1Decoder.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

// MARK: - Decoder

public struct ASN1Decoder {

    public init() {}

    public func decode(_ data: Data) throws -> ASN1Node {
        var index = 0
        let node = try parseNode(data, &index)
        return node
    }

    // MARK: - Parsing

    private func parseNode(_ data: Data, _ index: inout Int) throws -> ASN1Node {
        guard index < data.count else { throw ASN1Error.truncated }

        let tagByte = data[index]
        let startIndex = index
        index += 1

        let length = try parseLength(data, &index)
        guard index + length <= data.count else { throw ASN1Error.truncated }

        let content = data.subdata(in: index ..< index + length)
        index += length

        // Extract tag class
        let tagClassRaw = (tagByte & 0b1100_0000) >> 6
        let tagClass = ASN1Node.TagClass(rawValue: UInt8(tagClassRaw)) ?? .universal

        // Extract construction
        let isConstructed = (tagByte & 0b0010_0000) != 0
        let construction: ASN1Node.Construction = isConstructed ? .constructed : .primitive

        // Extract tag number
        let tagNumber = UInt64(tagByte & 0b0001_1111)

        // Get raw value (entire TLV including tag and length)
        let rawValue = data.subdata(in: startIndex ..< index)

        // Parse children if constructed
        let children: [ASN1Node]
        if isConstructed {
            children = try parseChildren(content)
        } else {
            children = []
        }

        return ASN1Node(
            tagClass: tagClass,
            tagNumber: tagNumber,
            construction: construction,
            length: length,
            rawValue: rawValue,
            children: children
        )
    }

    // MARK: - Helpers

    private func parseChildren(_ data: Data) throws -> [ASN1Node] {
        var nodes: [ASN1Node] = []
        var index = 0
        while index < data.count {
            nodes.append(try parseNode(data, &index))
        }
        return nodes
    }

    private func parseLength(_ data: Data, _ index: inout Int) throws -> Int {
        guard index < data.count else { throw ASN1Error.truncated }

        let first = data[index]
        index += 1

        if first & 0x80 == 0 {
            return Int(first)
        }

        let byteCount = Int(first & 0x7F)
        guard byteCount > 0, byteCount <= 4 else {
            throw ASN1Error.invalidLength
        }

        guard index + byteCount <= data.count else {
            throw ASN1Error.truncated
        }

        var length = 0
        for _ in 0..<byteCount {
            length = (length << 8) | Int(data[index])
            index += 1
        }

        return length
    }
}
