//
//  ChatStorage.swift
//  StudentAgent
//

import Foundation
import SwiftUI

@MainActor
public final class ChatStorage: ObservableObject {
    public static let shared = ChatStorage()
    
    @Published public var conversations: [ConversationItem] = []
    @Published public var messagesByConversation: [String: [ChatMessageItem]] = [:]
    
    private var dataDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("StudentAgent_Data", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var conversationsFileURL: URL {
        dataDirectory.appendingPathComponent("conversations.json")
    }
    
    private var messagesFileURL: URL {
        dataDirectory.appendingPathComponent("messages.json")
    }
    
    public init() {
        loadData()
    }
    
    public func loadData() {
        // 1. Load conversations
        if let data = try? Data(contentsOf: conversationsFileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let loaded = try? decoder.decode([ConversationItem].self, from: data) {
                self.conversations = loaded
            }
        }
        
        // 2. Load messages
        if let data = try? Data(contentsOf: messagesFileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let loaded = try? decoder.decode([ChatMessageItem].self, from: data) {
                var dict: [String: [ChatMessageItem]] = [:]
                for msg in loaded {
                    dict[msg.conversationId, default: []].append(msg)
                }
                self.messagesByConversation = dict
            }
        }
        
        // If empty, create initial conversation
        if conversations.isEmpty {
            let initial = ConversationItem(title: "Student Inbox & Schedule")
            conversations.append(initial)
            saveData()
        }
    }
    
    public func saveData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        // 1. Save conversations
        if let convData = try? encoder.encode(conversations) {
            try? convData.write(to: conversationsFileURL, options: .atomic)
        }
        
        // 2. Save all messages flat
        let allMessages = messagesByConversation.values.flatMap { $0 }
        if let msgData = try? encoder.encode(allMessages) {
            try? msgData.write(to: messagesFileURL, options: .atomic)
        }
        
        // Also trigger backup
        BackupService.shared.exportBackup(conversations: conversations, messages: allMessages)
    }
    
    public func getMessages(for conversationId: String) -> [ChatMessageItem] {
        return messagesByConversation[conversationId] ?? []
    }
    
    public func addMessage(_ message: ChatMessageItem) {
        messagesByConversation[message.conversationId, default: []].append(message)
        
        // Update conversation timestamp
        if let idx = conversations.firstIndex(where: { $0.id == message.conversationId }) {
            conversations[idx].updatedAt = Date()
        }
        
        saveData()
    }
    
    public func createConversation(title: String = "New Conversation") -> ConversationItem {
        let newConv = ConversationItem(title: title)
        conversations.insert(newConv, at: 0)
        saveData()
        return newConv
    }
    
    public func deleteConversation(_ conversation: ConversationItem) {
        conversations.removeAll { $0.id == conversation.id }
        messagesByConversation.removeValue(forKey: conversation.id)
        saveData()
    }
    
    public func updateActionStatus(actionId: String, in messageId: String, conversationId: String, newStatus: CalendarActionStatus, eventId: String? = nil) {
        guard let list = messagesByConversation[conversationId],
              let msgIdx = list.firstIndex(where: { $0.id == messageId }) else { return }
        
        var actions = list[msgIdx].proposedActions
        guard let actIdx = actions.firstIndex(where: { $0.id == actionId }) else { return }
        
        actions[actIdx].status = newStatus
        if let eventId = eventId {
            actions[actIdx].createdEventIdentifier = eventId
        }
        list[msgIdx].proposedActions = actions
        messagesByConversation[conversationId] = list
        saveData()
    }
}
