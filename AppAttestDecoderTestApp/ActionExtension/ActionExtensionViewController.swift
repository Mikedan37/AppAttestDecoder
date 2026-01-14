//
//  ActionExtensionViewController.swift
//  ActionExtension
//
//  Action Extension App Attest Identity Probe
//
//  Purpose: Prove that an Action Extension can generate its own App Attest identity.
//  This is a probe, not a security gate. We're proving a primitive exists.
//
//  Goal: Answer with zero ambiguity:
//  "Can an Action Extension produce a distinct, verifiable App Attest attestation?"
//
//  What this does:
//  - Generates its own App Attest key (distinct from main app)
//  - Produces an attestation from within Share Sheet context
//  - Makes the attestation observable (saves to App Group for decoder)
//
//  What this does NOT do:
//  - No verification yet
//  - No backend logic
//  - No policy enforcement
//  - Just generate and attest
//
//  This demonstrates: Apple treats Action Extensions as a separate trust principal
//  with hardware-backed identity.
//

import UIKit
import Social
import DeviceCheck
import CryptoKit

class ActionExtensionViewController: SLComposeServiceViewController {
    
    private let service = DCAppAttestService.shared
    private var keyID: String?
    private var attestationBlob: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if App Attest is supported
        guard service.isSupported else {
            showError("App Attest not supported on this device")
            return
        }
        
        // Generate key and attestation
        generateAttestation()
    }
    
    private func generateAttestation() {
        // Step 1: Generate key
        service.generateKey { [weak self] keyID, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.showError("Failed to generate key: \(error.localizedDescription)")
                }
                return
            }
            
            guard let keyID = keyID else {
                DispatchQueue.main.async {
                    self.showError("Key generation returned nil")
                }
                return
            }
            
            self.keyID = keyID
            print("[ActionExtension] Generated keyID: \(keyID)")
            
            // Step 2: Attest the key
            let challenge = UUID().uuidString.data(using: .utf8)!
            let clientDataHash = Data(SHA256.hash(data: challenge))
            
            self.service.attestKey(keyID, clientDataHash: clientDataHash) { [weak self] attestBlob, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.showError("Failed to attest key: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let attestBlob = attestBlob else {
                    DispatchQueue.main.async {
                        self.showError("Attestation returned nil")
                    }
                    return
                }
                
                self.attestationBlob = attestBlob
                print("[ActionExtension] Generated attestation: \(attestBlob.count) bytes")
                
                // Save to App Group for host app to retrieve
                self.saveToAppGroup(keyID: keyID, attestation: attestBlob, clientDataHash: clientDataHash)
                
                DispatchQueue.main.async {
                    self.showSuccess()
                }
            }
        }
    }
    
    private func saveToAppGroup(keyID: String, attestation: Data, clientDataHash: Data) {
        // Save to shared App Group container
        // Replace "group.com.example.AppAttestDecoder" with your actual App Group ID
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.AppAttestDecoder") else {
            print("[ActionExtension] Failed to get App Group container")
            return
        }
        
        let samplesDir = containerURL.appendingPathComponent("AttestationSamples", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)
        
        // Create sample file
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "action-extension-\(timestamp).json"
        let fileURL = samplesDir.appendingPathComponent(filename)
        
        // Create AttestationSample JSON
        let sample: [String: Any] = [
            "context": "action",
            "bundleID": Bundle.main.bundleIdentifier ?? "unknown",
            "teamID": "YOUR_TEAM_ID", // Replace with actual Team ID
            "keyID": keyID,
            "attestationObjectBase64": attestation.base64EncodedString(),
            "timestamp": timestamp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: sample, options: .prettyPrinted) else {
            print("[ActionExtension] Failed to serialize sample")
            return
        }
        
        do {
            try jsonData.write(to: fileURL)
            print("[ActionExtension] Saved sample to: \(fileURL.path)")
        } catch {
            print("[ActionExtension] Failed to write sample: \(error)")
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
        present(alert, animated: true)
    }
    
    private func showSuccess() {
        let alert = UIAlertController(
            title: "Attestation Generated",
            message: "Attestation has been saved to App Group container for analysis.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
        present(alert, animated: true)
    }
    
    // MARK: - SLComposeServiceViewController
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        // This is called when the user taps Post
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
}

