//
//  QuickCaptureStore.swift
//  ClaudeIsland
//
//  Local JSON persistence for Quick Capture.
//

import Combine
import Foundation
import OSLog

@MainActor
final class QuickCaptureStore: ObservableObject {
    static let shared = QuickCaptureStore()

    private static let logger = Logger(subsystem: "com.codeisland", category: "QuickCaptureStore")

    @Published private(set) var items: [QuickCaptureItem] = []

    private let fileName = "quick-capture.json"
    private let directoryName = "ClaudeIsland"

    init() {
        loadFromDisk()
    }

    func add(content: String, type: QuickCaptureType, tags: [String] = []) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let cleanedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let newItem = QuickCaptureItem(content: trimmed, type: type, tags: cleanedTags)
        items.insert(newItem, at: 0)
        items = sortedItems(items)
        saveToDisk()
    }

    func search(query: String) -> [QuickCaptureItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sortedItems(items) }

        let filtered = items.filter { item in
            item.content.localizedCaseInsensitiveContains(q)
                || item.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
                || item.type.title.localizedCaseInsensitiveContains(q)
        }
        return sortedItems(filtered)
    }

    func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        items = sortedItems(items)
        saveToDisk()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        saveToDisk()
    }

    func loadFromDisk() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let url = dataFileURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode([QuickCaptureItem].self, from: data) else {
            items = []
            return
        }

        items = sortedItems(decoded)
    }

    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            guard let url = dataFileURL(createDirectoryIfNeeded: true) else { return }
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            Self.logger.error("saveToDisk failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func sortedItems(_ source: [QuickCaptureItem]) -> [QuickCaptureItem] {
        source.sorted {
            if $0.pinned != $1.pinned {
                return $0.pinned && !$1.pinned
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func dataFileURL(createDirectoryIfNeeded: Bool = false) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = base.appendingPathComponent(directoryName, isDirectory: true)

        if createDirectoryIfNeeded {
            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Self.logger.error("createDirectory failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        return directoryURL.appendingPathComponent(fileName)
    }
}
