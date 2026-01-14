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
    private var statusLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if App Attest is supported
        guard service.isSupported else {
            showError("App Attest not supported on this device")
            return
        }
        
        setupUI()
    }
    
    private func setupUI() {
        // Hide the default text view
        textView.isHidden = true
        
        // Create container view for our UI
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Status label
        let statusLabel = UILabel()
        statusLabel.text = "Action Extension App Attest Probe"
        statusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        self.statusLabel = statusLabel
        
        // Key ID display
        let keyIDLabel = UILabel()
        keyIDLabel.text = "Key ID: Not generated"
        keyIDLabel.font = .systemFont(ofSize: 12, design: .monospaced)
        keyIDLabel.textColor = .secondaryLabel
        keyIDLabel.numberOfLines = 2
        keyIDLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(keyIDLabel)
        
        // Generate Key button
        let generateKeyButton = UIButton(type: .system)
        generateKeyButton.setTitle("1. Generate Key", for: .normal)
        generateKeyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        generateKeyButton.addTarget(self, action: #selector(generateKeyTapped), for: .touchUpInside)
        generateKeyButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(generateKeyButton)
        
        // Attest Key button
        let attestKeyButton = UIButton(type: .system)
        attestKeyButton.setTitle("2. Attest Key", for: .normal)
        attestKeyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        attestKeyButton.addTarget(self, action: #selector(attestKeyTapped), for: .touchUpInside)
        attestKeyButton.isEnabled = false
        attestKeyButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(attestKeyButton)
        
        // Store references for later updates
        self.keyIDLabel = keyIDLabel
        self.generateKeyButton = generateKeyButton
        self.attestKeyButton = attestKeyButton
        
        // Layout constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            statusLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            keyIDLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            keyIDLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            keyIDLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            generateKeyButton.topAnchor.constraint(equalTo: keyIDLabel.bottomAnchor, constant: 24),
            generateKeyButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            generateKeyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            generateKeyButton.heightAnchor.constraint(equalToConstant: 44),
            
            attestKeyButton.topAnchor.constraint(equalTo: generateKeyButton.bottomAnchor, constant: 16),
            attestKeyButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            attestKeyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            attestKeyButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private var keyIDLabel: UILabel?
    private var generateKeyButton: UIButton?
    private var attestKeyButton: UIButton?
    
    @objc private func generateKeyTapped() {
        statusLabel?.text = "Generating key..."
        generateKeyButton?.isEnabled = false
        
        service.generateKey { [weak self] keyID, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.statusLabel?.text = "Error: \(error.localizedDescription)"
                    self.generateKeyButton?.isEnabled = true
                    return
                }
                
                guard let keyID = keyID else {
                    self.statusLabel?.text = "Error: Key generation returned nil"
                    self.generateKeyButton?.isEnabled = true
                    return
                }
                
                self.keyID = keyID
                self.keyIDLabel?.text = "Key ID: \(keyID)"
                self.statusLabel?.text = "Key generated successfully"
                self.generateKeyButton?.isEnabled = true
                self.attestKeyButton?.isEnabled = true
                print("[ActionExtension] Generated keyID: \(keyID)")
            }
        }
    }
    
    @objc private func attestKeyTapped() {
        guard let keyID = keyID else {
            statusLabel?.text = "Error: Generate key first"
            return
        }
        
        statusLabel?.text = "Attesting key..."
        attestKeyButton?.isEnabled = false
        
        let challenge = UUID().uuidString.data(using: .utf8)!
        let clientDataHash = Data(SHA256.hash(data: challenge))
        
        service.attestKey(keyID, clientDataHash: clientDataHash) { [weak self] attestBlob, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.statusLabel?.text = "Error: \(error.localizedDescription)"
                    self.attestKeyButton?.isEnabled = true
                    return
                }
                
                guard let attestBlob = attestBlob else {
                    self.statusLabel?.text = "Error: Attestation returned nil"
                    self.attestKeyButton?.isEnabled = true
                    return
                }
                
                self.attestationBlob = attestBlob
                self.statusLabel?.text = "Attestation generated (\(attestBlob.count) bytes)"
                self.attestKeyButton?.isEnabled = true
                print("[ActionExtension] Generated attestation: \(attestBlob.count) bytes")
                
                // Save to App Group for decoder
                self.saveToAppGroup(keyID: keyID, attestation: attestBlob, clientDataHash: clientDataHash)
                
                // Show success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showSuccess()
                }
            }
        }
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

