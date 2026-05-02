import AppKit
import SwiftUI

struct QuickCaptureReviewPluginView: View {
    @ObservedObject var store: QuickCaptureStore

    @State private var monthlySummary = false
    @State private var autoWeeklySummary = false
    @State private var autoMonthlySummary = false

    private var theme: ThemeResolver {
        ThemeResolver(theme: NotchCustomizationStore.shared.customization.theme)
    }

    var body: some View {
        VStack(spacing: 10) {
            summaryCard
            Spacer(minLength: 0)
        }
        .padding(12)
        .onAppear(perform: loadAutoSummarySettings)
    }

    private var summaryCard: some View {
        let summary = monthlySummary ? store.monthlySummary() : store.weeklySummary()
        let text = store.summaryText(isMonthly: monthlySummary)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("复盘总结")
                    .notchFont(11, weight: .semibold)
                    .foregroundColor(theme.primaryText)

                Spacer()

                Picker("周期", selection: $monthlySummary) {
                    Text("周").tag(false)
                    Text("月").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            Text(text)
                .notchFont(10)
                .foregroundColor(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                metricPill("记录", value: summary.total)
                metricPill("完成率", value: summary.completionRate, suffix: "%")
                metricPill("待办", value: summary.todo)

                Spacer()

                Button("复制总结") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
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

            HStack(spacing: 8) {
                Toggle("每周五 18:00 自动提醒", isOn: $autoWeeklySummary)
                    .toggleStyle(.checkbox)
                    .onChange(of: autoWeeklySummary) { _, _ in
                        saveAutoSummarySettings()
                    }

                Toggle("每月末 18:00 自动提醒", isOn: $autoMonthlySummary)
                    .toggleStyle(.checkbox)
                    .onChange(of: autoMonthlySummary) { _, _ in
                        saveAutoSummarySettings()
                    }
            }
            .notchFont(10)
            .foregroundColor(theme.secondaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.overlay.opacity(0.12))
        )
    }

    private func metricPill(_ title: String, value: Int, suffix: String = "") -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("\(value)\(suffix)")
                .notchFont(10, weight: .semibold)
        }
        .notchFont(10)
        .foregroundColor(theme.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.overlay.opacity(0.18))
        )
    }

    private func loadAutoSummarySettings() {
        let settings = store.autoSummarySettings()
        autoWeeklySummary = settings.weeklyEnabled
        autoMonthlySummary = settings.monthlyEnabled
    }

    private func saveAutoSummarySettings() {
        store.updateAutoSummarySettings(
            QuickCaptureAutoSummarySettings(
                weeklyEnabled: autoWeeklySummary,
                monthlyEnabled: autoMonthlySummary,
                weeklyWeekday: 6,
                weeklyHour: 18,
                weeklyMinute: 0,
                monthlyHour: 18,
                monthlyMinute: 0
            )
        )
    }
}
