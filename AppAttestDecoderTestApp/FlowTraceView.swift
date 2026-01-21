//
//  FlowTraceView.swift
//  AppAttestDecoderTestApp
//
//  Diagnostic flow trace view. Displays complete flow from registration through assertion submission.
//  Observational only - no local verification performed.
//

import SwiftUI

struct FlowTraceEntry: Identifiable {
    let id = UUID()
    let step: String
    let timestamp: Date
    let flowID: String?
    let status: String
    let details: String?
}

struct FlowTraceView: View {
    @Binding var entries: [FlowTraceEntry]
    @State private var isRunning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diagnostic Flow Trace")
                    .font(.headline)
                Spacer()
                Text("No local verification performed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if entries.isEmpty {
                Text("No flow trace recorded. Complete registration → challenge → assertion flow to populate trace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { entry in
                            FlowTraceEntryView(entry: entry)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FlowTraceEntryView: View {
    let entry: FlowTraceEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.step)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if let flowID = entry.flowID {
                Text("flowID: \(flowID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("Status: \(entry.status)")
                .font(.caption)
                .foregroundStyle(statusColor(entry.status))
            
            if let details = entry.details {
                Text(details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .cornerRadius(4)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed", "sent":
            return .blue
        case "pending":
            return .orange
        case "error":
            return .red
        default:
            return .primary
        }
    }
}
