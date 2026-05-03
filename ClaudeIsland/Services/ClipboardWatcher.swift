//
//  ClipboardWatcher.swift
//  ClaudeIsland
//
//  Monitors system clipboard changes via polling NSPasteboard.changeCount
//

import AppKit
import Foundation

final class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastProcessedText: String = ""
    private var lastProcessedAt: Date = .distantPast
    private let duplicateWindow: TimeInterval = 0.35

    private let store: ClipboardStore
    private let quickCaptureStore: QuickCaptureStore

    @MainActor
    init(store: ClipboardStore, quickCaptureStore: QuickCaptureStore) {
        self.store = store
        self.quickCaptureStore = quickCaptureStore
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    /// Start watching clipboard changes
    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        // Add to common RunLoop mode so it fires during UI tracking
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Stop watching
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Read plain text only (MVP: no images/rich text)
        guard let rawText = pasteboard.string(forType: .string) else { return }
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 短窗口去重，避免同一文本在系统层重复写入时触发无意义更新
        let now = Date()
        if trimmed == lastProcessedText, now.timeIntervalSince(lastProcessedAt) < duplicateWindow {
            return
        }
        lastProcessedText = trimmed
        lastProcessedAt = now

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let bundleIdentifier = frontmostApp?.bundleIdentifier?.lowercased() ?? ""
        let appName = frontmostApp?.localizedName ?? "未知应用"
        let isDingTalk = bundleIdentifier.contains("dingtalk")

        // 前置开关判定：开启“仅钉钉复制触发”时，非钉钉来源直接忽略，避免进入主线程更新路径
        let dingtalkOnlyEnabled = UserDefaults.standard.object(forKey: "quickcapture.clipboard.dingtalk.enabled") as? Bool ?? true
        if dingtalkOnlyEnabled, !isDingTalk {
            return
        }

        Task { @MainActor in
            store.addOrUpdate(trimmed)
            guard isDingTalk else { return }
            let staged = quickCaptureStore.stageClipboardTodoCandidate(trimmed, sourceApp: appName)
            guard staged else { return }
            NotificationCenter.default.post(
                name: NSNotification.Name("com.codeisland.openPlugin"),
                object: nil,
                userInfo: ["pluginId": "quick-capture"]
            )
        }
    }

    deinit {
        stop()
    }
}