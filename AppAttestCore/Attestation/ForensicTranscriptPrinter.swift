//
//  ForensicTranscriptPrinter.swift
//  AppAttestDecoderCLI
//
//  Linear narrative transcript printer for forensic reports
//  Outputs all data in order: raw → decoded → next section
//

import Foundation

/// Linear transcript printer for forensic reports
/// Presents data as a continuous narrative: raw bytes always precede interpretation
struct ForensicTranscriptPrinter {
    let colorized: Bool
    private let dateFormatter: ISO8601DateFormatter
    
    init(colorized: Bool = false) {
        self.colorized = colorized
        self.dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    // MARK: - Section Headers
    
    func sectionHeader(_ title: String) -> String {
        let separator = String(repeating: "=", count: title.count)
        if colorized {
            return "\n\(ANSIColor.header)\(title)\(ANSIColor.reset)\n\(ANSIColor.separator)\(separator)\(ANSIColor.reset)\n\n"
        } else {
            return "\n\(title)\n\(separator)\n\n"
        }
    }
    
    func subsectionHeader(_ title: String) -> String {
        let separator = String(repeating: "-", count: title.count)
        if colorized {
            return "\n\(ANSIColor.subheader)\(title)\(ANSIColor.reset)\n\(separator)\n\n"
        } else {
            return "\n\(title)\n\(separator)\n\n"
        }
    }
    
    // MARK: - Raw Data Blocks
    
    func rawDataBlock(title: String, data: Data, encoding: String? = nil) -> String {
        var output = ""
        
        if colorized {
            output += "\(ANSIColor.rawLabel)[\(title)]\(ANSIColor.reset)\n"
        } else {
            output += "[\(title)]\n"
        }
        
        if let encoding = encoding {
            output += "Encoding: \(encoding)\n"
        }
        output += "Length: \(data.count) bytes\n\n"
        
        output += "Hex:\n"
        output += formatHex(data, lineLength: 80) + "\n\n"
        
        output += "Base64:\n"
        output += formatBase64(data) + "\n\n"
        
        if colorized {
            output += "\(ANSIColor.separator)(End \(title))\(ANSIColor.reset)\n"
        } else {
            output += "(End \(title))\n"
        }
        
        return output
    }
    
    // MARK: - Decoded Fields
    
    func field(name: String, value: String, indent: Int = 0) -> String {
        let indentStr = String(repeating: " ", count: indent)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)\(name)\(ANSIColor.reset)" : name
        return "\(indentStr)\(nameFormatted): \(value)\n"
    }
    
    func fieldWithRaw(name: String, decoded: String, raw: Data, encoding: String? = nil, indent: Int = 0) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)\(name)\(ANSIColor.reset)" : name
        
        output += "\(indentStr)\(nameFormatted):\n"
        output += "\(indentStr)  \(decoded)\n"
        if let encoding = encoding {
            output += "\(indentStr)  Encoding: \(encoding)\n"
        }
        output += "\(indentStr)  Raw hex: \(formatHex(raw, lineLength: 0))\n"
        
        return output
    }
    
    // MARK: - Formatting
    
    private func formatHex(_ data: Data, lineLength: Int = 80) -> String {
        let hexString = data.map { String(format: "%02x", $0) }.joined()
        
        if lineLength == 0 {
            // Single line, no wrapping
            return hexString
        }
        
        // Wrap at lineLength characters (2 chars per byte)
        var formatted = ""
        var currentLine = ""
        for (index, char) in hexString.enumerated() {
            currentLine.append(char)
            if (index + 1) % (lineLength / 2) == 0 {
                formatted += currentLine + "\n"
                currentLine = ""
            }
        }
        if !currentLine.isEmpty {
            formatted += currentLine
        }
        return formatted
    }
    
    private func formatBase64(_ data: Data) -> String {
        return data.base64EncodedString()
    }
    
    // MARK: - ANSI Colors
    
    enum ANSIColor {
        static let header = "\u{001B}[1;36m"      // Bold cyan
        static let subheader = "\u{001B}[1;33m"    // Bold yellow
        static let fieldName = "\u{001B}[36m"      // Cyan
        static let rawLabel = "\u{001B}[1;35m"     // Bold magenta
        static let separator = "\u{001B}[90m"      // Dark gray
        static let reset = "\u{001B}[0m"
    }
}
