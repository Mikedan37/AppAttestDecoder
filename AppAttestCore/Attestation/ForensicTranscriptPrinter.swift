//
//  ForensicTranscriptPrinter.swift
//  AppAttestDecoderCLI
//
//  Linear narrative transcript printer for forensic reports
//  Outputs all data in order: raw → decoded → next section
//

import Foundation

/// Linear transcript printer for forensic reports
/// Presents data as a continuous narrative: raw bytes only shown if showRaw=true, at the end
struct ForensicTranscriptPrinter {
    let colorized: Bool
    let showRaw: Bool
    private let dateFormatter: ISO8601DateFormatter
    private var rawDataBlocks: [(title: String, data: Data, encoding: String?)] = []
    
    init(colorized: Bool = false, showRaw: Bool = false) {
        self.colorized = colorized
        self.showRaw = showRaw
        self.dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    mutating func addRawDataBlock(title: String, data: Data, encoding: String? = nil) {
        rawDataBlocks.append((title: title, data: data, encoding: encoding))
    }
    
    func renderRawDataSection() -> String {
        guard showRaw && !rawDataBlocks.isEmpty else { return "" }
        
        var output = sectionHeader("RAW BYTES")
        output += "All raw data preserved for audit:\n\n"
        
        for block in rawDataBlocks {
            output += rawDataBlock(title: block.title, data: block.data, encoding: block.encoding, collapsed: false)
            output += "\n"
        }
        
        return output
    }
    
    // MARK: - Section Headers
    
    // MARK: - Box Drawing
    
    func boxedSection(_ title: String, content: String) -> String {
        let width = 80  // Increased width for better readability
        let titleWithDashes = "─ \(title) "
        let dashesNeeded = max(0, width - titleWithDashes.count - 1)
        let topBorder = "┌" + titleWithDashes + String(repeating: "─", count: dashesNeeded) + "┐"
        let bottomBorder = "└" + String(repeating: "─", count: width) + "┘"
        
        let header = colorized ? "\(ANSIColor.header)\(topBorder)\(ANSIColor.reset)" : topBorder
        let footer = colorized ? "\(ANSIColor.header)\(bottomBorder)\(ANSIColor.reset)" : bottomBorder
        
        // Wrap content lines in box
        let contentLines = content.components(separatedBy: "\n")
        var boxedContent = ""
        for line in contentLines {
            // Don't filter empty lines - they might be intentional spacing
            // But trim trailing whitespace for consistency
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Preserve ANSI codes when calculating length
            let displayLength = trimmedLine.replacingOccurrences(of: #"\u{001B}\[[0-9;]*m"#, with: "", options: .regularExpression).count
            let paddingNeeded = max(0, width - 2 - displayLength)
            let paddedLine = "│ " + trimmedLine + String(repeating: " ", count: paddingNeeded) + " │"
            boxedContent += paddedLine + "\n"
        }
        
        return "\n\(header)\n\(boxedContent)\(footer)\n"
    }
    
    func sectionHeader(_ title: String) -> String {
        if colorized {
            return "\n\(ANSIColor.header)\(title)\(ANSIColor.reset)\n\n"
        } else {
            return "\n\(title)\n\n"
        }
    }
    
    func subsectionHeader(_ title: String) -> String {
        if colorized {
            return "\n\(ANSIColor.header)\(title)\(ANSIColor.reset)\n"
        } else {
            return "\n\(title)\n"
        }
    }
    
    func sectionTitle(_ title: String, symbol: String = "▶") -> String {
        if colorized {
            return "\n\(ANSIColor.header)\(symbol) \(title)\(ANSIColor.reset)\n"
        } else {
            return "\n\(symbol) \(title)\n"
        }
    }
    
    func summaryHeader(_ title: String) -> String {
        if colorized {
            return "\n\(ANSIColor.header)\(title)\(ANSIColor.reset)\n\n"
        } else {
            return "\n\(title)\n\n"
        }
    }
    
    // MARK: - Raw Data Blocks (collapsed/indented)
    
    func rawDataBlock(title: String, data: Data, encoding: String? = nil, collapsed: Bool = true) -> String {
        var output = ""
        
        if collapsed {
            // Collapsed view - just summary
            if colorized {
                output += "\(ANSIColor.rawLabel)  [Raw Bytes: \(data.count) bytes]\(ANSIColor.reset)\n"
            } else {
                output += "  [Raw Bytes: \(data.count) bytes]\n"
            }
        } else {
            // Full view
            if colorized {
                output += "\(ANSIColor.rawLabel)  [\(title)]\(ANSIColor.reset)\n"
            } else {
                output += "  [\(title)]\n"
            }
            
            if let encoding = encoding {
                output += "  Encoding: \(encoding)\n"
            }
            output += "  Length: \(data.count) bytes\n\n"
            
            output += "  Hex:\n"
            output += formatHex(data, lineLength: 80, indent: 2) + "\n\n"
            
            output += "  Base64:\n"
            output += "  \(formatBase64(data))\n"
        }
        
        return output
    }
    
    // MARK: - Two-Column Format
    
    func twoColumnField(key: String, value: String, keyWidth: Int = 20) -> String {
        let keyUpper = key.uppercased()
        let paddedKey = keyUpper.padding(toLength: keyWidth, withPad: " ", startingAt: 0)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)\(paddedKey)\(ANSIColor.reset)" : paddedKey
        
        // Box width is 80, minus key width, minus "│ " and " │" = 80 - keyWidth - 4
        let maxValueLength = 80 - keyWidth - 4
        
        // If value fits on one line, return it
        if value.count <= maxValueLength {
            return "\(nameFormatted) \(value)\n"
        }
        
        // Otherwise, wrap across multiple lines
        var output = ""
        let valueLines = wrapText(value, maxLength: maxValueLength)
        
        // First line with key
        output += "\(nameFormatted) \(valueLines[0])\n"
        
        // Subsequent lines with indentation
        let indentStr = String(repeating: " ", count: keyWidth + 1)
        for line in valueLines.dropFirst() {
            output += "\(indentStr)\(line)\n"
        }
        
        return output
    }
    
    private func wrapText(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }
        
        var lines: [String] = []
        var remaining = text
        
        while remaining.count > maxLength {
            // Try to break at a word boundary
            let breakIndex = remaining.prefix(maxLength).lastIndex(of: " ") ?? remaining.index(remaining.startIndex, offsetBy: maxLength)
            let line = String(remaining[..<breakIndex])
            lines.append(line)
            remaining = String(remaining[remaining.index(after: breakIndex)...])
        }
        
        if !remaining.isEmpty {
            lines.append(remaining)
        }
        
        return lines
    }
    
    // MARK: - Decoded Fields
    
    func field(name: String, value: String, indent: Int = 0, symbol: String? = nil) -> String {
        let indentStr = String(repeating: " ", count: indent)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)\(name)\(ANSIColor.reset)" : name
        let symbolStr = symbol != nil ? "\(symbol!) " : ""
        return "\(indentStr)\(symbolStr)\(nameFormatted): \(value)\n"
    }
    
    func fieldWithContext(name: String, value: String, context: String, indent: Int = 0) -> String {
        let indentStr = String(repeating: " ", count: indent)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)\(name)\(ANSIColor.reset)" : name
        return "\(indentStr)\(nameFormatted) (\(context)): \(value)\n"
    }
    
    func fieldWithRaw(name: String, decoded: String, raw: Data, encoding: String? = nil, indent: Int = 0, showRaw: Bool = false) -> String {
        var output = ""
        let indentStr = String(repeating: " ", count: indent)
        let nameFormatted = colorized ? "\(ANSIColor.fieldName)\(name)\(ANSIColor.reset)" : name
        
        output += "\(indentStr)\(nameFormatted): \(decoded)\n"
        
        if showRaw {
            if let encoding = encoding {
                output += "\(indentStr)  Encoding: \(encoding)\n"
            }
            output += "\(indentStr)  Raw hex: \(formatHex(raw, lineLength: 0))\n"
        } else {
            output += "\(indentStr)  [\(raw.count) bytes, hex available in raw section]\n"
        }
        
        return output
    }
    
    func bulletPoint(_ text: String, indent: Int = 0, symbol: String = "•") -> String {
        let indentStr = String(repeating: " ", count: indent)
        return "\(indentStr)\(symbol) \(text)\n"
    }
    
    // MARK: - Formatting
    
    private func formatHex(_ data: Data, lineLength: Int = 80, indent: Int = 0) -> String {
        let hexString = data.map { String(format: "%02x", $0) }.joined()
        let indentStr = String(repeating: " ", count: indent)
        
        if lineLength == 0 {
            // Single line, no wrapping
            return hexString
        }
        
        // Wrap at lineLength characters (2 chars per byte), group bytes
        var formatted = ""
        var currentLine = indentStr
        for (index, byte) in data.enumerated() {
            if index > 0 && index % 16 == 0 {
                formatted += currentLine + "\n"
                currentLine = indentStr
            }
            currentLine += String(format: "%02x ", byte)
        }
        if !currentLine.isEmpty && currentLine != indentStr {
            formatted += currentLine.trimmingCharacters(in: .whitespaces) + "\n"
        }
        return formatted
    }
    
    private func formatBase64(_ data: Data) -> String {
        return data.base64EncodedString()
    }
    
    // MARK: - ANSI Colors (4-color professional palette)
    
    enum ANSIColor {
        static let header = "\u{001B}[1;37m"      // Bold white (headers)
        static let fieldName = "\u{001B}[36m"     // Cyan (keys)
        static let rawLabel = "\u{001B}[2;90m"    // Dim gray (raw/opaque)
        static let reset = "\u{001B}[0m"          // Reset
    }
    
    // MARK: - Status Symbols
    
    enum StatusSymbol {
        static let decoded = "✔"
        static let opaque = "◻"
        static let warning = "⚠"
        static let cryptographic = "🔒"
    }
}
