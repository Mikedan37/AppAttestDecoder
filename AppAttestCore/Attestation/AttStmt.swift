import Foundation

public enum AttStmtError: Error {
    case invalidFormat
}

public struct AttStmt {

    public let alg: Int?
    public let signature: Data
    public let certificates: [Data]
    public let rawCBOR: CBORValue

    public init(cbor: CBORValue) throws {
        self.rawCBOR = cbor

        guard let map = cbor.mapValue else {
            throw AttStmtError.invalidFormat
        }

        // Try text string keys first (standard WebAuthn/COSE format)
        var algValue: Int? = map[.textString("alg")]?.intValue
        var sigValue: Data? = map[.textString("sig")]?.dataValue ?? map[.textString("signature")]?.dataValue
        var x5cValue: [Data]? = map[.textString("x5c")]?.arrayDataValues ?? map[.textString("x5chain")]?.arrayDataValues
        
        // Fallback: check for integer keys (Apple sometimes uses integer keys)
        // Common integer keys in COSE: 1 = alg, 4 = kid, 33 = x5c
        // For signature, we'll check common integer keys
        if algValue == nil {
            algValue = map[.unsigned(1)]?.intValue ?? map[.negative(-1)]?.intValue
        }
        if sigValue == nil {
            // Signature might be at different integer keys, check for byte strings with integer keys
            for (key, value) in map {
                if case .byteString = value {
                    if case .negative(let intKey) = key {
                        // Common signature key might be a negative integer
                        sigValue = value.bytes
                        break
                    }
                }
            }
        }
        if x5cValue == nil {
            x5cValue = map[.unsigned(33)]?.arrayDataValues ?? map[.negative(-33)]?.arrayDataValues
        }

        self.alg = algValue
        self.signature = sigValue ?? Data()
        self.certificates = x5cValue ?? []
    }

    public var x5c: [Data] {
        certificates
    }
}
