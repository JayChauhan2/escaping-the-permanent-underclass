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
    
    private init() {
        loadData()
        if conversations.isEmpty {
            _ = createConversation(title: "New Conversation")
            saveData()
        }
    }
    
    @discardableResult
    public func createConversation(title: String = "New Conversation") -> ConversationItem {
        let item = ConversationItem(title: title)
        conversations.insert(item, at: 0)
        messagesByConversation[item.id] = []
        saveData()
        return item
    }
    
    public func deleteConversation(id: String) {
        conversations.removeAll(where: { $0.id == id })
        messagesByConversation.removeValue(forKey: id)
        if conversations.isEmpty {
            _ = createConversation(title: "New Conversation")
        }
        saveData()
    }
    
    public func getMessages(for conversationId: String) -> [ChatMessageItem] {
        return messagesByConversation[conversationId] ?? []
    }
    
    public func addMessage(_ message: ChatMessageItem) {
        if messagesByConversation[message.conversationId] == nil {
            messagesByConversation[message.conversationId] = []
        }
        messagesByConversation[message.conversationId]?.append(message)
        
        if let idx = conversations.firstIndex(where: { $0.id == message.conversationId }) {
            conversations[idx].updatedAt = Date()
        }
        
        saveData()
    }
    
    public func updateActionStatus(
        actionId: String,
        in messageId: String,
        conversationId: String,
        newStatus: CalendarActionStatus,
        eventId: String? = nil
    ) {
        guard let msgs = messagesByConversation[conversationId] else { return }
        for i in 0..<msgs.count {
            if msgs[i].id == messageId {
                var actions = msgs[i].proposedActions
                if let idx = actions.firstIndex(where: { $0.id == actionId }) {
                    actions[idx].status = newStatus
                    actions[idx].createdEventIdentifier = eventId
                    msgs[i].proposedActions = actions
                }
            }
        }
        saveData()
    }
    
    public func saveData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if let convosData = try? encoder.encode(conversations) {
            try? convosData.write(to: conversationsFileURL, options: .atomic)
        }
        
        var flatMessages: [ChatMessageItem] = []
        for list in messagesByConversation.values {
            flatMessages.append(contentsOf: list)
        }
        if let msgsData = try? encoder.encode(flatMessages) {
            try? msgsData.write(to: messagesFileURL, options: .atomic)
        }
        
        BackupService.shared.exportBackup(conversations: conversations, messages: flatMessages)
    }
    
    public func loadData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let convosData = try? Data(contentsOf: conversationsFileURL),
           let loadedConvos = try? decoder.decode([ConversationItem].self, from: convosData) {
            self.conversations = loadedConvos.sorted(by: { $0.updatedAt > $1.updatedAt })
        }
        
        if let msgsData = try? Data(contentsOf: messagesFileURL),
           let loadedMsgs = try? decoder.decode([ChatMessageItem].self, from: msgsData) {
            var map: [String: [ChatMessageItem]] = [:]
            for msg in loadedMsgs {
                if map[msg.conversationId] == nil {
                    map[msg.conversationId] = []
                }
                map[msg.conversationId]?.append(msg)
            }
            for (key, val) in map {
                map[key] = val.sorted(by: { $0.timestamp < $1.timestamp })
            }
            self.messagesByConversation = map
        }
    }
}
