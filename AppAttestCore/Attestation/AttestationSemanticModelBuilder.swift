//
//  AttestationSemanticModelBuilder.swift
//  AppAttestDecoderCLI
//
//  Builds semantic model from AttestationObject
//  Separates decoding from presentation
//

import Foundation

extension AttestationObject {
    /// Build semantic model from this attestation object
    public func buildSemanticModel() throws -> AttestationSemanticModel {
        // Summary
        let summary = buildSummary()
        
        // Identity
        let identity = buildIdentitySection()
        
        // Credential
        let credential = buildCredentialSection()
        
        // Trust Chain
        let trustChain = buildTrustChainSection()
        
        // Platform Claims
        let platformClaims = buildPlatformClaimsSection()
        
        // Receipt
        let receipt = buildReceiptSection()
        
        // Raw Evidence
        let rawEvidence = buildRawEvidenceSection()
        
        return AttestationSemanticModel(
            summary: summary,
            identity: identity,
            credential: credential,
            trustChain: trustChain,
            platformClaims: platformClaims,
            receipt: receipt,
            rawEvidence: rawEvidence
        )
    }
    
    private func buildSummary() -> AttestationSemanticModel.SummarySection {
        var decodedExtCount = 0
        var opaqueExtCount = 0
        var environment: String? = nil
        
        if let leafCertDER = attestationStatement.x5c.first,
           let leafCert = try? X509Certificate.parse(der: leafCertDER) {
            for (_, ext) in leafCert.decodedExtensions {
                switch ext {
                case .appleOID(_, let appleExt):
                    if case .environment(let env) = appleExt.type {
                        environment = env
                    }
                    decodedExtCount += 1
                case .basicConstraints, .keyUsage, .extendedKeyUsage, .subjectKeyIdentifier, .authorityKeyIdentifier, .subjectAlternativeName:
                    decodedExtCount += 1
                case .unknown:
                    opaqueExtCount += 1
                }
            }
        }
        
        let receiptPresent = (attestationStatement.rawCBOR.mapValue?.first(where: { key, _ in
            if case .textString("receipt") = key { return true }
            return false
        }) != nil)
        
        return AttestationSemanticModel.SummarySection(
            format: format,
            certificateChainLength: attestationStatement.x5c.count,
            receiptPresent: receiptPresent,
            attestedCredentialPresent: authenticatorData.attestedCredentialData != nil,
            environment: environment,
            extensionCount: (decoded: decodedExtCount, opaque: opaqueExtCount)
        )
    }
    
    private func buildIdentitySection() -> AttestationSemanticModel.IdentitySection {
        let rpIdHash = AttestationSemanticModel.HashInfo(
            algorithm: "SHA-256",
            hex: authenticatorData.rpIdHash.map { String(format: "%02x", $0) }.joined(),
            base64: authenticatorData.rpIdHash.base64EncodedString(),
            length: authenticatorData.rpIdHash.count,
            raw: authenticatorData.rpIdHash
        )
        
        let flags = AttestationSemanticModel.FlagsInfo(
            rawByte: authenticatorData.flags.rawValue,
            userPresent: authenticatorData.flags.userPresent,
            userVerified: authenticatorData.flags.userVerified,
            attestedCredentialData: authenticatorData.flags.attestedCredentialData,
            extensionsIncluded: authenticatorData.flags.extensionsIncluded,
            raw: Data([authenticatorData.flags.rawValue])
        )
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let signCountFormatted = formatter.string(from: NSNumber(value: authenticatorData.signCount)) ?? "\(authenticatorData.signCount)"
        
        let signCount = AttestationSemanticModel.SignCountInfo(
            value: authenticatorData.signCount,
            formatted: signCountFormatted,
            significance: authenticatorData.signCount == 0 ? "First attestation (no prior use)" : "Increments with each use (replay protection)"
        )
        
        return AttestationSemanticModel.IdentitySection(
            rpIdHash: rpIdHash,
            flags: flags,
            signCount: signCount
        )
    }
    
    private func buildCredentialSection() -> AttestationSemanticModel.CredentialSection? {
        guard let credData = authenticatorData.attestedCredentialData else {
            return nil
        }
        
        // AAGUID is 16 bytes, UUID format
        let aaguidUUID: UUID?
        if credData.aaguid.count == 16 {
            let uuidBytes = [UInt8](credData.aaguid)
            aaguidUUID = UUID(uuid: (
                uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
            ))
        } else {
            aaguidUUID = nil
        }
        let aaguid = AttestationSemanticModel.AAGUIDInfo(
            uuid: aaguidUUID?.uuidString,
            hex: credData.aaguid.map { String(format: "%02x", $0) }.joined(),
            length: credData.aaguid.count,
            raw: credData.aaguid
        )
        
        let credentialId = AttestationSemanticModel.CredentialIDInfo(
            hex: credData.credentialId.map { String(format: "%02x", $0) }.joined(),
            base64: credData.credentialId.base64EncodedString(),
            length: credData.credentialId.count,
            raw: credData.credentialId
        )
        
        let publicKey = buildCOSEKeyInfo(from: credData.credentialPublicKey)
        
        return AttestationSemanticModel.CredentialSection(
            aaguid: aaguid,
            credentialId: credentialId,
            publicKey: publicKey
        )
    }
    
    private func buildCOSEKeyInfo(from cbor: CBORValue) -> AttestationSemanticModel.COSEKeyInfo {
        var keyType: String? = nil
        var algorithm: String? = nil
        var curve: String? = nil
        var xCoordinate: AttestationSemanticModel.CoordinateInfo? = nil
        var yCoordinate: AttestationSemanticModel.CoordinateInfo? = nil
        var unknownParameters: [(String, String)] = []
        
        guard case .map(let pairs) = cbor else {
            return AttestationSemanticModel.COSEKeyInfo(
                keyType: nil,
                algorithm: nil,
                curve: nil,
                xCoordinate: nil,
                yCoordinate: nil,
                unknownParameters: [],
                rawCBOR: cbor
            )
        }
        
        for (key, value) in pairs {
            var label: String? = nil
            var valueStr: String? = nil
            
            // Map COSE key labels
            switch key {
            case .unsigned(1):
                label = "kty"
                if case .unsigned(let ktyVal) = value {
                    keyType = ktyVal == 2 ? "EC (2)" : "\(ktyVal)"
                    valueStr = keyType
                }
            case .negative(-1):
                label = "crv"
                if case .unsigned(1) = value {
                    curve = "P-256 (1)"
                    valueStr = curve
                }
            case .negative(-2):
                label = "x"
                if case .byteString(let xData) = value {
                    xCoordinate = AttestationSemanticModel.CoordinateInfo(
                        length: xData.count,
                        hex: xData.map { String(format: "%02x", $0) }.joined(),
                        raw: xData
                    )
                    valueStr = "[\(xData.count) bytes]"
                }
            case .negative(-3):
                label = "y"
                if case .byteString(let yData) = value {
                    yCoordinate = AttestationSemanticModel.CoordinateInfo(
                        length: yData.count,
                        hex: yData.map { String(format: "%02x", $0) }.joined(),
                        raw: yData
                    )
                    valueStr = "[\(yData.count) bytes]"
                }
            case .negative(-7), .unsigned(3):
                label = "alg"
                algorithm = "ES256 (-7)"
                valueStr = algorithm
            default:
                // Unknown parameter
                if let keyLabel = describeCBORKey(key) {
                    label = keyLabel
                } else {
                    label = "\(key)"
                }
                valueStr = describeCBORValue(value)
            }
            
            if let label = label, let valueStr = valueStr {
                unknownParameters.append((label, valueStr))
            }
        }
        
        return AttestationSemanticModel.COSEKeyInfo(
            keyType: keyType,
            algorithm: algorithm,
            curve: curve,
            xCoordinate: xCoordinate,
            yCoordinate: yCoordinate,
            unknownParameters: unknownParameters.filter { param in
                // Filter out known parameters
                !["kty", "crv", "x", "y", "alg"].contains(param.0)
            },
            rawCBOR: cbor
        )
    }
    
    private func describeCBORKey(_ key: CBORValue) -> String? {
        switch key {
        case .textString(let s): return "\"\(s)\""
        case .unsigned(let u): return "\(u)"
        case .negative(let n): return "\(n)"
        default: return nil
        }
    }
    
    private func describeCBORValue(_ value: CBORValue) -> String {
        switch value {
        case .unsigned(let u): return "\(u)"
        case .negative(let n): return "\(n)"
        case .byteString(let d): return "[\(d.count) bytes]"
        case .textString(let s): return "\"\(s)\""
        case .array(let arr): return "[\(arr.count) elements]"
        case .map(let pairs): return "{\(pairs.count) entries}"
        default: return "\(value)"
        }
    }
    
    private func buildTrustChainSection() -> AttestationSemanticModel.TrustChainSection {
        var certificates: [AttestationSemanticModel.CertificateInfo] = []
        
        for (index, certDER) in attestationStatement.x5c.enumerated() {
            let role = index == 0 ? "Leaf" : index == attestationStatement.x5c.count - 1 ? "Root" : "Intermediate"
            
            if let cert = try? X509Certificate.parse(der: certDER) {
                let certInfo = buildCertificateInfo(cert: cert, role: role, index: index, rawDER: certDER)
                certificates.append(certInfo)
            }
        }
        
        let chainStructure: String
        if certificates.count == 1 {
            chainStructure = "root"
        } else if certificates.count == 2 {
            chainStructure = "leaf → root"
        } else {
            chainStructure = "leaf → \(certificates.count - 2) intermediate(s) → root"
        }
        
        return AttestationSemanticModel.TrustChainSection(
            certificates: certificates,
            chainStructure: chainStructure
        )
    }
    
    private func buildCertificateInfo(cert: X509Certificate, role: String, index: Int, rawDER: Data) -> AttestationSemanticModel.CertificateInfo {
        let subject = buildDistinguishedName(cert.subject)
        let issuer = buildDistinguishedName(cert.issuer)
        
        let sigAlg = AttestationSemanticModel.AlgorithmInfo(
            oid: cert.signatureAlgorithmOID,
            name: X509Helpers.signatureAlgorithmName(for: cert.signatureAlgorithmOID)
        )
        
        let pubKeyAlgName = X509Helpers.publicKeyAlgorithmName(for: cert.subjectPublicKeyAlgorithmOID)
        let pubKeyDetails = X509Helpers.publicKeyDetails(algorithmOID: cert.subjectPublicKeyAlgorithmOID, keyBits: cert.subjectPublicKeyBits)
        
        let pubKey = AttestationSemanticModel.PublicKeyInfo(
            algorithm: pubKeyAlgName,
            type: pubKeyDetails.type,
            curve: pubKeyDetails.curve,
            keySize: pubKeyDetails.keySize,
            rawLength: cert.subjectPublicKeyBits?.count ?? 0
        )
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime, .withTimeZone]
        
        let validity = AttestationSemanticModel.ValidityInfo(
            notBefore: cert.validity.notBefore,
            notAfter: cert.validity.notAfter,
            durationDays: X509Helpers.validityDurationDays(notBefore: cert.validity.notBefore, notAfter: cert.validity.notAfter),
            formatted: (
                notBefore: formatter.string(from: cert.validity.notBefore),
                notAfter: formatter.string(from: cert.validity.notAfter)
            )
        )
        
        var extensions: [AttestationSemanticModel.ExtensionInfo] = []
        for (oid, ext) in cert.decodedExtensions.sorted(by: { $0.key < $1.key }) {
            let rawDER = cert.extensions[oid] ?? Data()
            let extInfo = buildExtensionInfo(oid: oid, ext: ext, rawDER: rawDER)
            extensions.append(extInfo)
        }
        
        return AttestationSemanticModel.CertificateInfo(
            role: role,
            index: index,
            subject: subject,
            issuer: issuer,
            serialNumber: cert.serialNumber.map { String(format: "%02x", $0) }.joined(),
            signatureAlgorithm: sigAlg,
            publicKey: pubKey,
            validity: validity,
            extensions: extensions,
            rawDER: rawDER
        )
    }
    
    private func buildDistinguishedName(_ name: X509Name) -> AttestationSemanticModel.DistinguishedNameInfo {
        let fullDN = X509Helpers.formatDN(name)
        var attributes: [AttestationSemanticModel.AttributeInfo] = []
        
        for atv in name.attributes {
            let oid = atv.oid
            let attrName = X509OID.name(for: oid)
            let value = atv.value
            attributes.append(AttestationSemanticModel.AttributeInfo(oid: oid, name: attrName, value: value))
        }
        
        return AttestationSemanticModel.DistinguishedNameInfo(
            fullDN: fullDN,
            attributes: attributes
        )
    }
    
    private func buildExtensionInfo(oid: String, ext: X509Extension, rawDER: Data) -> AttestationSemanticModel.ExtensionInfo {
        let name = X509OID.name(for: oid)
        let critical = false // TODO: extract from certificate if available
        
        let decoded: AttestationSemanticModel.DecodedExtension?
        switch ext {
        case .basicConstraints(let isCA, let pathLength):
            decoded = .basicConstraints(isCA: isCA, pathLength: pathLength)
        case .keyUsage(let usages):
            decoded = .keyUsage(usages.map { AttestationSemanticModel.KeyUsageFlag(name: $0.name, bit: $0.rawValue) })
        case .extendedKeyUsage(let usages):
            decoded = .extendedKeyUsage(usages.map { usage in
                let oid: String
                switch usage {
                case .serverAuth: oid = "1.3.6.1.5.5.7.3.1"
                case .clientAuth: oid = "1.3.6.1.5.5.7.3.2"
                case .codeSigning: oid = "1.3.6.1.5.5.7.3.3"
                case .emailProtection: oid = "1.3.6.1.5.5.7.3.4"
                case .timeStamping: oid = "1.3.6.1.5.5.7.3.8"
                case .ocspSigning: oid = "1.3.6.1.5.5.7.3.9"
                case .unknown(let unknownOID): oid = unknownOID
                }
                return AttestationSemanticModel.ExtendedKeyUsageOID(oid: oid, name: usage.name)
            })
        case .subjectKeyIdentifier(let keyId):
            decoded = .subjectKeyIdentifier(keyId)
        case .authorityKeyIdentifier(let keyId, let issuer, let serial):
            decoded = .authorityKeyIdentifier(keyId: keyId, issuer: issuer, serial: serial)
        case .subjectAlternativeName(let names):
            decoded = .subjectAlternativeName(names.map { name in
                switch name {
                case .dnsName(let s): return .dnsName(s)
                case .directoryName(let d): return .directoryName(d)
                case .uri(let s): return .uri(s)
                case .ipAddress(let d): return .ipAddress(d)
                case .other(let tag, let d): return .other(tag, d)
                }
            })
        case .appleOID(_, let appleExt):
            switch appleExt.type {
            case .challenge(let hash):
                decoded = .appleChallenge(hash)
            case .receipt(let receipt):
                decoded = .appleReceipt(AttestationSemanticModel.AppleReceiptInfo(
                    bundleID: receipt.bundleID,
                    teamID: receipt.teamID,
                    appVersion: receipt.appVersion,
                    receiptCreationDate: receipt.receiptCreationDate,
                    receiptExpirationDate: receipt.receiptExpirationDate,
                    rawCBOR: receipt.rawCBOR
                ))
            case .keyPurpose(let purpose):
                decoded = .appleKeyPurpose(purpose)
            case .environment(let env):
                decoded = .appleEnvironment(env)
            case .osVersion(let version):
                decoded = .appleOSVersion(version)
            case .deviceClass(let dc):
                decoded = .appleDeviceClass(dc)
            case .unknown:
                decoded = nil
            }
        case .unknown:
            decoded = nil
        }
        
        return AttestationSemanticModel.ExtensionInfo(
            oid: oid,
            name: name,
            critical: critical,
            decoded: decoded,
            rawDER: rawDER,
            rawLength: rawDER.count
        )
    }
    
    private func buildPlatformClaimsSection() -> AttestationSemanticModel.PlatformClaimsSection {
        var environment: String? = nil
        var osVersion: String? = nil
        var deviceClass: String? = nil
        var keyPurpose: String? = nil
        
        if let leafCertDER = attestationStatement.x5c.first,
           let leafCert = try? X509Certificate.parse(der: leafCertDER) {
            for (_, ext) in leafCert.decodedExtensions {
                if case .appleOID(_, let appleExt) = ext {
                    switch appleExt.type {
                    case .environment(let env):
                        environment = env
                    case .osVersion(let version):
                        osVersion = version
                    case .deviceClass(let dc):
                        deviceClass = dc
                    case .keyPurpose(let purpose):
                        keyPurpose = purpose
                    default:
                        break
                    }
                }
            }
        }
        
        return AttestationSemanticModel.PlatformClaimsSection(
            environment: environment,
            osVersion: osVersion,
            deviceClass: deviceClass,
            keyPurpose: keyPurpose
        )
    }
    
    private func buildReceiptSection() -> AttestationSemanticModel.ReceiptSection? {
        guard case .map(let mapPairs) = attestationStatement.rawCBOR,
              let receiptValue = mapPairs.first(where: { key, _ in
                  if case .textString("receipt") = key { return true }
                  return false
              })?.1,
              case .byteString(let receiptData) = receiptValue else {
            return nil
        }
        
        // Try CMS first
        if let cms = try? CMSSignedData.parse(der: receiptData) {
            let cmsInfo = buildCMSSignedDataInfo(cms: cms)
            return AttestationSemanticModel.ReceiptSection(
                containerType: "CMS SignedData (PKCS#7, RFC 5652)",
                structure: .cms(cmsInfo),
                rawData: receiptData
            )
        }
        
        // Try CBOR - actually parse it
        do {
            let cbor = try CBORDecoder.decode(receiptData)
            // Try to decode as Apple receipt structure
            var decodeError: String? = nil
            if case .map(let pairs) = cbor {
                // Successfully decoded as CBOR map
                let cborInfo = AttestationSemanticModel.CBORStructureInfo(
                    majorType: describeCBORMajorType(cbor),
                    structure: "CBOR Map (\(pairs.count) entries)",
                    decoded: cbor
                )
                return AttestationSemanticModel.ReceiptSection(
                    containerType: "CBOR",
                    structure: .cbor(cborInfo),
                    rawData: receiptData
                )
            } else {
                decodeError = "CBOR decoded but not a map (type: \(describeCBORMajorType(cbor)))"
            }
            
            // If decode failed, still show structure
            let cborInfo = AttestationSemanticModel.CBORStructureInfo(
                majorType: describeCBORMajorType(cbor),
                structure: "CBOR \(describeCBORStructure(cbor))" + (decodeError != nil ? " (decode error: \(decodeError!))" : ""),
                decoded: cbor
            )
            return AttestationSemanticModel.ReceiptSection(
                containerType: "CBOR",
                structure: .cbor(cborInfo),
                rawData: receiptData
            )
        } catch let error {
            // CBOR decode failed - show error
            return AttestationSemanticModel.ReceiptSection(
                containerType: "CBOR (parse failed)",
                structure: .opaque(reason: "CBOR decode error: \(error)"),
                rawData: receiptData
            )
        }
        
        // Try ASN.1
        var asn1Reader = ASN1Reader(receiptData)
        if let tlv = try? asn1Reader.readTLV() {
            let asn1Info = AttestationSemanticModel.ASN1StructureInfo(
                tag: describeASN1Tag(tlv.tag),
                tagClass: describeASN1Class(tlv.tag),
                constructed: tlv.tag.constructed,
                length: tlv.length,
                description: "ASN.1 \(describeASN1Tag(tlv.tag))"
            )
            return AttestationSemanticModel.ReceiptSection(
                containerType: "ASN.1 DER",
                structure: .asn1(asn1Info),
                rawData: receiptData
            )
        }
        
        // Try Property List
        if let _ = try? PropertyListSerialization.propertyList(from: receiptData, options: [], format: nil) {
            return AttestationSemanticModel.ReceiptSection(
                containerType: "Property List",
                structure: .plist(AttestationSemanticModel.PropertyListInfo(format: "binary", rootType: "unknown")),
                rawData: receiptData
            )
        }
        
        // Opaque
        return AttestationSemanticModel.ReceiptSection(
            containerType: "Unknown",
            structure: .opaque(reason: "No recognizable structure (not CMS, CBOR, ASN.1, or plist)"),
            rawData: receiptData
        )
    }
    
    private func buildCMSSignedDataInfo(cms: CMSSignedData) -> AttestationSemanticModel.CMSSignedDataInfo {
        let digestAlgNames = cms.digestAlgorithms.map { $0.name }
        
        var certInfos: [AttestationSemanticModel.CertificateInfo] = []
        for (idx, certDER) in cms.certificates.enumerated() {
            if let cert = try? X509Certificate.parse(der: certDER) {
                certInfos.append(buildCertificateInfo(cert: cert, role: "CMS Certificate", index: idx, rawDER: certDER))
            }
        }
        
        var signers: [AttestationSemanticModel.SignerInfo] = []
        for signer in cms.signerInfos {
            let identifier: AttestationSemanticModel.SignerIdentifier
            switch signer.sid.type {
            case .issuerAndSerialNumber(let issuer, let serial):
                identifier = .issuerAndSerialNumber(
                    issuer: buildDistinguishedName(issuer),
                    serial: serial.map { String(format: "%02x", $0) }.joined()
                )
            case .subjectKeyIdentifier(let keyId):
                identifier = .subjectKeyIdentifier(keyId.map { String(format: "%02x", $0) }.joined())
            }
            
            signers.append(AttestationSemanticModel.SignerInfo(
                version: signer.version,
                identifier: identifier,
                digestAlgorithm: signer.digestAlgorithm.name,
                signatureAlgorithm: signer.signatureAlgorithmName,
                signatureLength: signer.signature.count,
                signedAttrsLength: signer.signedAttrs?.count
            ))
        }
        
        // Try to detect payload structure
        let payload = cms.encapContentInfo.content
        var payloadStructure: AttestationSemanticModel.PayloadStructure? = nil
        if !payload.isEmpty {
            var payloadReader = ASN1Reader(payload)
            if let _ = try? payloadReader.readTLV() {
                payloadStructure = .asn1("ASN.1 DER")
            } else if let _ = try? CBORDecoder.decode(payload) {
                payloadStructure = .cbor("CBOR")
            } else if let _ = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) {
                payloadStructure = .plist("Property List")
            } else {
                payloadStructure = .opaque("Unknown format")
            }
        }
        
        return AttestationSemanticModel.CMSSignedDataInfo(
            version: cms.version,
            digestAlgorithms: digestAlgNames,
            contentType: cms.encapContentInfo.contentType,
            contentTypeName: cms.encapContentInfo.contentTypeName,
            payloadSize: cms.encapContentInfo.content.count,
            certificates: certInfos,
            signers: signers,
            payloadStructure: payloadStructure
        )
    }
    
    private func describeCBORMajorType(_ value: CBORValue) -> String {
        switch value {
        case .unsigned, .negative: return "Integer"
        case .byteString: return "Byte String"
        case .textString: return "Text String"
        case .array: return "Array"
        case .map: return "Map"
        case .tagged: return "Tagged"
        case .simple: return "Simple"
        case .boolean: return "Boolean"
        case .null: return "Null"
        case .undefined: return "Undefined"
        }
    }
    
    private func describeCBORStructure(_ value: CBORValue) -> String {
        switch value {
        case .array(let arr): return "Array (\(arr.count) elements)"
        case .map(let pairs): return "Map (\(pairs.count) entries)"
        default: return describeCBORMajorType(value)
        }
    }
    
    private func describeASN1Tag(_ tag: ASN1Tag) -> String {
        switch tag {
        case .sequence: return "SEQUENCE"
        case .set: return "SET"
        case .octetString: return "OCTET STRING"
        case .integer: return "INTEGER"
        case .oid: return "OBJECT IDENTIFIER"
        case .utf8String: return "UTF8String"
        case .printableString: return "PrintableString"
        case .ia5String: return "IA5String"
        default: return "Tag 0x\(String(format: "%02X", tag.raw))"
        }
    }
    
    private func describeASN1Class(_ tag: ASN1Tag) -> String {
        let tagClass = tag.tagClass
        switch tagClass {
        case 0b0000_0000: return "Universal"
        case 0b0100_0000: return "Application"
        case 0b1000_0000: return "Context-specific"
        case 0b1100_0000: return "Private"
        default: return "Unknown"
        }
    }
    
    private func buildRawEvidenceSection() -> AttestationSemanticModel.RawEvidenceSection {
        var extensions: [AttestationSemanticModel.ExtensionRaw] = []
        
        if let leafCertDER = attestationStatement.x5c.first,
           let leafCert = try? X509Certificate.parse(der: leafCertDER) {
            for (oid, ext) in leafCert.decodedExtensions {
                let rawDER = leafCert.extensions[oid] ?? Data()
                extensions.append(AttestationSemanticModel.ExtensionRaw(
                    oid: oid,
                    critical: false, // TODO: extract if available
                    rawDER: rawDER,
                    asn1Tree: nil // TODO: build ASN.1 tree
                ))
            }
        }
        
        return AttestationSemanticModel.RawEvidenceSection(
            attestationObjectCBOR: rawData ?? Data(),
            authenticatorData: authenticatorData.rawData,
            attestationStatement: AttestationSemanticModel.AttestationStatementRaw(
                rawCBOR: Data(), // TODO: extract from rawCBOR
                signature: attestationStatement.signature.isEmpty ? nil : attestationStatement.signature,
                algorithm: attestationStatement.alg.map { "\($0)" }
            ),
            certificates: attestationStatement.x5c,
            extensions: extensions,
            receipt: nil // TODO: extract receipt raw data
        )
    }
}
