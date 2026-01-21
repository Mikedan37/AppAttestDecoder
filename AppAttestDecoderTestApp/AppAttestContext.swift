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

/// CRITICAL: Single source of truth for clientDataHash per key lifecycle
/// 
/// clientDataHash is generated once at attestation and reused for assertion per App Attest spec.
/// This ensures attestation and assertion use the EXACT same hash.
/// 
/// App Attest identity model: One attestation → one identity → one clientDataHash
/// Breaking this invariant causes silent cryptographic verification failure.
struct ClientDataContext {
    let challenge: Data
    let environment: String
    let timestamp: String // ISO8601
    let rawClientDataJSON: Data
    let clientDataHash: Data // SHA256(rawClientDataJSON) - computed once, reused forever
    
    /// Create a new ClientDataContext (should only be called once per key lifecycle during attestation)
    /// 
    /// Rules:
    /// - Backend provides challenge (or generate client-side if not provided)
    /// - Frontend constructs clientDataJSON and hashes it
    /// - This hash is generated exactly once and reused for assertion
    static func create(challenge: Data? = nil, environment: String = "production") -> ClientDataContext {
        // Backend provides challenge, or generate client-side if not provided
        let challengeData = challenge ?? UUID().uuidString.data(using: .utf8)!
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Frontend constructs clientDataJSON (backend does NOT generate clientDataHash)
        let clientDataDict: [String: Any] = [
            "challenge": challengeData.base64EncodedString(),
            "environment": environment,
            "timestamp": timestamp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: clientDataDict, options: []) else {
            fatalError("Failed to serialize clientData JSON")
        }
        
        // Frontend hashes the JSON (backend does NOT do this)
        let hash = Data(SHA256.hash(data: jsonData))
        
        #if DEBUG
        print("[ClientDataContext] Created new context:")
        print("[ClientDataContext]   challenge (b64): \(challengeData.base64EncodedString())")
        print("[ClientDataContext]   clientDataHash (b64): \(hash.base64EncodedString())")
        print("[ClientDataContext]   timestamp: \(timestamp)")
        #endif
        
        return ClientDataContext(
            challenge: challengeData,
            environment: environment,
            timestamp: timestamp,
            rawClientDataJSON: jsonData,
            clientDataHash: hash
        )
    }
    
    /// Verify this context is valid (debugging)
    func verify() -> Bool {
        let recomputedHash = Data(SHA256.hash(data: rawClientDataJSON))
        return recomputedHash == clientDataHash
    }
}

/// Manages ClientDataContext per keyID to ensure hash reuse
class ClientDataContextManager {
    static let shared = ClientDataContextManager()
    
    private var contexts: [String: ClientDataContext] = [:] // keyID -> ClientDataContext
    private let lock = NSLock()
    
    private init() {}
    
    /// Get or create ClientDataContext for a keyID
    /// CRITICAL: This should ONLY be called during attestation
    /// If context already exists, returns existing (does NOT regenerate)
    func getOrCreateContext(for keyID: String) -> ClientDataContext {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = contexts[keyID] {
            #if DEBUG
            print("[ClientDataContextManager] ⚠ Reusing existing clientDataHash for keyID: \(keyID)")
            print("[ClientDataContextManager]   This should only happen if Attest Key was pressed again")
            print("[ClientDataContextManager]   clientDataHash (b64): \(existing.clientDataHash.base64EncodedString())")
            #endif
            return existing
        }
        
        let newContext = ClientDataContext.create()
        contexts[keyID] = newContext
        
        #if DEBUG
        print("[ClientDataContextManager] Created NEW clientDataContext for keyID: \(keyID)")
        print("[ClientDataContextManager]   clientDataHash (b64): \(newContext.clientDataHash.base64EncodedString())")
        print("[ClientDataContextManager]   challenge (b64): \(newContext.challenge.base64EncodedString())")
        print("[ClientDataContextManager]   timestamp: \(newContext.timestamp)")
        print("[ClientDataContextManager]   This hash will be reused for all assertions with this keyID")
        #endif
        
        return newContext
    }
    
    /// Get existing context (returns nil if not found - use this for assertion)
    func getContext(for keyID: String) -> ClientDataContext? {
        lock.lock()
        defer { lock.unlock() }
        return contexts[keyID]
    }
    
    /// Clear context for a keyID (when generating new key)
    func clearContext(for keyID: String) {
        lock.lock()
        defer { lock.unlock() }
        contexts.removeValue(forKey: keyID)
        #if DEBUG
        print("[ClientDataContextManager] Cleared context for keyID: \(keyID)")
        #endif
    }
    
    /// Verify context exists (hard assertion in DEBUG)
    func requireContext(for keyID: String) -> ClientDataContext {
        guard let context = getContext(for: keyID) else {
            #if DEBUG
            fatalError("CRITICAL: No ClientDataContext exists for keyID \(keyID). Attestation must happen before assertion.")
            #else
            // In release, create one (but this is wrong - should never happen)
            return getOrCreateContext(for: keyID)
            #endif
        }
        return context
    }
}

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

/// Manages the current App Attest keyID to ensure key continuity
/// CRITICAL: The same keyID must be used for attestation and assertion
class AppAttestKeyManager {
    static let shared = AppAttestKeyManager()
    
    private(set) var currentKeyID: String?
    private let lock = NSLock()
    
    private init() {}
    
    /// Set the current keyID (should only be called once after generateKey)
    func setKeyID(_ keyID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = currentKeyID {
            if existing != keyID {
                print("[AppAttestKeyManager] ⚠ WARNING: KeyID changed from \(existing) to \(keyID)")
                print("[AppAttestKeyManager] ⚠ This will cause signature verification to fail!")
            }
        }
        currentKeyID = keyID
        print("[AppAttestKeyManager] KeyID set: \(keyID)")
    }
    
    /// Get the current keyID (must match the one used for attestation)
    func getKeyID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return currentKeyID
    }
    
    /// Verify keyID matches (for debugging)
    func verifyKeyID(_ keyID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentKeyID == keyID
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
