//
//  QuickCapturePluginView.swift
//  ClaudeIsland
//
//  Quick Capture: input + hashtag tags + search + pin/delete.
//

import AppKit
import Combine
import SwiftUI

struct QuickCapturePluginView: View {
    @ObservedObject var store: QuickCaptureStore

    @State private var input: String = ""
    @State private var searchQuery: String = ""
    @State private var selectedType: QuickCaptureType = .todo
    @State private var justSaved = false
    @State private var placeholderIndex = 0
    @State private var hideDoneItems = false
    @State private var reminderEditorItemID: UUID?
    @State private var customReminderDate = Date().addingTimeInterval(3600)
    @State private var customReminderDay = Date().addingTimeInterval(3600)
    @State private var customReminderTime = Date().addingTimeInterval(3600)
    @State private var customReminderMinDate = Date().addingTimeInterval(5)
    @State private var cachedVisibleItems: [QuickCaptureItem] = []

    private static let placeholderTimer = Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    private let placeholderSamples: [String] = [
        "输入后按 Enter 保存（支持 #标签）",
        "例如：复盘 Claude PR #工作 #MioIsland",
        "例如：下周方案评审 #会议 #产品",
        "例如：补充登录埋点 #todo #前端"
    ]

    private var theme: ThemeResolver {
        ThemeResolver(theme: NotchCustomizationStore.shared.customization.theme)
    }

    private var visibleItems: [QuickCaptureItem] {
        let searched = store.search(query: searchQuery)
        guard hideDoneItems else { return searched }
        return searched.filter { $0.status != .done }
    }

    private func updateCachedVisibleItems() {
        let searched = store.search(query: searchQuery)
        cachedVisibleItems = hideDoneItems ? searched.filter { $0.status != .done } : searched
    }

    var body: some View {
        VStack(spacing: 10) {
            if let draft = store.pendingClipboardDraft {
                dingtalkConfirmCard(draft)
            }
            inputCard
            searchBar
            filterChipsBar
            todayReviewCard
            reminderEditorCard
            listArea
        }
        .padding(12)
    }

    private var header: some View {
        HStack {
            Text("一键记录")
                .notchFont(13, weight: .semibold)
                .foregroundColor(theme.primaryText)

            Spacer()

            Text("\(store.items.count)")
                .notchFont(11, weight: .medium)
                .foregroundColor(theme.mutedText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.overlay.opacity(0.2))
                )
        }
    }

    private var inputCard: some View {
        VStack(spacing: 8) {
            Picker("类型", selection: $selectedType) {
                ForEach(QuickCaptureType.allCases) { type in
                    Label(type.title, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)

            TextField(
                "",
                text: $input,
                prompt: Text(placeholderSamples[placeholderIndex])
                    .foregroundColor(theme.mutedText.opacity(0.9))
            )
                .textFieldStyle(.plain)
                .notchFont(12)
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.overlay.opacity(0.15))
                )
                .onSubmit(saveCurrentInput)
                .onReceive(Self.placeholderTimer) { _ in
                    // 避免在“自定义提醒”编辑中触发全局重绘，导致 DatePicker 弹层被系统收起
                    guard reminderEditorItemID == nil else { return }
                    guard input.isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        placeholderIndex = (placeholderIndex + 1) % placeholderSamples.count
                    }
                }

            HStack {
                if justSaved {
                    Text("已记录")
                        .notchFont(11)
                        .foregroundColor(theme.doneColor)
                } else {
                    Text("示例：复盘 Claude PR #工作 #MioIsland")
                        .notchFont(10)
                        .foregroundColor(theme.mutedText)
                }

                Spacer()

                Button("保存") { saveCurrentInput() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }


    private func dingtalkConfirmCard(_ draft: QuickCaptureClipboardDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "message.badge")
                    .foregroundColor(theme.doneColor)
                Text("检测到来自 \(draft.sourceApp) 的复制内容")
                    .notchFont(11, weight: .medium)
                    .foregroundColor(theme.primaryText)
                Spacer()
            }

            Text(draft.text)
                .notchFont(11)
                .foregroundColor(theme.secondaryText)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text("加入待办？")
                    .notchFont(10)
                    .foregroundColor(theme.mutedText)
                Spacer()
                Button("取消") {
                    store.dismissPendingClipboardTodo()
                }
                .buttonStyle(.plain)

                Button("确认") {
                    store.confirmPendingClipboardTodo()
                    justSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        justSaved = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.overlay.opacity(0.18))
        )
    }

    private var searchBar: some View {
        TextField("搜索：关键词 #标签 @todo/@doing/@done today/yesterday", text: $searchQuery)
            .textFieldStyle(.plain)
            .notchFont(12)
            .foregroundColor(theme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.overlay.opacity(0.12))
            )
    }

    private var filterChipsBar: some View {
        HStack(spacing: 8) {
            filterChip("@todo", token: "@todo")
            filterChip("@doing", token: "@doing")
            filterChip("@done", token: "@done")
            filterChip("today", token: "today")
            filterChip("yesterday", token: "yesterday")

            Spacer()

            Button(hideDoneItems ? "显示已完成" : "隐藏已完成") {
                hideDoneItems.toggle()
            }
            .buttonStyle(.plain)
            .notchFont(10)
            .foregroundColor(hideDoneItems ? theme.primaryText : theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(hideDoneItems ? theme.overlay.opacity(0.3) : theme.overlay.opacity(0.12))
            )

            if hasActiveFilters {
                Button("清空筛选") {
                    clearAllFilters()
                }
                .buttonStyle(.plain)
                .notchFont(10)
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(theme.overlay.opacity(0.3))
                )
            }
        }
    }

    private func filterChip(_ title: String, token: String) -> some View {
        let active = isTokenActive(token)

        return Button(title) {
            applyToken(token)
        }
        .buttonStyle(.plain)
        .notchFont(10)
        .foregroundColor(active ? theme.primaryText : theme.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(active ? theme.overlay.opacity(0.3) : theme.overlay.opacity(0.12))
        )
    }

    private var todayReviewCard: some View {
        let review = store.todayReview()

        return HStack(spacing: 8) {
            reviewChip("今日新增", value: review.added, icon: "calendar", token: "today")
            reviewChip("已完成", value: review.done, icon: "checkmark.circle", token: "@done today")
            reviewChip("未完成", value: review.pending, icon: "clock", token: "today")
        }
    }

    private var editingReminderItem: QuickCaptureItem? {
        guard let id = reminderEditorItemID else { return nil }
        return store.items.first { $0.id == id }
    }

    @ViewBuilder
    private var reminderEditorCard: some View {
        if let item = editingReminderItem {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("提醒设置：\(item.preview)")
                        .notchFont(11, weight: .medium)
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Button("关闭") { cancelCustomReminder() }
                        .buttonStyle(.plain)
                        .notchFont(10)
                        .foregroundColor(theme.mutedText)
                }

                HStack(spacing: 6) {
                    Button("1小时后") { store.setReminder(item.id, at: Date().addingTimeInterval(3600)); cancelCustomReminder() }
                    Button("今晚21:00") { store.setReminder(item.id, at: nextTime(hour: 21, minute: 0)); cancelCustomReminder() }
                    Button("明早09:00") { store.setReminder(item.id, at: nextTime(hour: 9, minute: 0, forceTomorrow: true)); cancelCustomReminder() }
                    Button("清除") { store.setReminder(item.id, at: nil); cancelCustomReminder() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                DatePicker(
                    "日期",
                    selection: $customReminderDay,
                    in: customReminderMinDate...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                HStack(spacing: 8) {
                    Text("时间")
                        .notchFont(10)
                        .foregroundColor(theme.mutedText)
                    DatePicker(
                        "时间",
                        selection: $customReminderTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.field)
                    .labelsHidden()
                    Spacer()
                    Button("保存") { applyCustomReminder(for: item.id) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.overlay.opacity(0.12))
            )
        }
    }

    private func reviewChip(_ title: String, value: Int, icon: String, token: String) -> some View {
        Button {
            if title == "未完成" {
                searchQuery = "today"
                hideDoneItems = true
            } else {
                searchQuery = token
                hideDoneItems = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                Text("\(value)")
                    .notchFont(10, weight: .semibold)
            }
            .notchFont(10)
            .foregroundColor(theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(theme.overlay.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private var listArea: some View {
        Group {
            if cachedVisibleItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 22))
                        .foregroundColor(theme.mutedText.opacity(0.5))
                    Text("暂无记录")
                        .notchFont(12)
                        .foregroundColor(theme.mutedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(cachedVisibleItems) { item in
                            QuickCaptureItemRow(
                                item: item,
                                theme: theme,
                                onCycleStatus: { id in store.cycleStatus(id) },
                                onOpenReminderEditor: { id in openCustomReminder(for: id) },
                                onTogglePin: { id in store.togglePin(id) },
                                onDelete: { id in store.delete(id) }
                            )
                            .id(item.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: searchQuery) { _ in updateCachedVisibleItems() }
        .onChange(of: hideDoneItems) { _ in updateCachedVisibleItems() }
        .onChange(of: store.items.count) { _ in
            DispatchQueue.main.async { updateCachedVisibleItems() }
        }
        .onAppear { updateCachedVisibleItems() }
    }

    private func timeString(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func isTokenActive(_ token: String) -> Bool {
        searchQuery
            .split(separator: " ")
            .map(String.init)
            .contains(token)
    }

    private var hasActiveFilters: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hideDoneItems
    }

    private func clearAllFilters() {
        searchQuery = ""
        hideDoneItems = false
    }

    private func applyToken(_ token: String) {
        let existing = searchQuery
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        if existing.contains(token) {
            searchQuery = existing.filter { $0 != token }.joined(separator: " ")
        } else {
            searchQuery = (existing + [token]).joined(separator: " ")
        }
    }

    private func nextTime(hour: Int, minute: Int, forceTomorrow: Bool = false) -> Date {
        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        let candidate = Calendar.current.date(from: components) ?? now.addingTimeInterval(3600)
        if forceTomorrow || candidate <= now {
            return Calendar.current.date(byAdding: .day, value: 1, to: candidate) ?? now.addingTimeInterval(3600)
        }
        return candidate
    }

    private func saveCurrentInput() {
        let parsed = parseInput(input)
        guard !parsed.content.isEmpty else { return }

        store.add(content: parsed.content, type: selectedType, tags: parsed.tags)
        input = ""
        justSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            justSaved = false
        }
    }

    private func parseInput(_ raw: String) -> (content: String, tags: [String]) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", []) }

        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        var tags: [String] = []
        var contentWords: [String] = []

        for part in parts {
            if part.hasPrefix("#") {
                let tag = part.dropFirst().trimmingCharacters(in: .punctuationCharacters)
                if !tag.isEmpty {
                    tags.append(String(tag))
                }
            } else {
                contentWords.append(String(part))
            }
        }

        let content = contentWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return (content, Array(Set(tags)).sorted())
    }

    private func openCustomReminder(for id: UUID) {
        if reminderEditorItemID == id {
            cancelCustomReminder()
            return
        }

        guard let item = store.items.first(where: { $0.id == id }) else {
            reminderEditorItemID = nil
            return
        }

        reminderEditorItemID = id
        customReminderMinDate = Date().addingTimeInterval(5)
        customReminderDate = item.reminderAt ?? Date().addingTimeInterval(3600)
        if customReminderDate <= customReminderMinDate {
            customReminderDate = customReminderMinDate
        }
        customReminderDay = customReminderDate
        customReminderTime = customReminderDate
    }

    private func cancelCustomReminder() {
        reminderEditorItemID = nil
    }

    private func applyCustomReminder(for id: UUID) {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: customReminderDay)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: customReminderTime)

        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = 0

        let selected = calendar.date(from: merged) ?? customReminderDate
        let reminder = max(selected, Date().addingTimeInterval(5))
        customReminderDate = reminder
        store.setReminder(id, at: reminder)
        cancelCustomReminder()
    }

}
