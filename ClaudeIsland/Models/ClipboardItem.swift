//
//  ClipboardItem.swift
//  ClaudeIsland
//
//  Model for a single clipboard history entry
//

import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: String
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Preview text truncated to a reasonable display length
    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 80 {
            return String(trimmed.prefix(80)) + "…"
        }
        return trimmed
    }

    /// Time formatted as HH:mm
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: updatedAt)
    }
}