//
//  QuickCaptureStore.swift
//  ClaudeIsland
//
//  Local JSON persistence for Quick Capture.
//

import Combine
import Foundation
import OSLog
import UserNotifications

struct QuickCapturePeriodSummary {
    let periodName: String
    let total: Int
    let done: Int
    let doing: Int
    let todo: Int
    let completionRate: Int
    let topTags: [String]
}

struct QuickCaptureAutoSummarySettings {
    var weeklyEnabled: Bool
    var monthlyEnabled: Bool
    var weeklyWeekday: Int
    var weeklyHour: Int
    var weeklyMinute: Int
    var monthlyHour: Int
    var monthlyMinute: Int
}

struct QuickCaptureClipboardDraft: Equatable {
    let text: String
    let sourceApp: String
    let createdAt: Date
}

struct QuickCaptureClipboardCaptureSettings {
    var dingtalkOnlyEnabled: Bool
    var confirmTimeoutSeconds: Int
    var smartDedupEnabled: Bool
    var smartParseTimeEnabled: Bool
}

@MainActor
final class QuickCaptureStore: ObservableObject {
    static let shared = QuickCaptureStore()

    private static let logger = Logger(subsystem: "com.codeisland", category: "QuickCaptureStore")

    @Published private(set) var items: [QuickCaptureItem] = []
    @Published private(set) var pendingClipboardDraft: QuickCaptureClipboardDraft?

    private let fileName = "quick-capture.json"
    private let directoryName = "ClaudeIsland"
    private let reminderPrefix = "quickcapture.reminder."
    private let weeklySummaryIdentifier = "quickcapture.summary.weekly"
    private let monthlySummaryIdentifier = "quickcapture.summary.monthly"

    private enum DefaultsKey {
        static let weeklyEnabled = "quickcapture.summary.weekly.enabled"
        static let monthlyEnabled = "quickcapture.summary.monthly.enabled"
        static let weeklyWeekday = "quickcapture.summary.weekly.weekday"
        static let weeklyHour = "quickcapture.summary.weekly.hour"
        static let weeklyMinute = "quickcapture.summary.weekly.minute"
        static let monthlyHour = "quickcapture.summary.monthly.hour"
        static let monthlyMinute = "quickcapture.summary.monthly.minute"
        static let dingtalkClipboardEnabled = "quickcapture.clipboard.dingtalk.enabled"
        static let clipboardConfirmTimeoutSeconds = "quickcapture.clipboard.confirm.timeout"
        static let clipboardSmartDedupEnabled = "quickcapture.clipboard.smartDedup.enabled"
        static let clipboardSmartParseTimeEnabled = "quickcapture.clipboard.smartParseTime.enabled"
    }

    private var pendingDraftAutoDismissWorkItem: DispatchWorkItem?

    init() {
        loadFromDisk()
    }

    func add(content: String, type: QuickCaptureType, tags: [String] = []) {
        _ = addAndReturnItem(content: content, type: type, tags: tags)
    }

    @discardableResult
    private func addAndReturnItem(content: String, type: QuickCaptureType, tags: [String] = []) -> QuickCaptureItem? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cleanedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let newItem = QuickCaptureItem(content: trimmed, type: type, tags: cleanedTags)
        items.insert(newItem, at: 0)
        items = sortedItems(items)
        saveToDisk()
        return newItem
    }

    @discardableResult
    func stageClipboardTodoCandidate(_ text: String, sourceApp: String) -> Bool {
        let settings = clipboardCaptureSettings()
        guard settings.dingtalkOnlyEnabled else { return false }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if pendingClipboardDraft?.text == trimmed {
            return false
        }

        if settings.smartDedupEnabled, isDuplicateClipboardTodo(trimmed) {
            return false
        }

        pendingClipboardDraft = QuickCaptureClipboardDraft(
            text: trimmed,
            sourceApp: sourceApp,
            createdAt: Date()
        )
        schedulePendingDraftAutoDismiss(timeoutSeconds: settings.confirmTimeoutSeconds)
        return true
    }

    func confirmPendingClipboardTodo() {
        guard let pending = pendingClipboardDraft else { return }
        let settings = clipboardCaptureSettings()

        let tags = ["dingtalk", "followup"]
        let added = addAndReturnItem(content: pending.text, type: .todo, tags: tags)

        if settings.smartParseTimeEnabled,
           let item = added,
           let parsed = parseReminderDate(from: pending.text) {
            setReminder(item.id, at: parsed)
        }

        cancelPendingDraftAutoDismiss()
        pendingClipboardDraft = nil
    }

    func dismissPendingClipboardTodo() {
        cancelPendingDraftAutoDismiss()
        pendingClipboardDraft = nil
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
        cancelReminder(for: id)
        saveToDisk()
    }

    func todayReview() -> (added: Int, done: Int, pending: Int) {
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) }
        let done = todayItems.filter { $0.status == .done }.count
        let pending = todayItems.filter { $0.status != .done }.count
        return (added: todayItems.count, done: done, pending: pending)
    }

    func weeklySummary() -> QuickCapturePeriodSummary {
        summary(days: 7, periodName: "本周")
    }

    func monthlySummary() -> QuickCapturePeriodSummary {
        summary(days: 30, periodName: "本月")
    }

    func summaryText(isMonthly: Bool) -> String {
        let data = isMonthly ? monthlySummary() : weeklySummary()
        let topTags = data.topTags.isEmpty ? "无" : data.topTags.map { "#\($0)" }.joined(separator: " ")
        return "\(data.periodName)记录 \(data.total) 条，完成 \(data.done) 条，进行中 \(data.doing) 条，待办 \(data.todo) 条，完成率 \(data.completionRate)% 。高频标签：\(topTags)"
    }

    func setReminder(_ id: UUID, at reminderAt: Date?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].reminderAt = reminderAt
        saveToDisk()

        if let reminderAt {
            scheduleReminder(for: items[idx], at: reminderAt)
        } else {
            cancelReminder(for: id)
        }
    }

    func autoSummarySettings() -> QuickCaptureAutoSummarySettings {
        let defaults = UserDefaults.standard
        return QuickCaptureAutoSummarySettings(
            weeklyEnabled: defaults.object(forKey: DefaultsKey.weeklyEnabled) as? Bool ?? false,
            monthlyEnabled: defaults.object(forKey: DefaultsKey.monthlyEnabled) as? Bool ?? false,
            weeklyWeekday: defaults.object(forKey: DefaultsKey.weeklyWeekday) as? Int ?? 6,
            weeklyHour: defaults.object(forKey: DefaultsKey.weeklyHour) as? Int ?? 18,
            weeklyMinute: defaults.object(forKey: DefaultsKey.weeklyMinute) as? Int ?? 0,
            monthlyHour: defaults.object(forKey: DefaultsKey.monthlyHour) as? Int ?? 18,
            monthlyMinute: defaults.object(forKey: DefaultsKey.monthlyMinute) as? Int ?? 0
        )
    }

    func clipboardCaptureSettings() -> QuickCaptureClipboardCaptureSettings {
        let defaults = UserDefaults.standard
        let timeout = defaults.object(forKey: DefaultsKey.clipboardConfirmTimeoutSeconds) as? Int ?? 10
        return QuickCaptureClipboardCaptureSettings(
            dingtalkOnlyEnabled: defaults.object(forKey: DefaultsKey.dingtalkClipboardEnabled) as? Bool ?? true,
            confirmTimeoutSeconds: max(3, min(timeout, 60)),
            smartDedupEnabled: defaults.object(forKey: DefaultsKey.clipboardSmartDedupEnabled) as? Bool ?? true,
            smartParseTimeEnabled: defaults.object(forKey: DefaultsKey.clipboardSmartParseTimeEnabled) as? Bool ?? true
        )
    }

    func updateClipboardCaptureSettings(_ settings: QuickCaptureClipboardCaptureSettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.dingtalkOnlyEnabled, forKey: DefaultsKey.dingtalkClipboardEnabled)
        defaults.set(max(3, min(settings.confirmTimeoutSeconds, 60)), forKey: DefaultsKey.clipboardConfirmTimeoutSeconds)
        defaults.set(settings.smartDedupEnabled, forKey: DefaultsKey.clipboardSmartDedupEnabled)
        defaults.set(settings.smartParseTimeEnabled, forKey: DefaultsKey.clipboardSmartParseTimeEnabled)

        if !settings.dingtalkOnlyEnabled {
            dismissPendingClipboardTodo()
        } else if pendingClipboardDraft != nil {
            schedulePendingDraftAutoDismiss(timeoutSeconds: settings.confirmTimeoutSeconds)
        }
    }

    func updateAutoSummarySettings(_ settings: QuickCaptureAutoSummarySettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.weeklyEnabled, forKey: DefaultsKey.weeklyEnabled)
        defaults.set(settings.monthlyEnabled, forKey: DefaultsKey.monthlyEnabled)
        defaults.set(settings.weeklyWeekday, forKey: DefaultsKey.weeklyWeekday)
        defaults.set(settings.weeklyHour, forKey: DefaultsKey.weeklyHour)
        defaults.set(settings.weeklyMinute, forKey: DefaultsKey.weeklyMinute)
        defaults.set(settings.monthlyHour, forKey: DefaultsKey.monthlyHour)
        defaults.set(settings.monthlyMinute, forKey: DefaultsKey.monthlyMinute)
        scheduleAutoSummaryReminders()
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
        rescheduleAllFutureReminders()
        scheduleAutoSummaryReminders()
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

    private func summary(days: Int, periodName: String) -> QuickCapturePeriodSummary {
        let start = Calendar.current.date(byAdding: .day, value: -days + 1, to: Date()) ?? Date.distantPast
        let periodItems = items.filter { $0.createdAt >= start }

        let done = periodItems.filter { $0.status == .done }.count
        let doing = periodItems.filter { $0.status == .doing }.count
        let todo = periodItems.filter { $0.status == .todo }.count
        let total = periodItems.count
        let completionRate = total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded())

        let tagCounter = periodItems
            .flatMap(\.tags)
            .reduce(into: [String: Int]()) { partial, tag in
                partial[tag, default: 0] += 1
            }

        let topTags = tagCounter
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(3)
            .map(\.key)

        return QuickCapturePeriodSummary(
            periodName: periodName,
            total: total,
            done: done,
            doing: doing,
            todo: todo,
            completionRate: completionRate,
            topTags: Array(topTags)
        )
    }

    private func reminderIdentifier(for id: UUID) -> String {
        reminderPrefix + id.uuidString
    }

    private func scheduleReminder(for item: QuickCaptureItem, at reminderAt: Date) {
        guard reminderAt > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "一键记录提醒"
        content.body = item.preview
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, reminderAt.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: reminderIdentifier(for: item.id), content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier(for: item.id)])
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error("scheduleReminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func cancelReminder(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier(for: id)])
    }

    private func rescheduleAllFutureReminders() {
        for item in items {
            guard let reminderAt = item.reminderAt, reminderAt > Date() else { continue }
            scheduleReminder(for: item, at: reminderAt)
        }
    }

    private func scheduleAutoSummaryReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklySummaryIdentifier, monthlySummaryIdentifier])

        let settings = autoSummarySettings()
        if settings.weeklyEnabled {
            scheduleWeeklySummaryReminder(settings: settings)
        }
        if settings.monthlyEnabled {
            scheduleMonthlySummaryReminder(settings: settings)
        }
    }

    private func scheduleWeeklySummaryReminder(settings: QuickCaptureAutoSummarySettings) {
        var components = DateComponents()
        components.weekday = settings.weeklyWeekday
        components.hour = settings.weeklyHour
        components.minute = settings.weeklyMinute

        let content = UNMutableNotificationContent()
        content.title = "每周复盘提醒"
        content.body = summaryText(isMonthly: false)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklySummaryIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error("scheduleWeeklySummaryReminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func scheduleMonthlySummaryReminder(settings: QuickCaptureAutoSummarySettings) {
        let nextDate = nextMonthEndDate(hour: settings.monthlyHour, minute: settings.monthlyMinute)
        guard nextDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "每月复盘提醒"
        content.body = summaryText(isMonthly: true)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, nextDate.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: monthlySummaryIdentifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.error("scheduleMonthlySummaryReminder failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func nextMonthEndDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()

        guard let monthRange = calendar.range(of: .day, in: .month, for: now),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return now.addingTimeInterval(86400)
        }

        let lastDay = monthRange.count
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = lastDay
        components.hour = hour
        components.minute = minute
        components.second = 0

        let currentMonthEnd = calendar.date(from: components) ?? now.addingTimeInterval(86400)
        if currentMonthEnd > now {
            return currentMonthEnd
        }

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
              let nextRange = calendar.range(of: .day, in: .month, for: nextMonth) else {
            return now.addingTimeInterval(86400)
        }

        var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
        nextComponents.day = nextRange.count
        nextComponents.hour = hour
        nextComponents.minute = minute
        nextComponents.second = 0
        return calendar.date(from: nextComponents) ?? now.addingTimeInterval(86400)
    }

    private func isDuplicateClipboardTodo(_ text: String) -> Bool {
        let normalizedIncoming = normalizedClipboardText(text)
        guard !normalizedIncoming.isEmpty else { return true }

        if normalizedClipboardText(pendingClipboardDraft?.text ?? "") == normalizedIncoming {
            return true
        }

        let now = Date()
        let recentWindow: TimeInterval = 6 * 3600
        return items.contains { item in
            guard item.type == .todo else { return false }
            guard now.timeIntervalSince(item.createdAt) <= recentWindow else { return false }
            return normalizedClipboardText(item.content) == normalizedIncoming
        }
    }

    private func normalizedClipboardText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[，。！？；：,.!?;:（）()【】\\[\\]{}\"'`~·•-]", with: "", options: .regularExpression)
    }

    private func parseReminderDate(from text: String) -> Date? {
        let lowered = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        let hour: Int
        let minute: Int
        if let match = lowered.range(of: #"(\d{1,2})[:：点](\d{1,2})"#, options: .regularExpression) {
            let token = String(lowered[match])
            let parts = token.split(whereSeparator: { $0 == ":" || $0 == "：" || $0 == "点" })
            hour = max(0, min(23, Int(parts.first ?? "9") ?? 9))
            minute = max(0, min(59, Int(parts.last ?? "0") ?? 0))
        } else {
            hour = lowered.contains("下午") || lowered.contains("今晚") ? 18 : 9
            minute = 0
        }

        var targetDay = now
        if lowered.contains("明天") || lowered.contains("明早") || lowered.contains("明晚") {
            targetDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        } else if lowered.contains("后天") {
            targetDay = calendar.date(byAdding: .day, value: 2, to: now) ?? now
        }

        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let candidate = calendar.date(from: components) else { return nil }

        if lowered.contains("今天") || lowered.contains("今晚") || lowered.contains("明天") || lowered.contains("明早") || lowered.contains("明晚") || lowered.contains("后天") {
            return candidate > now ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)
        }

        return nil
    }

    private func schedulePendingDraftAutoDismiss(timeoutSeconds: Int) {
        cancelPendingDraftAutoDismiss()
        let clamped = max(3, min(timeoutSeconds, 60))
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.pendingClipboardDraft = nil
                self.pendingDraftAutoDismissWorkItem = nil
            }
        }
        pendingDraftAutoDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(clamped), execute: workItem)
    }

    private func cancelPendingDraftAutoDismiss() {
        pendingDraftAutoDismissWorkItem?.cancel()
        pendingDraftAutoDismissWorkItem = nil
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
