//
//  ClipboardStore.swift
//  ClaudeIsland
//
//  In-memory storage for clipboard history (MVP)
//

import AppKit
import Foundation
import Combine

@MainActor
final class ClipboardStore: ObservableObject {
    /// All clipboard items, newest first
    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems: Int

    init(maxItems: Int = 50) {
        self.maxItems = maxItems
    }

    /// Add a new item or update existing if content matches
    /// - Parameter text: Raw clipboard text (will be trimmed)
    func addOrUpdate(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ignore empty content
        guard !trimmed.isEmpty else { return }

        // Check for duplicate — update timestamp and move to front
        if let existingIndex = items.firstIndex(where: { $0.content == trimmed }) {
            var existing = items[existingIndex]
            existing.updatedAt = Date()
            items.remove(at: existingIndex)
            items.insert(existing, at: 0)
        } else {
            // Insert new item at front
            let newItem = ClipboardItem(content: trimmed)
            items.insert(newItem, at: 0)

            // Enforce limit
            trimToLimit(maxItems)
        }
    }

    /// Remove all items older than the limit
    func trimToLimit(_ limit: Int = 50) {
        guard items.count > limit else { return }
        items = Array(items.prefix(limit))
    }

    /// Write item content back to system clipboard (triggers watcher re-read,
    /// but dedup logic prevents infinite growth)
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
    }
}