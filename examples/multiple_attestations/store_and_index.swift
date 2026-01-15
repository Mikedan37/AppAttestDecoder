#!/usr/bin/env swift
// Multiple attestations storage and indexing example
// Usage: ./store_and_index.swift <attestation1.b64> [attestation2.b64] ...

import Foundation
import AppAttestCore

// Storage structure for attestation metadata
// This stores decoded information only, no trust decisions
struct AttestationMetadata {
    let credentialID: String
    let timestamp: Date
    let deviceID: String?
    let osVersion: String?
    let environment: String?
    let certificateCount: Int
    let hasReceipt: Bool
    
    // This is metadata storage, not a trust decision
    // Verification must happen separately on the server
}

// Index by credential ID to track key lifecycle
var attestationIndex: [String: [AttestationMetadata]] = [:]

let decoder = AppAttestDecoder(teamID: nil)

for attestationPath in CommandLine.arguments.dropFirst() {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: attestationPath)),
          let base64 = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          let attestationData = Data(base64Encoded: base64) else {
        print("Error: Failed to read attestation from \(attestationPath)")
        continue
    }
    
    do {
        let attestation = try decoder.decodeAttestationObject(attestationData)
        let model = try attestation.buildSemanticModel()
        
        // Extract credential ID
        guard let credential = model.credential else {
            print("Warning: No credential data in \(attestationPath)")
            continue
        }
        
        let credentialID = credential.credentialId.hex
        
        // Extract metadata (inspection only, no trust decisions)
        let metadata = AttestationMetadata(
            credentialID: credentialID,
            timestamp: Date(),
            deviceID: nil, // Device ID not available in attestation
            osVersion: model.platformClaims.osVersion,
            environment: model.platformClaims.environment,
            certificateCount: model.trustChain.certificates.count,
            hasReceipt: model.receipt != nil
        )
        
        // Index by credential ID
        if attestationIndex[credentialID] == nil {
            attestationIndex[credentialID] = []
        }
        attestationIndex[credentialID]?.append(metadata)
        
        print("Stored attestation: \(attestationPath)")
        print("  Credential ID: \(credentialID)")
        print("  OS Version: \(metadata.osVersion ?? "unknown")")
        print("  Environment: \(metadata.environment ?? "unknown")")
        print("  Certificates: \(metadata.certificateCount)")
        print("  Receipt: \(metadata.hasReceipt ? "present" : "absent")")
        print("")
        
    } catch {
        print("Error: Failed to decode \(attestationPath): \(error)")
        continue
    }
}

// Print index summary
print("=== Index Summary ===")
print("Total credential IDs: \(attestationIndex.count)")
for (credentialID, attestations) in attestationIndex {
    print("Credential ID: \(credentialID)")
    print("  Attestations: \(attestations.count)")
    print("  First seen: \(attestations.first?.timestamp ?? Date())")
    print("  Last seen: \(attestations.last?.timestamp ?? Date())")
    print("")
}

// This is metadata storage only
// No trust decisions are made here
// Verification must happen separately on the server
