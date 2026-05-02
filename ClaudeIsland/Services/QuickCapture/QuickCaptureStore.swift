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

        let tokens = q.split(separator: " ").map(String.init)
        let statusFilters = tokens.compactMap { token in
            QuickCaptureStatus(rawValue: token.lowercased().replacingOccurrences(of: "@", with: ""))
        }

        let dayFilter: Date? = {
            if tokens.contains(where: { $0.caseInsensitiveCompare("today") == .orderedSame }) { return Date() }
            if tokens.contains(where: { $0.caseInsensitiveCompare("yesterday") == .orderedSame }) {
                return Calendar.current.date(byAdding: .day, value: -1, to: Date())
            }
            return nil
        }()

        let keywordTokens = tokens.filter {
            !$0.hasPrefix("@")
                && $0.caseInsensitiveCompare("today") != .orderedSame
                && $0.caseInsensitiveCompare("yesterday") != .orderedSame
        }

        let filtered = items.filter { item in
            let statusMatched = statusFilters.isEmpty || statusFilters.contains(item.status)
            let dayMatched: Bool = {
                guard let dayFilter else { return true }
                return Calendar.current.isDate(item.createdAt, inSameDayAs: dayFilter)
            }()

            let keywordMatched: Bool = {
                guard !keywordTokens.isEmpty else { return true }
                return keywordTokens.allSatisfy { token in
                    item.content.localizedCaseInsensitiveContains(token)
                        || item.tags.contains(where: { $0.localizedCaseInsensitiveContains(token) })
                        || item.type.title.localizedCaseInsensitiveContains(token)
                        || item.status.title.localizedCaseInsensitiveContains(token)
                }
            }()

            return statusMatched && dayMatched && keywordMatched
        }

        return sortedItems(filtered)
    }

    func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        items = sortedItems(items)
        saveToDisk()
    }

    func cycleStatus(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].status = items[idx].status.next
        saveToDisk()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        saveToDisk()
    }

    func todayReview() -> (added: Int, done: Int, pending: Int) {
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) }
        let done = todayItems.filter { $0.status == .done }.count
        let pending = todayItems.filter { $0.status != .done }.count
        return (added: todayItems.count, done: done, pending: pending)
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
