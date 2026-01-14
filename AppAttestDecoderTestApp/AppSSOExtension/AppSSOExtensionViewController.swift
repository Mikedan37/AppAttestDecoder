//
//  AppSSOExtensionViewController.swift
//  AppSSOExtension
//
//  This file implements an App SSO Extension that demonstrates trust delegation
//  and identity-adjacent trust surfaces. This extension does NOT generate its own
//  attestation. Instead, it requests an assertion from the main app and uses it
//  as an identity-bound signal in an SSO-style flow.
//
//  This demonstrates:
//  - Trust delegation (main app → extension)
//  - Identity-adjacent trust surfaces
//  - Non-primary execution context signaling
//
//  Important:
//  - This extension does NOT generate attestations
//  - It uses assertions from the main app
//  - Artifacts are captured for decoding + annotation
//  - No validation or security claims are made
//

import UIKit
import AuthenticationServices
import DeviceCheck
import CryptoKit

class AppSSOExtensionViewController: ASCredentialProviderViewController {
    
    private let service = DCAppAttestService.shared
    private var assertionBlob: Data?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if App Attest is supported
        guard service.isSupported else {
            showError("App Attest not supported on this device")
            return
        }
        
        // Request assertion from main app
        // In a real SSO flow, this would be triggered by an authentication request
        requestAssertionFromMainApp()
    }
    
    private func requestAssertionFromMainApp() {
        // This extension generates its own App Attest key (distinct identity).
        // We model each execution context as a distinct trust surface.
        // No keys are shared. No identity is unified.
        
        // Generate our own key for this extension context
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
            
            // Generate attestation for this extension's key
            self.generateAttestation(keyID: keyID)
        }
    }
    
    private func generateAttestation(keyID: String) {
        let challenge = UUID().uuidString.data(using: .utf8)!
        let clientDataHash = Data(SHA256.hash(data: challenge))
        
        service.attestKey(keyID, clientDataHash: clientDataHash) { [weak self] attestBlob, error in
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
            
            // Save to App Group for analysis
            self.saveToAppGroup(keyID: keyID, attestation: attestBlob, clientDataHash: clientDataHash)
            
            DispatchQueue.main.async {
                self.showSuccess()
            }
        }
    }
    
    
    private func saveToAppGroup(keyID: String, attestation: Data, clientDataHash: Data) {
        // Save to shared App Group container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.AppAttestDecoder") else {
            print("[AppSSOExtension] Failed to get App Group container")
            return
        }
        
        let samplesDir = containerURL.appendingPathComponent("AttestationSamples", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)
        
        // Create sample file
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "app-sso-extension-\(timestamp).json"
        let fileURL = samplesDir.appendingPathComponent(filename)
        
        // Create AttestationSample JSON
        let sample: [String: Any] = [
            "context": "sso",
            "bundleID": Bundle.main.bundleIdentifier ?? "unknown",
            "teamID": "YOUR_TEAM_ID", // Replace with actual Team ID
            "keyID": keyID,
            "attestationObjectBase64": attestation.base64EncodedString(),
            "timestamp": timestamp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: sample, options: .prettyPrinted) else {
            print("[AppSSOExtension] Failed to serialize sample")
            return
        }
        
        do {
            try jsonData.write(to: fileURL)
            print("[AppSSOExtension] Saved sample to: \(fileURL.path)")
        } catch {
            print("[AppSSOExtension] Failed to write sample: \(error)")
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.extensionContext.cancelRequest(withError: NSError(domain: "AppSSOExtension", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
        })
        present(alert, animated: true)
    }
    
    private func showSuccess() {
        let alert = UIAlertController(
            title: "Assertion Generated",
            message: "Assertion has been saved to App Group container for analysis.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            // Complete the credential request
            let credential = ASPasswordCredential(user: "user", password: "token")
            self.extensionContext.completeRequest(withSelectedCredential: credential) { _ in }
        })
        present(alert, animated: true)
    }
    
    // MARK: - ASCredentialProviderViewController
    
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // Prepare credential list
    }
    
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Provide credential without user interaction
        let credential = ASPasswordCredential(user: credentialIdentity.user, password: "token")
        extensionContext.completeRequest(withSelectedCredential: credential) { _ in }
    }
}

