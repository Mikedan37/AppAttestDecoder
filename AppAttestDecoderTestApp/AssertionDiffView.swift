//
//  AssertionDiffView.swift
//  AppAttestDecoderTestApp
//
//  Compares iOS CryptoEvidence (from EvidenceStore) to backend forensics. Dev-only.
//  Green for match, red for mismatch; first differing byte index and hex window when both raw buffers available.
//

import SwiftUI

struct AssertionDiffView: View {
    let runID: String
    let backend: BackendForensics?

    private var ios: CryptoEvidence? { runID.isEmpty ? nil : EvidenceStore.shared.get(runID) }

    private func cmp(_ label: String, _ a: String?, _ b: String?) -> (match: Bool, a: String, b: String) {
        let ai = a ?? "—"
        let bi = b ?? "—"
        return (ai == bi && !ai.isEmpty && ai != "—", ai, bi)
    }

    private func firstDiffIndex(_ d1: Data, _ d2: Data) -> Int? {
        for i in 0..<min(d1.count, d2.count) {
            if d1[i] != d2[i] { return i }
        }
        if d1.count != d2.count { return min(d1.count, d2.count) }
        return nil
    }

    private func hexWindow(_ d: Data, at index: Int, width: Int = 8) -> String {
        let lo = max(0, index - width)
        let hi = min(d.count, index + 1 + width)
        return d.subdata(in: lo..<hi).map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    var body: some View {
        List {
            Section("verifyRunID") { Text(runID).font(.system(.caption, design: .monospaced)) }
            if ios == nil && backend == nil {
                Section { Text("No iOS evidence or backend forensics for this run.").foregroundStyle(.secondary) }
            } else if ios == nil {
                Section { Text("No iOS CryptoEvidence for this run. Run Assert Key first.").foregroundStyle(.orange) }
            } else if backend == nil {
                Section { Text("No forensics in verify response. Enable backend debug.").foregroundStyle(.orange) }
            } else {
                let i = ios!, be = backend!
                Section("authenticatorData.sha256") {
                    let (m, a, b) = cmp("authenticatorData.sha256", i.authenticatorData_sha256, be.authenticatorData_sha256)
                    HStack {
                        Text(m ? "MATCH" : "MISMATCH").foregroundColor(m ? .green : .red)
                        Text("iOS: \(a)").font(.system(.caption, design: .monospaced))
                        Text("BE:  \(b)").font(.system(.caption, design: .monospaced))
                    }
                    if !m, let ah = be.authenticatorData_hex, let ad = CryptoEncoding.hexToData(ah) {
                        if let idx = firstDiffIndex(i.authenticatorData, ad) {
                            Text("First diff at byte \(idx). iOS: \(hexWindow(i.authenticatorData, at: idx)) BE: \(hexWindow(ad, at: idx))").font(.caption2)
                        }
                    }
                }
                Section("storedClientDataHash.sha256") {
                    let (m, a, b) = cmp("storedClientDataHash.sha256", i.clientDataHash_sha256, be.storedClientDataHash_sha256)
                    HStack { Text(m ? "MATCH" : "MISMATCH").foregroundColor(m ? .green : .red); Text("iOS: \(a)"); Text("BE: \(b)") }
                }
                Section("signature.sha256") {
                    let (m, a, b) = cmp("signature.sha256", i.signature_sha256, be.signature_sha256)
                    HStack { Text(m ? "MATCH" : "MISMATCH").foregroundColor(m ? .green : .red); Text("iOS: \(a)"); Text("BE: \(b)") }
                }
                Section("signedBytes.sha256") {
                    let beVal = be.signedBytesA_sha256 ?? be.digestA_hex
                    let (m, a, b) = cmp("signedBytes.sha256", i.signedBytes_sha256, beVal)
                    HStack { Text(m ? "MATCH" : "MISMATCH").foregroundColor(m ? .green : .red); Text("iOS: \(a)"); Text("BE:  \(b)") }
                }
            }
        }
        .navigationTitle("Diff View")
    }
}
