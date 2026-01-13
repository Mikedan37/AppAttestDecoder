//
//  COSEHeader.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

/// COSE header parameter labels as defined in RFC 8152 / 9052.
/// We only implement what App Attest actually uses.
public enum COSEHeaderLabel: Int64 {
    case algorithm = 1
    case keyID = 4
    case x5chain = 33
}

/// Supported COSE algorithms for App Attest.
/// Apple currently uses ES256.
public enum COSEAlgorithm: Int {
    case es256 = -7

    public init?(rawCBOR: CBORValue) {
        guard let int = rawCBOR.intValue else { return nil }
        self.init(rawValue: int)
    }
}

/// Parsed COSE header (protected or unprotected).
/// This is intentionally strict and minimal.
public struct COSEHeader {

    public let algorithm: COSEAlgorithm?
    public let keyID: Data?
    public let x5c: [Data]

    /// Raw header map for debugging / inspection.
    public let raw: [CBORValue: CBORValue]

    public init(cbor: CBORValue) throws {
        guard let map = cbor.mapValue else {
            throw COSEError.invalidHeaderType
        }

        self.raw = map
        var alg: COSEAlgorithm? = nil
        var kid: Data? = nil
        var certs: [Data] = []

        for (key, value) in map {
            guard let labelInt = key.intValue,
                  let label = COSEHeaderLabel(rawValue: Int64(labelInt)) else {
                continue
            }

            switch label {
            case .algorithm:
                alg = COSEAlgorithm(rawCBOR: value)

            case .keyID:
                kid = value.dataValue

            case .x5chain:
                if let arr = value.arrayDataValues {
                    certs = arr
                }
            }
        }

        self.algorithm = alg
        self.keyID = kid
        self.x5c = certs
    }
    
    // MARK: - Static Decode Methods
    
    /// Decode a protected header from a CBOR byte string.
    /// The protected header is encoded as a CBOR byte string containing a CBOR map.
    static func decodeProtected(_ value: CBORValue) throws -> COSEHeader {
        guard let data = value.bytes else {
            throw COSEError.invalidProtectedHeader
        }
        
        let decoded = try CBORDecoder.decode(data)
        return try COSEHeader(cbor: decoded)
    }
    
    /// Decode an unprotected header from a CBOR map.
    static func decodeUnprotected(_ value: CBORValue) throws -> COSEHeader {
        return try COSEHeader(cbor: value)
    }
}
