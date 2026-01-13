//
//  ASN1Error.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// Errors emitted by the ASN.1 / DER decoder.
/// These are intentionally explicit so failures are debuggable,
/// not swallowed as generic parsing issues.
public enum ASN1Error: Error, CustomStringConvertible {
    
    /// Input data ended unexpectedly while parsing.
    case truncated
    
    /// Encountered a tag that is not supported by this decoder.
    case unsupportedTag(UInt8)
    
    /// Length field is malformed or invalid.
    case invalidLength
    
    /// The ASN.1 structure is not well-formed.
    case malformedStructure(String)
    
    /// Encountered an object identifier that could not be decoded.
    case invalidOID
    
    /// Expected a specific ASN.1 tag but encountered another.
    case unexpectedTag(expected: UInt8, actual: UInt8)
    
    /// Decoder attempted to read beyond available data.
    case outOfBounds
    
    /// Encountered an invalid ASN.1 tag.
    case invalidTag
    
    /// Encountered an invalid time encoding.
    case invalidTime
    
    /// Expected a constructed type but encountered a primitive.
    case expectedConstructed
    
    /// Expected a primitive type but encountered a constructed.
    case expectedPrimitive
    
    /// Expected a specific value but encountered another.
    case expected(_ what: String)
    
    public var description: String {
        switch self {
        case .truncated:
            return "ASN.1 data is truncated"
        case .unsupportedTag(let tag):
            return "Unsupported ASN.1 tag: 0x\(String(tag, radix: 16))"
        case .invalidLength:
            return "Invalid ASN.1 length encoding"
        case .malformedStructure(let reason):
            return "Malformed ASN.1 structure: \(reason)"
        case .invalidOID:
            return "Invalid ASN.1 object identifier"
        case .unexpectedTag(let expected, let actual):
            return "Unexpected ASN.1 tag. Expected 0x\(String(expected, radix: 16)), got 0x\(String(actual, radix: 16))"
        case .outOfBounds:
            return "ASN.1 decoder read out of bounds"
        case .invalidTag:
            return "Invalid ASN.1 tag"
        case .invalidTime:
            return "Invalid ASN.1 time encoding"
        case .expectedConstructed:
            return "Expected constructed ASN.1 type"
        case .expectedPrimitive:
            return "Expected primitive ASN.1 type"
        case .expected(let what):
            return "Expected \(what)"
        }
    }
}
