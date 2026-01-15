//
//  AttestationDiff.swift
//  AppAttestCore
//
//  Side-by-side comparison of two attestations
//

import Foundation

/// Compare two attestations and produce a diff
public struct AttestationDiff {
    
    public static func diff(_ left: AttestationSemanticModel, _ right: AttestationSemanticModel) -> DiffResult {
        var result = DiffResult()
        
        // Identity section
        result.identity = diffIdentity(left.identity, right.identity)
        
        // Credential section
        result.credential = diffCredential(left.credential, right.credential)
        
        // Trust chain
        result.trustChain = diffTrustChain(left.trustChain, right.trustChain)
        
        // Platform claims
        result.platformClaims = diffPlatformClaims(left.platformClaims, right.platformClaims)
        
        // Receipt
        result.receipt = diffReceipt(left.receipt, right.receipt)
        
        return result
    }
    
    private static func diffIdentity(_ left: AttestationSemanticModel.IdentitySection, _ right: AttestationSemanticModel.IdentitySection) -> SectionDiff {
        var diff = SectionDiff()
        
        if left.rpIdHash.hex != right.rpIdHash.hex {
            diff.changes.append(SectionDiff.Change(field: "rpIdHash", left: left.rpIdHash.hex, right: right.rpIdHash.hex))
        }
        if left.flags.rawByte != right.flags.rawByte {
            diff.changes.append(SectionDiff.Change(field: "flags", left: String(format: "0x%02x", left.flags.rawByte), right: String(format: "0x%02x", right.flags.rawByte)))
        }
        if left.signCount.value != right.signCount.value {
            diff.changes.append(SectionDiff.Change(field: "signCount", left: "\(left.signCount.value)", right: "\(right.signCount.value)"))
        }
        
        if diff.changes.isEmpty {
            diff.status = .identical
        } else {
            diff.status = .different
        }
        
        return diff
    }
    
    private static func diffCredential(_ left: AttestationSemanticModel.CredentialSection?, _ right: AttestationSemanticModel.CredentialSection?) -> SectionDiff {
        var diff = SectionDiff()
        
        if left == nil && right == nil {
            diff.status = .identical
            return diff
        }
        if left == nil {
            diff.status = .different
            diff.changes.append(SectionDiff.Change(field: "credential", left: "missing", right: "present"))
            return diff
        }
        if right == nil {
            diff.status = .different
            diff.changes.append(SectionDiff.Change(field: "credential", left: "present", right: "missing"))
            return diff
        }
        
        let l = left!, r = right!
        
        if l.aaguid.hex != r.aaguid.hex {
            diff.changes.append(SectionDiff.Change(field: "aaguid", left: l.aaguid.hex, right: r.aaguid.hex))
        }
        if l.credentialId.hex != r.credentialId.hex {
            diff.changes.append(SectionDiff.Change(field: "credentialId", left: l.credentialId.hex, right: r.credentialId.hex))
        }
        if l.publicKey.algorithm != r.publicKey.algorithm {
            diff.changes.append(SectionDiff.Change(field: "publicKey.algorithm", left: l.publicKey.algorithm ?? "nil", right: r.publicKey.algorithm ?? "nil"))
        }
        
        if diff.changes.isEmpty {
            diff.status = .identical
        } else {
            diff.status = .different
        }
        
        return diff
    }
    
    private static func diffTrustChain(_ left: AttestationSemanticModel.TrustChainSection, _ right: AttestationSemanticModel.TrustChainSection) -> SectionDiff {
        var diff = SectionDiff()
        
        if left.chainStructure != right.chainStructure {
            diff.changes.append(SectionDiff.Change(field: "chainStructure", left: left.chainStructure, right: right.chainStructure))
        }
        
        if left.certificates.count != right.certificates.count {
            diff.changes.append(SectionDiff.Change(field: "certificateCount", left: "\(left.certificates.count)", right: "\(right.certificates.count)"))
        }
        
        // Compare certificates
        let minCount = min(left.certificates.count, right.certificates.count)
        for i in 0..<minCount {
            let certDiff = diffCertificate(left.certificates[i], right.certificates[i])
            if certDiff.status == .different {
                diff.changes.append(SectionDiff.Change(field: "cert[\(i)]", left: "different", right: "different"))
                diff.subDiffs["cert[\(i)]"] = certDiff
            }
        }
        
        if diff.changes.isEmpty {
            diff.status = .identical
        } else {
            diff.status = .different
        }
        
        return diff
    }
    
    private static func diffCertificate(_ left: AttestationSemanticModel.CertificateInfo, _ right: AttestationSemanticModel.CertificateInfo) -> SectionDiff {
        var diff = SectionDiff()
        
        if left.subject.fullDN != right.subject.fullDN {
            diff.changes.append(SectionDiff.Change(field: "subject", left: left.subject.fullDN, right: right.subject.fullDN))
        }
        if left.issuer.fullDN != right.issuer.fullDN {
            diff.changes.append(SectionDiff.Change(field: "issuer", left: left.issuer.fullDN, right: right.issuer.fullDN))
        }
        if left.serialNumber != right.serialNumber {
            diff.changes.append(SectionDiff.Change(field: "serialNumber", left: left.serialNumber, right: right.serialNumber))
        }
        
        if diff.changes.isEmpty {
            diff.status = .identical
        } else {
            diff.status = .different
        }
        
        return diff
    }
    
    private static func diffPlatformClaims(_ left: AttestationSemanticModel.PlatformClaimsSection, _ right: AttestationSemanticModel.PlatformClaimsSection) -> SectionDiff {
        var diff = SectionDiff()
        
        if left.environment != right.environment {
            diff.changes.append(SectionDiff.Change(field: "environment", left: left.environment ?? "nil", right: right.environment ?? "nil"))
        }
        if left.osVersion != right.osVersion {
            diff.changes.append(SectionDiff.Change(field: "osVersion", left: left.osVersion ?? "nil", right: right.osVersion ?? "nil"))
        }
        if left.deviceClass != right.deviceClass {
            diff.changes.append(SectionDiff.Change(field: "deviceClass", left: left.deviceClass ?? "nil", right: right.deviceClass ?? "nil"))
        }
        if left.keyPurpose != right.keyPurpose {
            diff.changes.append(SectionDiff.Change(field: "keyPurpose", left: left.keyPurpose ?? "nil", right: right.keyPurpose ?? "nil"))
        }
        
        if diff.changes.isEmpty {
            diff.status = .identical
        } else {
            diff.status = .different
        }
        
        return diff
    }
    
    private static func diffReceipt(_ left: AttestationSemanticModel.ReceiptSection?, _ right: AttestationSemanticModel.ReceiptSection?) -> SectionDiff {
        var diff = SectionDiff()
        
        if left == nil && right == nil {
            diff.status = .identical
            return diff
        }
        if left == nil {
            diff.status = .different
            diff.changes.append(SectionDiff.Change(field: "receipt", left: "missing", right: "present"))
            return diff
        }
        if right == nil {
            diff.status = .different
            diff.changes.append(SectionDiff.Change(field: "receipt", left: "present", right: "missing"))
            return diff
        }
        
        let l = left!, r = right!
        
        if l.containerType != r.containerType {
            diff.changes.append(SectionDiff.Change(field: "containerType", left: l.containerType, right: r.containerType))
        }
        if l.rawData.count != r.rawData.count {
            diff.changes.append(SectionDiff.Change(field: "size", left: "\(l.rawData.count) bytes", right: "\(r.rawData.count) bytes"))
        }
        
        if diff.changes.isEmpty {
            diff.status = .identical
        } else {
            diff.status = .different
        }
        
        return diff
    }
}

public struct DiffResult: Codable {
    public var identity: SectionDiff = SectionDiff()
    public var credential: SectionDiff = SectionDiff()
    public var trustChain: SectionDiff = SectionDiff()
    public var platformClaims: SectionDiff = SectionDiff()
    public var receipt: SectionDiff = SectionDiff()
    
    public var hasDifferences: Bool {
        identity.status == .different ||
        credential.status == .different ||
        trustChain.status == .different ||
        platformClaims.status == .different ||
        receipt.status == .different
    }
}

public struct SectionDiff: Codable {
    public enum Status: String, Codable {
        case identical
        case different
    }
    
    public struct Change: Codable {
        public let field: String
        public let left: String
        public let right: String
    }
    
    public var status: Status = .identical
    public var changes: [Change] = []
    public var subDiffs: [String: SectionDiff] = [:]
}
