//
//  BackupService.swift
//  StudentAgent
//

import Foundation

public struct BackupMessageDTO: Codable {
    public let id: String
    public let role: String
    public let content: String
    public let timestamp: Date
    public let conversationId: String
    public let toolCallsJSON: String?
    public let proposedActionsJSON: String?
    public let emailDigestsJSON: String?
}

public struct BackupConversationDTO: Codable {
    public let id: String
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
}

public struct FullAppBackupDTO: Codable {
    public let version: Int
    public let exportedAt: Date
    public let conversations: [BackupConversationDTO]
    public let messages: [BackupMessageDTO]
}

public final class BackupService {
    public static let shared = BackupService()
    
    private init() {}
    
    private var backupDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("StudentAgent_Backups", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var autoBackupFileURL: URL {
        backupDirectory.appendingPathComponent("latest_chat_history.json")
    }
    
    // Auto-save full backup to Documents directory
    public func exportBackup(conversations: [ConversationItem], messages: [ChatMessageItem]) {
        do {
            let backup = FullAppBackupDTO(
                version: 1,
                exportedAt: Date(),
                conversations: conversations.map { BackupConversationDTO(id: $0.id, title: $0.title, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
                messages: messages.map {
                    BackupMessageDTO(
                        id: $0.id,
                        role: $0.roleRaw,
                        content: $0.content,
                        timestamp: $0.timestamp,
                        conversationId: $0.conversationId,
                        toolCallsJSON: $0.rawToolCallsJSON,
                        proposedActionsJSON: $0.rawProposedActionsJSON,
                        emailDigestsJSON: $0.rawEmailDigestsJSON
                    )
                }
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backup)
            
            try data.write(to: autoBackupFileURL, options: .atomic)
            print("[BackupService] Successfully auto-backed up \(messages.count) messages to \(autoBackupFileURL.path)")
        } catch {
            print("[BackupService] Backup error: \(error)")
        }
    }
    
    public func getBackupFileURL() -> URL? {
        if FileManager.default.fileExists(atPath: autoBackupFileURL.path) {
            return autoBackupFileURL
        }
        return nil
    }
}
