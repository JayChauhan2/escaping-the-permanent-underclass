//
//  DebugLogger.swift
//  StudentAgent
//

import Foundation
import SwiftUI

public enum DebugEventType: String, Codable {
    case userPrompt = "USER_PROMPT"
    case systemPrompt = "SYSTEM_PROMPT"
    case apiRequest = "DEEPSEEK_REQUEST"
    case toolCall = "TOOL_EXECUTION"
    case apiResponse = "DEEPSEEK_RESPONSE"
    case eventKit = "EVENTKIT_ACTION"
    case error = "ERROR"
    case general = "LOG"
}

public struct DebugLogEntry: Identifiable, Codable {
    public let id: String
    public let timestamp: Date
    public let type: DebugEventType
    public let title: String
    public let payload: String
    
    public init(id: String = UUID().uuidString, timestamp: Date = Date(), type: DebugEventType, title: String, payload: String) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.payload = payload
    }
}

@MainActor
public final class DebugLogger: ObservableObject {
    public static let shared = DebugLogger()
    
    @Published public var logs: [DebugLogEntry] = []
    
    private var logFileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("StudentAgent_Data", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("debug_telemetry.json")
    }
    
    private init() {
        loadLogs()
    }
    
    public func log(type: DebugEventType, title: String, payload: String) {
        let entry = DebugLogEntry(type: type, title: title, payload: payload)
        logs.insert(entry, at: 0)
        
        // Print to Xcode Debug Console with clear delimiters
        let formatter = ISO8601DateFormatter()
        let timeStr = formatter.string(from: entry.timestamp)
        print("\n================ [STUDENTAGENT DEBUG: \(entry.type.rawValue)] ================")
        print("⏰ Time: \(timeStr)")
        print("📌 Title: \(entry.title)")
        print("📦 Payload:\n\(entry.payload)")
        print("=========================================================================\n")
        
        saveLogs()
    }
    
    private func saveLogs() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(logs) {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }
    
    private func loadLogs() {
        if let data = try? Data(contentsOf: logFileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let loaded = try? decoder.decode([DebugLogEntry].self, from: data) {
                self.logs = loaded
            }
        }
    }
    
    public func clearLogs() {
        logs.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    public func exportFormattedText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        return logs.map { entry in
            """
            [\(formatter.string(from: entry.timestamp))] [\(entry.type.rawValue)]
            Title: \(entry.title)
            Payload:
            \(entry.payload)
            --------------------------------------------------
            """
        }.joined(separator: "\n\n")
    }
}
