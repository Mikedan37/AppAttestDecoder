//
//  AppAttestContext.swift
//  AppAttestDecoderTestApp
//
//  Context persistence for App Attest verification.
//  Stores publicKey from attestation and clientDataHash from assertion generation
//  to enable full COSE verification of assertions.
//

import Foundation
import Combine
import CryptoKit

/// Stores verification context for App Attest assertions
struct AppAttestContext: Codable, Identifiable {
    let id: String // keyID
    let keyID: String
    let publicKey: Data // Raw public key bytes from attestation certificate
    let attestationClientDataHash: Data? // clientDataHash used during attestation
    let assertionClientDataHashes: [Data] // Multiple clientDataHashes from assertion generations
    let attestationTimestamp: Date
    let source: String // "Test App", "Imported", etc.
    
    var hasPublicKey: Bool { !publicKey.isEmpty }
    var hasAttestationContext: Bool { attestationClientDataHash != nil }
    var hasAssertionContext: Bool { !assertionClientDataHashes.isEmpty }
    
    /// Returns true if full verification is possible (has both publicKey and at least one clientDataHash)
    var canVerifyAssertion: Bool {
        hasPublicKey && !assertionClientDataHashes.isEmpty
    }
}

/// Manages persistence and retrieval of App Attest verification context
class AppAttestContextStore: ObservableObject {
    static let shared = AppAttestContextStore()
    
    @Published private(set) var contexts: [String: AppAttestContext] = [:]
    
    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        // Store in app's documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsPath.appendingPathComponent("AppAttestContexts.json")
        
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        loadContexts()
    }
    
    /// Load contexts from disk
    private func loadContexts() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? decoder.decode([String: AppAttestContext].self, from: data) else {
            contexts = [:]
            return
        }
        contexts = decoded
    }
    
    /// Save contexts to disk
    private func saveContexts() {
        guard let data = try? encoder.encode(contexts) else { return }
        try? data.write(to: storageURL)
    }
    
    /// Store or update context for a keyID
    func storeContext(
        keyID: String,
        publicKey: Data? = nil,
        attestationClientDataHash: Data? = nil,
        assertionClientDataHash: Data? = nil,
        source: String = "Test App"
    ) {
        let now = Date()
        
        var context = contexts[keyID] ?? AppAttestContext(
            id: keyID,
            keyID: keyID,
            publicKey: publicKey ?? Data(),
            attestationClientDataHash: attestationClientDataHash,
            assertionClientDataHashes: [],
            attestationTimestamp: now,
            source: source
        )
        
        // Update publicKey if provided
        if let publicKey = publicKey {
            context = AppAttestContext(
                id: keyID,
                keyID: keyID,
                publicKey: publicKey,
                attestationClientDataHash: context.attestationClientDataHash ?? attestationClientDataHash,
                assertionClientDataHashes: context.assertionClientDataHashes,
                attestationTimestamp: context.attestationTimestamp,
                source: context.source
            )
        }
        
        // Update attestation clientDataHash if provided
        if let attestationHash = attestationClientDataHash {
            context = AppAttestContext(
                id: keyID,
                keyID: keyID,
                publicKey: context.publicKey,
                attestationClientDataHash: attestationHash,
                assertionClientDataHashes: context.assertionClientDataHashes,
                attestationTimestamp: context.attestationTimestamp,
                source: context.source
            )
        }
        
        // Add assertion clientDataHash if provided (append to list)
        if let assertionHash = assertionClientDataHash {
            var hashes = context.assertionClientDataHashes
            if !hashes.contains(assertionHash) {
                hashes.append(assertionHash)
            }
            context = AppAttestContext(
                id: keyID,
                keyID: keyID,
                publicKey: context.publicKey,
                attestationClientDataHash: context.attestationClientDataHash,
                assertionClientDataHashes: hashes,
                attestationTimestamp: context.attestationTimestamp,
                source: context.source
            )
        }
        
        contexts[keyID] = context
        saveContexts()
    }
    
    /// Retrieve context for a keyID
    func getContext(keyID: String) -> AppAttestContext? {
        return contexts[keyID]
    }
    
    /// Clear all contexts (for testing/debugging)
    func clearAll() {
        contexts = [:]
        try? FileManager.default.removeItem(at: storageURL)
    }
}
