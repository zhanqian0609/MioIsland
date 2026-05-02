//
//  QuickCapturePluginView.swift
//  ClaudeIsland
//
//  Quick Capture: input + hashtag tags + search + pin/delete.
//

import Combine
import SwiftUI

struct QuickCapturePluginView: View {
    @ObservedObject var store: QuickCaptureStore

    @State private var input: String = ""
    @State private var searchQuery: String = ""
    @State private var selectedType: QuickCaptureType = .idea
    @State private var justSaved = false
    @State private var placeholderIndex = 0
    @State private var hideDoneItems = false

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

    var body: some View {
        VStack(spacing: 10) {
            inputCard
            searchBar
            filterChipsBar
            todayReviewCard
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
                .onReceive(Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()) { _ in
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
            if visibleItems.isEmpty {
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
                        ForEach(visibleItems) { item in
                            itemRow(item)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemRow(_ item: QuickCaptureItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.type.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if item.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(theme.doneColor)
                    }

                    Text(item.preview)
                        .notchFont(12)
                        .foregroundColor(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .notchFont(10)
                                .foregroundColor(theme.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(theme.overlay.opacity(0.2))
                                )
                        }
                    }
                }

                HStack(spacing: 6) {
                    Text(item.type.title)
                    Text(item.status.title)
                        .foregroundColor(item.status == .done ? theme.doneColor : theme.mutedText)
                    Text(timeString(item.createdAt))
                    Spacer()

                    Button {
                        store.cycleStatus(item.id)
                    } label: {
                        Label(item.status.title, systemImage: item.status.icon)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(item.status == .done ? theme.doneColor : theme.mutedText)

                    Button {
                        store.togglePin(item.id)
                    } label: {
                        Image(systemName: item.pinned ? "pin.slash" : "pin")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.mutedText)

                    Button {
                        store.delete(item.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.mutedText)
                }
                .notchFont(10, weight: .regular, design: .monospaced)
                .foregroundColor(theme.mutedText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.overlay.opacity(0.1))
        )
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
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
}
