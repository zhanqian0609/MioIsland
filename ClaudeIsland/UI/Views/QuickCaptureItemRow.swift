//
//  QuickCaptureItemRow.swift
//  ClaudeIsland
//
//  Quick Capture item row with lightweight rendering.
//

import SwiftUI

struct QuickCaptureItemRow: View {
    let item: QuickCaptureItem
    let theme: ThemeResolver
    let onCycleStatus: (UUID) -> Void
    let onOpenReminderEditor: (UUID) -> Void
    let onTogglePin: (UUID) -> Void
    let onDelete: (UUID) -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    private func timeString(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    var body: some View {
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
                    if let reminderAt = item.reminderAt {
                        Text("提醒 \(timeString(reminderAt))")
                            .foregroundColor(theme.doneColor)
                    }
                    Spacer()

                    Button {
                        onCycleStatus(item.id)
                    } label: {
                        Image(systemName: item.status.icon)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(item.status == .done ? theme.doneColor : theme.mutedText)

                    Button {
                        onOpenReminderEditor(item.id)
                    } label: {
                        Image(systemName: item.reminderAt == nil ? "bell" : "bell.badge")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(item.reminderAt == nil ? theme.mutedText : theme.doneColor)

                    Button {
                        onTogglePin(item.id)
                    } label: {
                        Image(systemName: item.pinned ? "pin.slash" : "pin")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.mutedText)

                    Button {
                        onDelete(item.id)
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
}
