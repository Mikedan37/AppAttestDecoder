//
//  ReceiptASN1Inspector.swift
//  AppAttestCore
//
//  Enhanced ASN.1/CMS envelope inspection for receipts
//

import Foundation

/// Enhanced receipt inspection with ASN.1 TLV tree
public struct ReceiptASN1Inspector {
    
    /// Inspect receipt with full ASN.1 TLV breakdown
    public static func inspect(_ receiptData: Data) -> ReceiptInspection {
        var containerType = "Unknown"
        var cmsStructure: CMSStructure? = nil
        var asn1Tree: [ASN1TLVNode] = []
        var payloadAnalysis: PayloadAnalysis? = nil
        
        // Try CMS first
        if let cms = try? CMSSignedData.parse(der: receiptData) {
            containerType = "CMS SignedData (PKCS#7, RFC 5652)"
            cmsStructure = CMSStructure(
                version: cms.version,
                digestAlgorithms: cms.digestAlgorithms.map { $0.name },
                contentType: cms.encapContentInfo.contentType,
                contentTypeName: cms.encapContentInfo.contentTypeName,
                payloadSize: cms.encapContentInfo.content.count,
                certificateCount: cms.certificates.count,
                signerCount: cms.signerInfos.count
            )
            
            // Parse ASN.1 TLV tree for the CMS structure
            var reader = ASN1Reader(receiptData)
            asn1Tree = parseASN1Tree(&reader, path: "receipt", maxDepth: 10)
            
            // Analyze payload
            if !cms.encapContentInfo.content.isEmpty {
                payloadAnalysis = analyzePayload(cms.encapContentInfo.content)
            }
        } else {
            // Not CMS - try direct ASN.1
            var reader = ASN1Reader(receiptData)
            if let _ = try? reader.readTLV() {
                containerType = "ASN.1 DER"
                var reader2 = ASN1Reader(receiptData)
                asn1Tree = parseASN1Tree(&reader2, path: "receipt", maxDepth: 10)
            }
        }
        
        return ReceiptInspection(
            rawSize: receiptData.count,
            containerType: containerType,
            asn1Tree: asn1Tree,
            cmsStructure: cmsStructure,
            payloadAnalysis: payloadAnalysis
        )
    }
    
    private static func parseASN1Tree(_ reader: inout ASN1Reader, path: String, maxDepth: Int, currentDepth: Int = 0) -> [ASN1TLVNode] {
        guard currentDepth < maxDepth else { return [] }
        var nodes: [ASN1TLVNode] = []
        
        let startOffset = reader.offset
        guard let tlv = try? reader.readTLV() else { return [] }
        
        let tagName = describeASN1Tag(tlv.tag)
        let valueData = tlv.tag.constructed ? Data() : reader.data.subdata(in: tlv.valueRange)
        let node = ASN1TLVNode(
            path: path,
            offset: startOffset,
            tag: tlv.tag,
            length: tlv.length,
            valueHexPreview: formatHexPreview(valueData, firstBytes: 16, lastBytes: 8)
        )
        nodes.append(node)
        
        // If constructed, parse children
        if tlv.tag.constructed && tlv.length > 0 {
            var childReader = ASN1Reader(reader.data.subdata(in: tlv.valueRange))
            let childNodes = parseASN1Tree(&childReader, path: "\(path)/\(tagName)", maxDepth: maxDepth, currentDepth: currentDepth + 1)
            nodes.append(contentsOf: childNodes)
        }
        
        // Continue parsing siblings
        if reader.remaining > 0 {
            let siblingNodes = parseASN1Tree(&reader, path: path, maxDepth: maxDepth, currentDepth: currentDepth)
            nodes.append(contentsOf: siblingNodes)
        }
        
        return nodes
    }
    
    static func describeTagClassPublic(_ tagClass: UInt8) -> String {
        return describeTagClass(tagClass)
    }
    
    private static func describeTagClass(_ tagClass: UInt8) -> String {
        switch tagClass {
        case 0b00: return "Universal"
        case 0b01: return "Application"
        case 0b10: return "Context-Specific"
        case 0b11: return "Private"
        default: return "Unknown"
        }
    }
    
    static func describeASN1TagPublic(_ tag: ASN1Tag) -> String {
        return describeASN1Tag(tag)
    }
    
    private static func describeASN1Tag(_ tag: ASN1Tag) -> String {
        let tagClass = tag.tagClass
        if tagClass == 0b00 { // Universal
            switch tag.number {
            case 1: return "BOOLEAN"
            case 2: return "INTEGER"
            case 3: return "BIT STRING"
            case 4: return "OCTET STRING"
            case 5: return "NULL"
            case 6: return "OBJECT IDENTIFIER"
            case 12: return "UTF8String"
            case 16: return "SEQUENCE"
            case 17: return "SET"
            case 19: return "PrintableString"
            case 22: return "IA5String"
            case 23: return "UTCTime"
            case 24: return "GeneralizedTime"
            default: return "UNIVERSAL \(tag.number)"
            }
        } else if tagClass == 0b10 { // Context-Specific
            return "[\(tag.number)]"
        } else if tagClass == 0b01 { // Application
            return "APPLICATION \(tag.number)"
        } else { // Private
            return "PRIVATE \(tag.number)"
        }
    }
    
    private static func formatHexPreview(_ data: Data, firstBytes: Int, lastBytes: Int) -> String {
        guard data.count > firstBytes + lastBytes else {
            return data.map { String(format: "%02x", $0) }.joined()
        }
        let first = data.prefix(firstBytes).map { String(format: "%02x", $0) }.joined()
        let last = data.suffix(lastBytes).map { String(format: "%02x", $0) }.joined()
        return "\(first)…\(last)"
    }
    
    private static func analyzePayload(_ payload: Data) -> PayloadAnalysis {
        var detectedFormat = "Unknown"
        var structure: [ASN1TLVNode] = []
        
        // Try ASN.1
        var asn1Reader = ASN1Reader(payload)
        if let _ = try? asn1Reader.readTLV() {
            detectedFormat = "ASN.1 DER"
            var reader2 = ASN1Reader(payload)
            structure = parseASN1Tree(&reader2, path: "payload", maxDepth: 5)
        }
        // Try CBOR
        else if let _ = try? CBORDecoder.decode(payload) {
            detectedFormat = "CBOR"
        }
        // Try plist
        else if let _ = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) {
            detectedFormat = "Property List"
        }
        // Try UTF-8
        else if let str = String(data: payload, encoding: .utf8), str.count < 200 {
            detectedFormat = "UTF-8 String"
        }
        
        return PayloadAnalysis(
            size: payload.count,
            detectedFormat: detectedFormat,
            structure: structure
        )
    }
}

public struct ReceiptInspection {
    public let rawSize: Int
    public let containerType: String
    public let asn1Tree: [ASN1TLVNode]
    public let cmsStructure: CMSStructure?
    public let payloadAnalysis: PayloadAnalysis?
}

public struct ASN1TLVNode {
    public let path: String
    public let offset: Int
    public let tag: String
    public let tagClass: String
    public let constructed: Bool
    public let length: Int
    public let valueHexPreview: String
    
    init(path: String, offset: Int, tag: ASN1Tag, length: Int, valueHexPreview: String) {
        self.path = path
        self.offset = offset
        self.tag = ReceiptASN1Inspector.describeASN1TagPublic(tag)
        self.tagClass = ReceiptASN1Inspector.describeTagClassPublic(tag.tagClass)
        self.constructed = tag.constructed
        self.length = length
        self.valueHexPreview = valueHexPreview
    }
}

public struct CMSStructure {
    public let version: Int
    public let digestAlgorithms: [String]
    public let contentType: String
    public let contentTypeName: String
    public let payloadSize: Int
    public let certificateCount: Int
    public let signerCount: Int
}

public struct PayloadAnalysis {
    public let size: Int
    public let detectedFormat: String
    public let structure: [ASN1TLVNode]
}

