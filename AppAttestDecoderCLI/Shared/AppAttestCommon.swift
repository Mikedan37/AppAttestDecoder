//
//  AppAttestCommon.swift
//  Shared utilities for App Attest test app and CLI
//
//  Created by Michael Danylchuk
//

import Foundation
import CryptoKit

// MARK: - Canonical Artifact Container

public struct AppAttestArtifacts: Codable {
    public let keyID: String
    public let clientDataHash: Data
    public let attestationObject: Data?
    public let assertionObject: Data?

    public init(
        keyID: String,
        clientDataHash: Data,
        attestationObject: Data? = nil,
        assertionObject: Data? = nil
    ) {
        self.keyID = keyID
        self.clientDataHash = clientDataHash
        self.attestationObject = attestationObject
        self.assertionObject = assertionObject
    }
}

// MARK: - Base64 Utilities

public enum AppAttestBase64 {

    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
    }

    public static func decode(_ string: String) -> Data? {
        Data(base64Encoded: string)
    }
}

// MARK: - Client Data Hash Helpers

public enum AppAttestClientData {

    public static func hash(challenge: Data) -> Data {
        Data(SHA256.hash(data: challenge))
    }

    public static func hashBase64(challenge: Data) -> String {
        AppAttestBase64.encode(hash(challenge: challenge))
    }
}

// MARK: - Debug / Inspection Helpers

public enum AppAttestDebug {

    public static func describe(label: String, data: Data) -> String {
        """
        \(label)
        ├─ size: \(data.count) bytes
        └─ base64:
        \(data.base64EncodedString())
        """
    }

    public static func describeArtifacts(_ artifacts: AppAttestArtifacts) -> String {
        var output = ""

        output += "Key ID:\n\(artifacts.keyID)\n\n"
        output += describe(label: "Client Data Hash", data: artifacts.clientDataHash) + "\n\n"

        if let attestation = artifacts.attestationObject {
            output += describe(label: "Attestation Object", data: attestation) + "\n\n"
        }

        if let assertion = artifacts.assertionObject {
            output += describe(label: "Assertion Object", data: assertion) + "\n\n"
        }

        return output
    }
}

// MARK: - Clipboard Helpers (String Normalization)

public enum AppAttestClipboard {

    public static func stringForCopy(_ data: Data) -> String {
        data.base64EncodedString()
    }

    public static func stringForCopy(_ string: String) -> String {
        string
    }
}

// MARK: - Optional Fixture Loading

public enum AppAttestFixtures {

    public static func loadBase64(named name: String, bundle: Bundle = .main) -> Data? {
        guard let url = bundle.url(forResource: name, withExtension: "b64") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
}
