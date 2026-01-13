//
//  COSEError.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// Errors that can occur while decoding or validating COSE structures.
public enum COSEError: Error, CustomStringConvertible {
    
    /// The top-level CBOR object was not the expected COSE structure.
    case invalidTopLevelType
    
    /// The COSE structure does not match the expected array length.
    case invalidStructureLength(expected: Int, actual: Int)
    
    /// A required header (protected or unprotected) is missing or malformed.
    case invalidHeader
    
    /// The protected header could not be decoded from its byte string.
    case invalidProtectedHeader
    
    /// An unsupported or unknown COSE algorithm identifier was encountered.
    case unsupportedAlgorithm(Int)
    
    /// The signature field is missing or invalid.
    case invalidSignature
    
    /// The payload field is missing or invalid.
    case invalidPayload
    
    /// The certificate chain (x5c) is missing, empty, or malformed.
    case invalidCertificateChain
    
    /// The COSE object is structurally valid but semantically unsupported.
    case unsupportedFeature(String)
    
    /// The header type is invalid (expected a map).
    case invalidHeaderType
    
    /// The COSE structure is invalid (wrong array length or format).
    case invalidStructure
    
    /// The unprotected header is missing or malformed.
    case invalidUnprotectedHeader
    
    public var description: String {
        switch self {
        case .invalidTopLevelType:
            return "Invalid COSE top-level type"
        case .invalidStructureLength(let expected, let actual):
            return "Invalid COSE structure length (expected \(expected), got \(actual))"
        case .invalidHeader:
            return "Invalid or missing COSE header"
        case .invalidProtectedHeader:
            return "Failed to decode COSE protected header"
        case .unsupportedAlgorithm(let alg):
            return "Unsupported COSE algorithm: \(alg)"
        case .invalidSignature:
            return "Invalid or missing COSE signature"
        case .invalidPayload:
            return "Invalid or missing COSE payload"
        case .invalidCertificateChain:
            return "Invalid or missing COSE x5c certificate chain"
        case .unsupportedFeature(let feature):
            return "Unsupported COSE feature: \(feature)"
        case .invalidHeaderType:
            return "Invalid COSE header type (expected map)"
        case .invalidStructure:
            return "Invalid COSE structure"
        case .invalidUnprotectedHeader:
            return "Invalid or missing COSE unprotected header"
        }
    }
}
