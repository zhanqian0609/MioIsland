//
//  QuickCaptureItem.swift
//  ClaudeIsland
//
//  Persistent model for quick capture notes.
//

import Foundation

enum QuickCaptureType: String, Codable, CaseIterable, Identifiable {
    case idea
    case todo
    case meeting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idea: return "灵感"
        case .todo: return "待办"
        case .meeting: return "会议"
        }
    }

    var icon: String {
        switch self {
        case .idea: return "lightbulb"
        case .todo: return "checklist"
        case .meeting: return "person.2"
        }
    }
}

enum QuickCaptureStatus: String, Codable, CaseIterable, Identifiable {
    case todo
    case doing
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo: return "待办"
        case .doing: return "进行中"
        case .done: return "已完成"
        }
    }

    var icon: String {
        switch self {
        case .todo: return "circle"
        case .doing: return "hourglass"
        case .done: return "checkmark.circle.fill"
        }
    }

    var next: QuickCaptureStatus {
        switch self {
        case .todo: return .doing
        case .doing: return .done
        case .done: return .todo
        }
    }
}

struct QuickCaptureItem: Codable, Identifiable, Equatable {
    let id: UUID
    var content: String
    var type: QuickCaptureType
    var status: QuickCaptureStatus
    var tags: [String]
    var createdAt: Date
    var pinned: Bool
    var reminderAt: Date?

    init(
        id: UUID = UUID(),
        content: String,
        type: QuickCaptureType,
        status: QuickCaptureStatus = .todo,
        tags: [String] = [],
        createdAt: Date = Date(),
        pinned: Bool = false,
        reminderAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.status = status
        self.tags = tags
        self.createdAt = createdAt
        self.pinned = pinned
        self.reminderAt = reminderAt
    }

    enum CodingKeys: String, CodingKey {
        case id, content, type, status, tags, createdAt, pinned, reminderAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(QuickCaptureType.self, forKey: .type)
        status = try container.decodeIfPresent(QuickCaptureStatus.self, forKey: .status) ?? .todo
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        reminderAt = try container.decodeIfPresent(Date.self, forKey: .reminderAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(type, forKey: .type)
        try container.encode(status, forKey: .status)
        try container.encode(tags, forKey: .tags)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(pinned, forKey: .pinned)
        try container.encodeIfPresent(reminderAt, forKey: .reminderAt)
    }

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "…"
        }
        return trimmed
    }
}
