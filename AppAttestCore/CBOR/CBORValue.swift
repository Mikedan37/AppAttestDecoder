import Foundation

public indirect enum CBORValue: Hashable, Equatable {
    case unsigned(UInt64)
    case negative(Int64)
    case byteString(Data)
    case textString(String)
    case array([CBORValue])
    case map([(CBORValue, CBORValue)])
    case tagged(UInt64, CBORValue)
    case simple(UInt8)
    case boolean(Bool)
    case null
    case undefined
}

extension CBORValue {

    /// Returns the associated String if this value is a text string.
    public var string: String? {
        if case .textString(let s) = self { return s }
        return nil
    }

    /// Returns the associated Data if this value is a byte string.
    public var bytes: Data? {
        if case .byteString(let d) = self { return d }
        return nil
    }

    /// Returns the associated UInt64 if this value is an unsigned integer.
    public var unsignedInt: UInt64? {
        if case .unsigned(let v) = self { return v }
        return nil
    }

    /// Returns the associated Int64 if this value is a negative integer.
    public var negativeInt: Int64? {
        if case .negative(let v) = self { return v }
        return nil
    }

    /// Returns the underlying map if this value is a CBOR map.
    public var mapValue: [CBORValue: CBORValue]? {
        if case .map(let pairs) = self {
            return Dictionary(uniqueKeysWithValues: pairs)
        }
        return nil
    }

    /// Returns the underlying array if this value is a CBOR array.
    public var arrayValue: [CBORValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// Returns this value as an Int if it is an integer (unsigned or negative).
    public var intValue: Int? {
        switch self {
        case .unsigned(let u): return Int(u)
        case .negative(let n): return Int(n)
        default: return nil
        }
    }

    /// Returns this value as Data if it is a byte string.
    public var dataValue: Data? {
        if case .byteString(let d) = self { return d }
        return nil
    }

    /// Returns this value as an array of Data if it is an array of byte strings.
    public var arrayDataValues: [Data]? {
        guard case .array(let arr) = self else { return nil }
        return arr.compactMap { v in
            if case .byteString(let d) = v { return d }
            return nil
        }
    }
}

extension CBORValue {
    public static func == (lhs: CBORValue, rhs: CBORValue) -> Bool {
        switch (lhs, rhs) {
        case (.unsigned(let a), .unsigned(let b)): return a == b
        case (.negative(let a), .negative(let b)): return a == b
        case (.byteString(let a), .byteString(let b)): return a == b
        case (.textString(let a), .textString(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.map(let a), .map(let b)):
            guard a.count == b.count else { return false }
            for (lhsPair, rhsPair) in zip(a, b) {
                if lhsPair.0 != rhsPair.0 || lhsPair.1 != rhsPair.1 {
                    return false
                }
            }
            return true
        case (.tagged(let ta, let va), .tagged(let tb, let vb)):
            return ta == tb && va == vb
        case (.simple(let a), .simple(let b)): return a == b
        case (.boolean(let a), .boolean(let b)): return a == b
        case (.null, .null): return true
        case (.undefined, .undefined): return true
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .unsigned(let v):
            hasher.combine(0); hasher.combine(v)
        case .negative(let v):
            hasher.combine(1); hasher.combine(v)
        case .byteString(let v):
            hasher.combine(2); hasher.combine(v)
        case .textString(let v):
            hasher.combine(3); hasher.combine(v)
        case .array(let v):
            hasher.combine(4); hasher.combine(v)
        case .map(let pairs):
            hasher.combine(5)
            for (k, v) in pairs {
                hasher.combine(k)
                hasher.combine(v)
            }
        case .tagged(let t, let v):
            hasher.combine(6); hasher.combine(t); hasher.combine(v)
        case .simple(let v):
            hasher.combine(7); hasher.combine(v)
        case .boolean(let v):
            hasher.combine(8); hasher.combine(v)
        case .null:
            hasher.combine(9)
        case .undefined:
            hasher.combine(10)
        }
    }
}
