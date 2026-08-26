//
//  ChatMessage.swift
//  StudentAgent
//

import Foundation

public enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case tool = "tool"
}

public final class ChatMessageItem: Identifiable, Codable, ObservableObject {
    public let id: String
    public var roleRaw: String
    public var content: String
    public var timestamp: Date
    public var conversationId: String
    
    // Action and email payloads
    public var rawToolCallsJSON: String?
    public var rawProposedActionsJSON: String?
    public var rawEmailDigestsJSON: String?
    
    public var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .assistant }
        set { roleRaw = newValue.rawValue }
    }
    
    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        conversationId: String,
        toolCallsJSON: String? = nil,
        proposedActionsJSON: String? = nil,
        emailDigestsJSON: String? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.conversationId = conversationId
        self.rawToolCallsJSON = toolCallsJSON
        self.rawProposedActionsJSON = proposedActionsJSON
        self.rawEmailDigestsJSON = emailDigestsJSON
    }
    
    // Decode proposed calendar actions
    public var proposedActions: [CalendarAction] {
        get {
            guard let json = rawProposedActionsJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([CalendarAction].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue), let str = String(data: data, encoding: .utf8) {
                rawProposedActionsJSON = str
            } else {
                rawProposedActionsJSON = nil
            }
        }
    }
    
    // Decode email items
    public var emailDigests: [EmailItem] {
        get {
            guard let json = rawEmailDigestsJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([EmailItem].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue), let str = String(data: data, encoding: .utf8) {
                rawEmailDigestsJSON = str
            } else {
                rawEmailDigestsJSON = nil
            }
        }
    }
}

public final class ConversationItem: Identifiable, Codable, ObservableObject, Hashable {
    public let id: String
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String = "New Conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }
    
    public static func == (lhs: ConversationItem, rhs: ConversationItem) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
