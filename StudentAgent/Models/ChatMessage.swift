//
//  ChatMessage.swift
//  StudentAgent
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case tool = "tool"
}

public final class ChatMessageItem: Identifiable, Codable, ObservableObject {
    public let id: String
    public var roleRaw: String
    @Published public var content: String
    public var timestamp: Date
    public var conversationId: String
    
    // Image attachment filename
    @Published public var imageAttachmentFilename: String?
    
    // Action and email payloads
    @Published public var rawToolCallsJSON: String?
    @Published public var rawProposedActionsJSON: String?
    @Published public var rawEmailDigestsJSON: String?
    @Published public var rawChecklistItemsJSON: String?
    
    // UI Streaming state
    @Published public var isStreaming: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, roleRaw, content, timestamp, conversationId, imageAttachmentFilename, rawToolCallsJSON, rawProposedActionsJSON, rawEmailDigestsJSON, rawChecklistItemsJSON
    }
    
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
        imageAttachmentFilename: String? = nil,
        toolCallsJSON: String? = nil,
        proposedActionsJSON: String? = nil,
        emailDigestsJSON: String? = nil,
        checklistItemsJSON: String? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.conversationId = conversationId
        self.imageAttachmentFilename = imageAttachmentFilename
        self.rawToolCallsJSON = toolCallsJSON
        self.rawProposedActionsJSON = proposedActionsJSON
        self.rawEmailDigestsJSON = emailDigestsJSON
        self.rawChecklistItemsJSON = checklistItemsJSON
        self.isStreaming = isStreaming
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.roleRaw = try container.decode(String.self, forKey: .roleRaw)
        self.content = try container.decode(String.self, forKey: .content)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.conversationId = try container.decode(String.self, forKey: .conversationId)
        self.imageAttachmentFilename = try container.decodeIfPresent(String.self, forKey: .imageAttachmentFilename)
        self.rawToolCallsJSON = try container.decodeIfPresent(String.self, forKey: .rawToolCallsJSON)
        self.rawProposedActionsJSON = try container.decodeIfPresent(String.self, forKey: .rawProposedActionsJSON)
        self.rawEmailDigestsJSON = try container.decodeIfPresent(String.self, forKey: .rawEmailDigestsJSON)
        self.rawChecklistItemsJSON = try container.decodeIfPresent(String.self, forKey: .rawChecklistItemsJSON)
        self.isStreaming = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roleRaw, forKey: .roleRaw)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(imageAttachmentFilename, forKey: .imageAttachmentFilename)
        try container.encodeIfPresent(rawToolCallsJSON, forKey: .rawToolCallsJSON)
        try container.encodeIfPresent(rawProposedActionsJSON, forKey: .rawProposedActionsJSON)
        try container.encodeIfPresent(rawEmailDigestsJSON, forKey: .rawEmailDigestsJSON)
        try container.encodeIfPresent(rawChecklistItemsJSON, forKey: .rawChecklistItemsJSON)
    }
    
    #if canImport(UIKit)
    public var attachmentImage: UIImage? {
        guard let filename = imageAttachmentFilename else { return nil }
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileURL = paths[0].appendingPathComponent("StudentAgent_Attachments", isDirectory: true).appendingPathComponent(filename)
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    public static func saveAttachmentImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("StudentAgent_Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            print("[ChatMessageItem] Failed to save attachment image: \(error)")
            return nil
        }
    }
    #endif
    
    // Decode/encode proposed calendar actions
    public var proposedActions: [CalendarAction] {
        get {
            guard let json = rawProposedActionsJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([CalendarAction].self, from: data)) ?? []
        }
        set {
            objectWillChange.send()
            if let data = try? JSONEncoder().encode(newValue), let str = String(data: data, encoding: .utf8) {
                rawProposedActionsJSON = str
            } else {
                rawProposedActionsJSON = nil
            }
        }
    }
    
    // Decode/encode email items
    public var emailDigests: [EmailItem] {
        get {
            guard let json = rawEmailDigestsJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([EmailItem].self, from: data)) ?? []
        }
        set {
            objectWillChange.send()
            if let data = try? JSONEncoder().encode(newValue), let str = String(data: data, encoding: .utf8) {
                rawEmailDigestsJSON = str
            } else {
                rawEmailDigestsJSON = nil
            }
        }
    }
    
    // Decode/encode checklist items
    public var checklistItems: [ChecklistItem] {
        get {
            guard let json = rawChecklistItemsJSON, let data = json.data(using: .utf8) else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([ChecklistItem].self, from: data)) ?? []
        }
        set {
            objectWillChange.send()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(newValue), let str = String(data: data, encoding: .utf8) {
                rawChecklistItemsJSON = str
            } else {
                rawChecklistItemsJSON = nil
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
