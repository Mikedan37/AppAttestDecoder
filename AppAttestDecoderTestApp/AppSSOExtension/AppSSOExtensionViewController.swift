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
        // In a real implementation, this would:
        // 1. Communicate with the main app via App Group or XPC
        // 2. Request the main app to generate an assertion
        // 3. Receive the assertion blob
        // 4. Use it in the SSO flow
        
        // For research purposes, we'll simulate this by:
        // 1. Checking if we have a stored key ID from the main app
        // 2. Generating an assertion using that key ID
        // 3. Saving the assertion for analysis
        
        // Note: In practice, the main app would have already generated a key
        // and we would retrieve the key ID from shared storage
        guard let keyID = retrieveKeyIDFromMainApp() else {
            showError("No key ID available from main app")
            return
        }
        
        generateAssertion(keyID: keyID)
    }
    
    private func retrieveKeyIDFromMainApp() -> String? {
        // Retrieve key ID from App Group container
        // In a real implementation, this would be stored by the main app
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.AppAttestDecoder") else {
            return nil
        }
        
        let keyIDFile = containerURL.appendingPathComponent("mainAppKeyID.txt")
        return try? String(contentsOf: keyIDFile, encoding: .utf8)
    }
    
    private func generateAssertion(keyID: String) {
        let challenge = UUID().uuidString.data(using: .utf8)!
        let clientDataHash = Data(SHA256.hash(data: challenge))
        
        service.generateAssertion(keyID, clientDataHash: clientDataHash) { [weak self] assertionObject, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.showError("Failed to generate assertion: \(error.localizedDescription)")
                }
                return
            }
            
            guard let assertionObject = assertionObject else {
                DispatchQueue.main.async {
                    self.showError("Assertion generation returned nil")
                }
                return
            }
            
            self.assertionBlob = assertionObject
            print("[AppSSOExtension] Generated assertion: \(assertionObject.count) bytes")
            
            // Save to App Group for analysis
            self.saveToAppGroup(keyID: keyID, assertion: assertionObject, clientDataHash: clientDataHash)
            
            DispatchQueue.main.async {
                self.showSuccess()
            }
        }
    }
    
    private func saveToAppGroup(keyID: String, assertion: Data, clientDataHash: Data) {
        // Save to shared App Group container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.AppAttestDecoder") else {
            print("[AppSSOExtension] Failed to get App Group container")
            return
        }
        
        let samplesDir = containerURL.appendingPathComponent("AssertionSamples", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: samplesDir, withIntermediateDirectories: true)
        
        // Create sample file
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "app-sso-extension-\(timestamp).json"
        let fileURL = samplesDir.appendingPathComponent(filename)
        
        // Create sample JSON (note: assertions don't use AttestationSample, but we'll store metadata)
        let sample: [String: Any] = [
            "context": "sso",
            "bundleID": Bundle.main.bundleIdentifier ?? "unknown",
            "teamID": "YOUR_TEAM_ID", // Replace with actual Team ID
            "keyID": keyID,
            "assertionObjectBase64": assertion.base64EncodedString(),
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

