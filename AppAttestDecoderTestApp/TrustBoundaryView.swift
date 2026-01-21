//
//  TrustBoundaryView.swift
//  AppAttestDecoderTestApp
//
//  Explicit trust boundary indicator for inspection results.
//  Shows what is decoded from wire, reconstructed per spec, and verified cryptographically.
//

import SwiftUI
import AppAttestCore

struct TrustBoundaryView: View {
    let hasDecodedData: Bool
    let hasReconstructedData: Bool
    let hasVerifiedData: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trust Boundary")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                TrustBoundaryItem(
                    label: "Decoded from wire",
                    status: hasDecodedData ? .decoded : .missing,
                    description: "Data extracted directly from artifact bytes"
                )
                
                TrustBoundaryItem(
                    label: "Reconstructed per spec",
                    status: hasReconstructedData ? .reconstructed : .missing,
                    description: "Derived view per App Attest specification"
                )
                
                TrustBoundaryItem(
                    label: "Backend verification status",
                    status: hasVerifiedData ? .verified : .notVerified,
                    description: "Backend cryptographic verification result (frontend does not verify)"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TrustBoundaryItem: View {
    let label: String
    let status: TrustStatus
    let description: String
    
    enum TrustStatus {
        case decoded
        case reconstructed
        case verified
        case missing
        case notVerified
        
        var icon: String {
            switch self {
            case .decoded, .verified:
                return "checkmark.circle.fill"
            case .reconstructed:
                return "exclamationmark.triangle.fill"
            case .missing, .notVerified:
                return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .decoded, .verified:
                return .green
            case .reconstructed:
                return .orange
            case .missing, .notVerified:
                return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
