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
    private let store: ClipboardStore

    init(store: ClipboardStore) {
        self.store = store
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
        guard let text = pasteboard.string(forType: .string) else { return }

        Task { @MainActor in
            store.addOrUpdate(text)
        }
    }

    deinit {
        stop()
    }
}