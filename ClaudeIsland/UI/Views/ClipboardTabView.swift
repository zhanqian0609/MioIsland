//
//  ClipboardTabView.swift
//  ClaudeIsland
//
//  Shows clipboard history list inside the opened notch panel
//

import SwiftUI

struct ClipboardTabView: View {
    @ObservedObject var store: ClipboardStore
    let viewModel: NotchViewModel?
    @State private var copiedId: UUID? = nil

    private var theme: ThemeResolver {
        ThemeResolver(theme: NotchCustomizationStore.shared.customization.theme)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if store.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.items) { item in
                            ClipboardItemRow(
                                item: item,
                                isCopied: copiedId == item.id,
                                onCopy: {
                                    copyItem(item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24))
                .foregroundColor(theme.mutedText.opacity(0.5))

            Text("暂无剪贴历史")
                .notchFont(12)
                .foregroundColor(theme.mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 40)
    }

    private func copyItem(_ item: ClipboardItem) {
        store.copyToClipboard(item)
        withAnimation(.easeOut(duration: 0.15)) {
            copiedId = item.id
        }
        // Clear "copied" indicator after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedId == item.id {
                copiedId = nil
            }
        }
    }
}

// MARK: - ClipboardItemRow

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var isHovered = false
    private var theme: ThemeResolver {
        ThemeResolver(theme: NotchCustomizationStore.shared.customization.theme)
    }

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 8) {
                // Copy indicator
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(isCopied ? theme.doneColor : (isHovered ? theme.primaryText : theme.mutedText))
                    .frame(width: 14)

                // Content preview
                Text(item.preview)
                    .notchFont(12, weight: .regular)
                    .foregroundColor(isCopied ? theme.doneColor : theme.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Timestamp
                Text(item.timeString)
                    .notchFont(10, weight: .regular, design: .monospaced)
                    .foregroundColor(theme.mutedText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? theme.overlay.opacity(0.18) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}