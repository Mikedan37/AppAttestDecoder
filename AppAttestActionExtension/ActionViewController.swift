//
//  ActionViewController.swift
//  AppAttestActionExtension
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
//  - Auto-runs full App Attest flow on load (generate key → attest → assert)
//  - Generates its own App Attest key (distinct from main app)
//  - Produces attestation and assertion from within Share Sheet context
//  - Makes artifacts observable (saves to App Group for decoder)
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

class ActionViewController: SLComposeServiceViewController {
    
    private let service = DCAppAttestService.shared
    
    // State
    private var keyID: String?
    private var attestationBlobB64: String?
    private var assertionBlobB64: String?
    private var lastAttestClientDataHashB64: String?
    private var lastAssertClientDataHashB64: String?
    
    // UI Elements
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var statusLabel: UILabel!
    private var keyIDLabel: UILabel!
    private var keyIDTextView: UITextView!
    private var attestationLabel: UILabel!
    private var attestationTextView: UITextView!
    private var assertionLabel: UILabel!
    private var assertionTextView: UITextView!
    private var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("[ActionExtension] viewDidLoad called - extension is loading!")
        print("[ActionExtension] Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // Hide default text view
        textView.isHidden = true
        
        // Check if App Attest is supported
        guard service.isSupported else {
            print("[ActionExtension] ERROR: App Attest not supported")
            showError("App Attest not supported on this device")
            return
        }
        
        print("[ActionExtension] App Attest is supported, setting up UI...")
        setupUI()
        
        // Auto-run full flow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.runFullFlow()
        }
    }
    
    private func setupUI() {
        // Scroll view for content
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .systemBackground
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Status label
        statusLabel = UILabel()
        statusLabel.text = "Action Extension App Attest Probe"
        statusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // Error label
        errorLabel = UILabel()
        errorLabel.text = ""
        errorLabel.font = .systemFont(ofSize: 14)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(errorLabel)
        
        // Key ID section
        let keyIDTitle = UILabel()
        keyIDTitle.text = "Key ID"
        keyIDTitle.font = .systemFont(ofSize: 12)
        keyIDTitle.textColor = .secondaryLabel
        keyIDTitle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyIDTitle)
        
        keyIDLabel = UILabel()
        keyIDLabel.text = "Not generated"
        keyIDLabel.font = .systemFont(ofSize: 14)
        keyIDLabel.textColor = .secondaryLabel
        keyIDLabel.numberOfLines = 0
        keyIDLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyIDLabel)
        
        keyIDTextView = UITextView()
        keyIDTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        keyIDTextView.isEditable = false
        keyIDTextView.isScrollEnabled = false
        keyIDTextView.backgroundColor = .secondarySystemBackground
        keyIDTextView.layer.cornerRadius = 8
        keyIDTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        keyIDTextView.isHidden = true
        keyIDTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyIDTextView)
        
        // Attestation section
        attestationLabel = UILabel()
        attestationLabel.text = "Attestation Blob (base64)"
        attestationLabel.font = .systemFont(ofSize: 12)
        attestationLabel.textColor = .secondaryLabel
        attestationLabel.isHidden = true
        attestationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(attestationLabel)
        
        attestationTextView = UITextView()
        attestationTextView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        attestationTextView.isEditable = false
        attestationTextView.isScrollEnabled = true
        attestationTextView.backgroundColor = .secondarySystemBackground
        attestationTextView.layer.cornerRadius = 8
        attestationTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        attestationTextView.isHidden = true
        attestationTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(attestationTextView)
        
        // Assertion section
        assertionLabel = UILabel()
        assertionLabel.text = "Assertion Blob (base64)"
        assertionLabel.font = .systemFont(ofSize: 12)
        assertionLabel.textColor = .secondaryLabel
        assertionLabel.isHidden = true
        assertionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(assertionLabel)
        
        assertionTextView = UITextView()
        assertionTextView.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        assertionTextView.isEditable = false
        assertionTextView.isScrollEnabled = true
        assertionTextView.backgroundColor = .secondarySystemBackground
        assertionTextView.layer.cornerRadius = 8
        assertionTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        assertionTextView.isHidden = true
        assertionTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(assertionTextView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Error label
            errorLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            errorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Key ID section
            keyIDTitle.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
            keyIDTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyIDTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            keyIDLabel.topAnchor.constraint(equalTo: keyIDTitle.bottomAnchor, constant: 6),
            keyIDLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyIDLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            keyIDTextView.topAnchor.constraint(equalTo: keyIDLabel.bottomAnchor, constant: 6),
            keyIDTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyIDTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            keyIDTextView.heightAnchor.constraint(equalToConstant: 60),
            
            // Attestation section
            attestationLabel.topAnchor.constraint(equalTo: keyIDTextView.bottomAnchor, constant: 20),
            attestationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            attestationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            attestationTextView.topAnchor.constraint(equalTo: attestationLabel.bottomAnchor, constant: 6),
            attestationTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            attestationTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            attestationTextView.heightAnchor.constraint(equalToConstant: 200),
            
            // Assertion section
            assertionLabel.topAnchor.constraint(equalTo: attestationTextView.bottomAnchor, constant: 20),
            assertionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            assertionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            assertionTextView.topAnchor.constraint(equalTo: assertionLabel.bottomAnchor, constant: 6),
            assertionTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            assertionTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            assertionTextView.heightAnchor.constraint(equalToConstant: 200),
            assertionTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func runFullFlow() {
        updateStatus("Running full App Attest flow...")
        
        // Step 1: Generate Key
        updateStatus("Step 1: Generating key...")
        service.generateKey { [weak self] keyID, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.showError("Failed to generate key: \(error.localizedDescription)")
                    return
                }
                
                guard let keyID = keyID else {
                    self.showError("Key generation returned nil")
                    return
                }
                
                self.keyID = keyID
                self.updateKeyID(keyID)
                print("[ActionExtension] Generated keyID: \(keyID)")
                
                // Step 2: Attest Key
                self.updateStatus("Step 2: Attesting key...")
                let challenge = UUID().uuidString.data(using: .utf8)!
                let clientDataHash = Data(SHA256.hash(data: challenge))
                self.lastAttestClientDataHashB64 = clientDataHash.base64EncodedString()
                print("[ActionExtension] Attest clientDataHash (b64): \(self.lastAttestClientDataHashB64 ?? "")")
                
                self.service.attestKey(keyID, clientDataHash: clientDataHash) { [weak self] attestBlob, error in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let error = error {
                            self.showError("Failed to attest key: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let attestBlob = attestBlob else {
                            self.showError("Attestation returned nil")
                            return
                        }
                        
                        self.attestationBlobB64 = attestBlob.base64EncodedString()
                        self.updateAttestation(self.attestationBlobB64!)
                        print("[ActionExtension] Generated attestation: \(attestBlob.count) bytes")
                        
                        // Step 3: Assert Key
                        self.updateStatus("Step 3: Generating assertion...")
                        let assertChallenge = UUID().uuidString.data(using: .utf8)!
                        let assertClientDataHash = Data(SHA256.hash(data: assertChallenge))
                        self.lastAssertClientDataHashB64 = assertClientDataHash.base64EncodedString()
                        print("[ActionExtension] Assert clientDataHash (b64): \(self.lastAssertClientDataHashB64 ?? "")")
                        
                        self.service.generateAssertion(keyID, clientDataHash: assertClientDataHash) { [weak self] assertionObject, error in
                            guard let self = self else { return }
                            
                            DispatchQueue.main.async {
                                if let error = error {
                                    self.showError("Failed to generate assertion: \(error.localizedDescription)")
                                    return
                                }
                                
                                guard let assertionObject = assertionObject else {
                                    self.showError("Assertion returned nil")
                                    return
                                }
                                
                                self.assertionBlobB64 = assertionObject.base64EncodedString()
                                self.updateAssertion(self.assertionBlobB64!)
                                print("[ActionExtension] Generated assertion: \(assertionObject.count) bytes")
                                
                                // Save to App Group
                                self.saveToAppGroup(
                                    keyID: keyID,
                                    attestation: attestBlob,
                                    assertion: assertionObject,
                                    attestClientDataHash: clientDataHash,
                                    assertClientDataHash: assertClientDataHash
                                )
                                
                                self.updateStatus("✅ Complete! All artifacts generated.")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func updateStatus(_ text: String) {
        statusLabel.text = text
    }
    
    private func updateKeyID(_ keyID: String) {
        keyIDLabel.isHidden = true
        keyIDTextView.isHidden = false
        keyIDTextView.text = keyID
    }
    
    private func updateAttestation(_ base64: String) {
        attestationLabel.isHidden = false
        attestationTextView.isHidden = false
        attestationTextView.text = base64
    }
    
    private func updateAssertion(_ base64: String) {
        assertionLabel.isHidden = false
        assertionTextView.isHidden = false
        assertionTextView.text = base64
    }
    
    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
        updateStatus("❌ Error occurred")
        print("[ActionExtension] ERROR: \(message)")
    }
    
    private func saveToAppGroup(keyID: String, attestation: Data, assertion: Data, attestClientDataHash: Data, assertClientDataHash: Data) {
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
            "context": "actionExtension",
            "bundleID": Bundle.main.bundleIdentifier ?? "unknown",
            "teamID": "YOUR_TEAM_ID", // Replace with actual Team ID
            "keyID": keyID,
            "attestationObjectBase64": attestation.base64EncodedString(),
            "assertionObjectBase64": assertion.base64EncodedString(),
            "attestClientDataHashBase64": attestClientDataHash.base64EncodedString(),
            "assertClientDataHashBase64": assertClientDataHash.base64EncodedString(),
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
    
    // MARK: - SLComposeServiceViewController
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        // This is called when the user taps Post/Done
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
}
