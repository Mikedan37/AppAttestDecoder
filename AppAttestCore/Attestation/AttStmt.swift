import Foundation

public enum AttStmtError: Error {
    case invalidFormat
}

/// Attestation statement containing signature and certificate chain.
/// All fields are parsed but NOT validated. Consumers must perform full certificate chain validation
/// and signature verification using these raw materials.
public struct AttStmt {

    /// Algorithm identifier (COSE algorithm number, e.g., -7 for ES256).
    /// This value is parsed but NOT validated. Consumers must verify algorithm matches expected value.
    public let alg: Int?
    
    /// Attestation signature bytes. This is the cryptographic signature over the attestation object.
    /// This value is extracted but NOT verified. Consumers must verify signature using validated certificate.
    public let signature: Data
    
    /// Certificate chain as array of DER-encoded X.509 certificates.
    /// Certificates are extracted but NOT validated. Consumers must perform full certificate chain validation
    /// against Apple's App Attest Root CA before using any certificate for signature verification.
    public let certificates: [Data]
    
    /// Raw CBOR-encoded attestation statement. Useful for debugging or custom parsing.
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
        if algValue == nil {
            algValue = map[.unsigned(1)]?.intValue ?? map[.negative(-1)]?.intValue
        }
        if sigValue == nil {
            // Signature might be at different integer keys, check for byte strings
            // Try common COSE integer keys first
            if let sig = map[.unsigned(4)]?.bytes ?? map[.negative(-4)]?.bytes {
                sigValue = sig
            } else {
                // Search for any byte string that might be a signature (typically 64-72 bytes for ES256)
                for (_, value) in map {
                    if case .byteString(let bytes) = value {
                        // ES256 signatures are typically 64 bytes, but can be 70-72 with ASN.1 encoding
                        if bytes.count >= 60 && bytes.count <= 80 {
                            sigValue = bytes
                            break
                        }
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

    /// Certificate chain accessor (alias for `certificates`).
    /// Returns DER-encoded X.509 certificates. These are NOT validated.
    /// Consumers must perform full certificate chain validation before use.
    public var x5c: [Data] {
        certificates
    }
}
