//
//  X509Certificate.swift
//  AppAttestDecoderCLI
//
//  Created by Michael Danylchuk on 1/12/26.
//

import Foundation

// MARK: - Minimal ASN.1 / DER reader (enough for X.509)

public struct ASN1Tag: Equatable {
    public let raw: UInt8

    public init(_ raw: UInt8) { self.raw = raw }

    public var tagClass: UInt8 { raw & 0b1100_0000 }
    public var constructed: Bool { (raw & 0b0010_0000) != 0 }
    public var number: UInt8 { raw & 0b0001_1111 }

    // Universal tags we care about
    public static let boolean = ASN1Tag(0x01)
    public static let integer = ASN1Tag(0x02)
    public static let bitString = ASN1Tag(0x03)
    public static let octetString = ASN1Tag(0x04)
    public static let null = ASN1Tag(0x05)
    public static let oid = ASN1Tag(0x06)
    public static let utf8String = ASN1Tag(0x0C)
    public static let sequence = ASN1Tag(0x30)
    public static let set = ASN1Tag(0x31)
    public static let printableString = ASN1Tag(0x13)
    public static let ia5String = ASN1Tag(0x16)
    public static let utcTime = ASN1Tag(0x17)
    public static let generalizedTime = ASN1Tag(0x18)
}

public struct ASN1TLV {
    public let tag: ASN1Tag
    public let length: Int
    public let valueRange: Range<Int>
}

public struct ASN1Reader {
    public let data: Data
    public private(set) var offset: Int = 0

    public init(_ data: Data) { self.data = data }

    public var remaining: Int { data.count - offset }

    public mutating func peekByte() throws -> UInt8 {
        guard offset < data.count else { throw ASN1Error.truncated }
        return data[offset]
    }

    public mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw ASN1Error.truncated }
        let b = data[offset]
        offset += 1
        return b
    }

    public mutating func read(_ count: Int) throws -> Data {
        guard count >= 0, offset + count <= data.count else { throw ASN1Error.truncated }
        let out = data.subdata(in: offset..<(offset + count))
        offset += count
        return out
    }

    public mutating func readLength() throws -> Int {
        let first = try readByte()
        if first & 0x80 == 0 {
            return Int(first)
        }
        let n = Int(first & 0x7F)
        if n == 0 { throw ASN1Error.invalidLength } // indefinite not allowed in DER
        if n > 4 { throw ASN1Error.invalidLength } // sanity
        var value: Int = 0
        for _ in 0..<n {
            value = (value << 8) | Int(try readByte())
        }
        return value
    }

    public mutating func readTLV() throws -> ASN1TLV {
        let t = ASN1Tag(try readByte())
        // We don’t support high-tag-number form here; X.509 doesn’t need it.
        if t.number == 0x1F { throw ASN1Error.invalidTag }
        let len = try readLength()
        let start = offset
        let end = start + len
        guard end <= data.count else { throw ASN1Error.truncated }
        offset = end
        return ASN1TLV(tag: t, length: len, valueRange: start..<end)
    }

    public mutating func withValueReader<T>(_ tlv: ASN1TLV, _ body: (inout ASN1Reader) throws -> T) throws -> T {
        var sub = ASN1Reader(data.subdata(in: tlv.valueRange))
        let result = try body(&sub)
        // If the consumer didn’t drain it, fine. DER parsers often allow skipping unknowns.
        return result
    }

    public mutating func expectTag(_ expected: ASN1Tag) throws -> ASN1TLV {
        let tlv = try readTLV()
        guard tlv.tag == expected else {
            throw ASN1Error.expected("tag 0x\(String(format: "%02X", expected.raw))")
        }
        return tlv
    }

    public mutating func readIntegerBytes() throws -> Data {
        let tlv = try expectTag(.integer)
        return data.subdata(in: tlv.valueRange)
    }

    public mutating func readOID() throws -> String {
        let tlv = try expectTag(.oid)
        let bytes = [UInt8](data.subdata(in: tlv.valueRange))
        guard !bytes.isEmpty else { throw ASN1Error.invalidOID }

        let first = Int(bytes[0])
        let a = first / 40
        let b = first % 40
        var arcs: [Int] = [a, b]

        var value = 0
        var started = false
        for byte in bytes.dropFirst() {
            started = true
            value = (value << 7) | Int(byte & 0x7F)
            if (byte & 0x80) == 0 {
                arcs.append(value)
                value = 0
            }
        }
        if started && value != 0 { throw ASN1Error.invalidOID }
        return arcs.map(String.init).joined(separator: ".")
    }

    public mutating func readString() throws -> String {
        let tlv = try readTLV()
        let slice = data.subdata(in: tlv.valueRange)
        switch tlv.tag {
        case .utf8String:
            return String(data: slice, encoding: .utf8) ?? ""
        case .printableString, .ia5String:
            return String(data: slice, encoding: .ascii) ?? ""
        default:
            throw ASN1Error.expected("string")
        }
    }

    public mutating func readTime() throws -> Date {
        let tlv = try readTLV()
        let str = String(data: data.subdata(in: tlv.valueRange), encoding: .ascii) ?? ""

        // DER times are typically like: YYMMDDHHMMSSZ or YYYYMMDDHHMMSSZ
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)

        switch tlv.tag {
        case .utcTime:
            fmt.dateFormat = "yyMMddHHmmss'Z'"
        case .generalizedTime:
            fmt.dateFormat = "yyyyMMddHHmmss'Z'"
        default:
            throw ASN1Error.expected("time")
        }

        guard let d = fmt.date(from: str) else { throw ASN1Error.invalidTime }
        return d
    }
}

// MARK: - X.509 structures

public struct X509Name: Equatable, CustomStringConvertible {
    public struct Attribute: Equatable {
        public let oid: String
        public let value: String
    }

    public let attributes: [Attribute]

    public var description: String {
        if attributes.isEmpty { return "<empty>" }
        return attributes.map { "\($0.oid)=\($0.value)" }.joined(separator: ", ")
    }
}

public struct X509Validity: Equatable {
    public let notBefore: Date
    public let notAfter: Date
}

public struct X509Certificate: Equatable {
    public let serialNumber: Data
    public let signatureAlgorithmOID: String
    public let issuer: X509Name
    public let subject: X509Name
    public let validity: X509Validity
    public let subjectPublicKeyAlgorithmOID: String?
    public let subjectPublicKeyBits: Data?

    /// Raw DER of the certificate (useful for hashing / debugging)
    public let der: Data

    /// Best-effort extraction of extensions by OID (raw DER of extnValue OCTET STRING contents).
    public let extensions: [String: Data]
    
    /// Decoded extensions (human-readable)
    public var decodedExtensions: [String: X509Extension] {
        var decoded: [String: X509Extension] = [:]
        for (oid, rawValue) in extensions {
            decoded[oid] = X509Extension.decode(oid: oid, rawValue: rawValue)
        }
        return decoded
    }

    public init(
        serialNumber: Data,
        signatureAlgorithmOID: String,
        issuer: X509Name,
        subject: X509Name,
        validity: X509Validity,
        subjectPublicKeyAlgorithmOID: String?,
        subjectPublicKeyBits: Data?,
        der: Data,
        extensions: [String: Data]
    ) {
        self.serialNumber = serialNumber
        self.signatureAlgorithmOID = signatureAlgorithmOID
        self.issuer = issuer
        self.subject = subject
        self.validity = validity
        self.subjectPublicKeyAlgorithmOID = subjectPublicKeyAlgorithmOID
        self.subjectPublicKeyBits = subjectPublicKeyBits
        self.der = der
        self.extensions = extensions
    }

    // MARK: Parse

    public static func parse(der: Data) throws -> X509Certificate {
        var r = ASN1Reader(der)
        let certTLV = try r.expectTag(.sequence)
        return try r.withValueReader(certTLV) { rr in
            // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
            let tbsTLV = try rr.expectTag(.sequence)
            let sigAlgTLV = try rr.expectTag(.sequence)
            _ = try rr.expectTag(.bitString) // signatureValue (we don’t need it for now)

            // signatureAlgorithm OID
            var sigAlgOID: String = ""
            try rr.withValueReader(sigAlgTLV) { s in
                sigAlgOID = (try? s.readOID()) ?? ""
                // params ignored
            }

            // Parse TBS
            var serial = Data()
            var issuer = X509Name(attributes: [])
            var subject = X509Name(attributes: [])
            var validity = X509Validity(notBefore: .distantPast, notAfter: .distantFuture)
            var spkiAlgOID: String? = nil
            var spkiBits: Data? = nil
            var exts: [String: Data] = [:]

            try rr.withValueReader(tbsTLV) { tbs in
                // Optional version: [0] EXPLICIT
                let first = try tbs.peekByte()
                if (first & 0xE0) == 0xA0 { // context-specific constructed 0
                    let vTLV = try tbs.readTLV()
                    // we don’t actually need version; skip
                    _ = vTLV
                }

                serial = try tbs.readIntegerBytes()

                // signature (AlgorithmIdentifier)
                _ = try tbs.expectTag(.sequence)

                // issuer
                issuer = try X509Certificate.readName(&tbs)

                // validity
                let validityTLV = try tbs.expectTag(.sequence)
                try tbs.withValueReader(validityTLV) { v in
                    let nb = try v.readTime()
                    let na = try v.readTime()
                    validity = X509Validity(notBefore: nb, notAfter: na)
                }

                // subject
                subject = try X509Certificate.readName(&tbs)

                // subjectPublicKeyInfo
                let spkiTLV = try tbs.expectTag(.sequence)
                try tbs.withValueReader(spkiTLV) { s in
                    // algorithm
                    let algTLV = try s.expectTag(.sequence)
                    try s.withValueReader(algTLV) { a in
                        spkiAlgOID = try? a.readOID()
                        // params ignored
                    }

                    // subjectPublicKey BIT STRING
                    let pkTLV = try s.expectTag(.bitString)
                    let pk = s.data.subdata(in: pkTLV.valueRange)
                    // first byte is "unused bits" count
                    if pk.count >= 1 {
                        spkiBits = pk.dropFirst()
                    } else {
                        spkiBits = Data()
                    }
                }

                // Optional fields: issuerUniqueID [1], subjectUniqueID [2], extensions [3]
                // We’ll scan remaining TLVs and pull extensions if present.
                while tbs.remaining > 0 {
                    let next = try tbs.peekByte()
                    // [3] EXPLICIT Extensions is tag 0xA3
                    if next == 0xA3 {
                        let extWrapper = try tbs.readTLV()
                        try tbs.withValueReader(extWrapper) { ew in
                            let extSeq = try ew.expectTag(.sequence)
                            try ew.withValueReader(extSeq) { seq in
                                while seq.remaining > 0 {
                                    let ext = try seq.expectTag(.sequence)
                                    try seq.withValueReader(ext) { e in
                                        let oid = try e.readOID()
                                        // optional critical (BOOLEAN)
                                        if (try? e.peekByte()) == ASN1Tag.boolean.raw {
                                            _ = try e.readTLV() // ignore
                                        }
                                        // extnValue OCTET STRING
                                        let oct = try e.expectTag(.octetString)
                                        let raw = e.data.subdata(in: oct.valueRange)
                                        // Often extnValue is an OCTET STRING containing DER of the extension
                                        exts[oid] = raw
                                    }
                                }
                            }
                        }
                    } else {
                        // Unknown optional field, skip TLV.
                        _ = try tbs.readTLV()
                    }
                }
            }

            return X509Certificate(
                serialNumber: serial,
                signatureAlgorithmOID: sigAlgOID,
                issuer: issuer,
                subject: subject,
                validity: validity,
                subjectPublicKeyAlgorithmOID: spkiAlgOID,
                subjectPublicKeyBits: spkiBits,
                der: der,
                extensions: exts
            )
        }
    }

    private static func readName(_ r: inout ASN1Reader) throws -> X509Name {
        // Name ::= SEQUENCE OF RDN
        let nameTLV = try r.expectTag(.sequence)
        return try r.withValueReader(nameTLV) { n in
            var attrs: [X509Name.Attribute] = []
            while n.remaining > 0 {
                // RDN ::= SET OF AttributeTypeAndValue
                let rdnTLV = try n.expectTag(.set)
                try n.withValueReader(rdnTLV) { setr in
                    while setr.remaining > 0 {
                        let atvTLV = try setr.expectTag(.sequence)
                        try setr.withValueReader(atvTLV) { atv in
                            let oid = (try? atv.readOID()) ?? ""
                            let val = (try? atv.readString()) ?? ""
                            if !oid.isEmpty {
                                attrs.append(.init(oid: oid, value: val))
                            }
                        }
                    }
                }
            }
            return X509Name(attributes: attrs)
        }
    }
}

extension Data {
    fileprivate func dropFirst() -> Data {
        guard !isEmpty else { return self }
        return subdata(in: 1..<count)
    }
}
