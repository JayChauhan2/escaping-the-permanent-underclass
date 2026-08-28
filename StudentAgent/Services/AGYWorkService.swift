//
//  AGYWorkService.swift
//  StudentAgent
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class AGYWorkService: ObservableObject {
    public static let shared = AGYWorkService()
    
    @Published public var isConnected: Bool = false
    @Published public var isRunning: Bool = false
    @Published public var serverWorkspace: String = ""
    @Published public var activeConversationId: String? = nil
    
    // Sessions & Messages Persistence
    @Published public var sessions: [AGYSessionItem] = []
    @Published public var activeSessionId: String? = nil
    @Published public var messages: [AGYMessage] = []
    @Published public var currentStreamingText: String = ""
    @Published public var connectionError: String? = nil
    
    private var activeTask: Task<Void, Never>? = nil
    
    public static let defaultBridgeURL: String = "https://deviant-richmond-strange-real.trycloudflare.com"
    
    private var dataDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("StudentAgent_Data", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var sessionsFileURL: URL {
        dataDirectory.appendingPathComponent("agy_sessions.json")
    }
    
    public var bridgeBaseURL: String {
        var raw = UserDefaults.standard.string(forKey: "agy_bridge_url")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty || raw.contains("100.") || raw.contains("172.16") || raw.contains("10.203") || raw.contains("localhost") || raw.contains("127.0.0.1") {
            raw = AGYWorkService.defaultBridgeURL
            UserDefaults.standard.set(AGYWorkService.defaultBridgeURL, forKey: "agy_bridge_url")
        }
        return raw
    }
    
    public func setBridgeURL(_ urlString: String) {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cleaned, forKey: "agy_bridge_url")
        Task {
            await checkHealth()
        }
    }
    
    private init() {
        loadSessions()
        Task {
            await checkHealth()
        }
    }
    
    // MARK: - Session Management
    
    public func loadSessions() {
        guard FileManager.default.fileExists(atPath: sessionsFileURL.path) else {
            createInitialSession()
            return
        }
        do {
            let data = try Data(contentsOf: sessionsFileURL)
            let decoded = try JSONDecoder().decode([AGYSessionItem].self, from: data)
            self.sessions = decoded
            if let first = decoded.first {
                self.activeSessionId = first.id
                self.messages = first.messages
                self.activeConversationId = first.conversationId
            } else {
                createInitialSession()
            }
        } catch {
            print("Failed to load AGY sessions: \(error)")
            if sessions.isEmpty {
                createInitialSession()
            }
        }
    }
    
    public func saveSessions() {
        if let activeId = activeSessionId, let idx = sessions.firstIndex(where: { $0.id == activeId }) {
            sessions[idx].messages = messages
            sessions[idx].updatedAt = Date()
            sessions[idx].conversationId = activeConversationId
        }
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: sessionsFileURL, options: .atomic)
        } catch {
            print("Failed to save AGY sessions: \(error)")
        }
    }
    
    private func createInitialSession() {
        let session = AGYSessionItem(title: "New AGY Task")
        sessions = [session]
        activeSessionId = session.id
        messages = []
        activeConversationId = nil
        saveSessions()
    }
    
    @discardableResult
    public func createNewSession(title: String = "New AGY Task") -> AGYSessionItem {
        saveSessions()
        let session = AGYSessionItem(title: title)
        sessions.insert(session, at: 0)
        activeSessionId = session.id
        messages = []
        activeConversationId = nil
        saveSessions()
        return session
    }
    
    public func selectSession(id: String) {
        saveSessions()
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        self.activeSessionId = session.id
        self.messages = session.messages
        self.activeConversationId = session.conversationId
    }
    
    public func deleteSession(id: String) {
        sessions.removeAll(where: { $0.id == id })
        if sessions.isEmpty {
            createInitialSession()
        } else if activeSessionId == id {
            if let first = sessions.first {
                selectSession(id: first.id)
            }
        }
        saveSessions()
    }
    
    // MARK: - Health Check
    
    public func checkHealth() async {
        guard let url = URL(string: "\(bridgeBaseURL)/status") else {
            isConnected = false
            return
        }
        
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 3.0
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.isConnected = true
                    self.serverWorkspace = json["workspace"] as? String ?? ""
                    self.connectionError = nil
                    return
                }
            }
            self.isConnected = false
        } catch {
            self.isConnected = false
            self.connectionError = error.localizedDescription
        }
    }
    
    // MARK: - Execution & Live Streaming
    
    public func sendPrompt(_ text: String, customCwd: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Auto-title session if it's the first message
        if messages.isEmpty, let activeId = activeSessionId, let idx = sessions.firstIndex(where: { $0.id == activeId }) {
            let summary = trimmed.prefix(32)
            sessions[idx].title = String(summary) + (trimmed.count > 32 ? "..." : "")
        }
        
        let message = AGYMessage(
            prompt: trimmed,
            conversationId: activeConversationId,
            isRunning: true
        )
        messages.append(message)
        let messageIndex = messages.count - 1
        saveSessions()
        
        isRunning = true
        currentStreamingText = ""
        
        activeTask?.cancel()
        activeTask = Task {
            await runStreamPipeline(prompt: trimmed, messageIndex: messageIndex, customCwd: customCwd)
        }
    }
    
    public func abortTask() {
        activeTask?.cancel()
        isRunning = false
        if let idx = messages.indices.last, messages[idx].isRunning {
            messages[idx].isRunning = false
            messages[idx].finalResponse += "\n\n[⚠️ Task Aborted by User]"
        }
        saveSessions()
        
        Task {
            guard let url = URL(string: "\(bridgeBaseURL)/abort") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            _ = try? await URLSession.shared.data(for: req)
        }
    }
    
    public func clearHistory() {
        messages.removeAll()
        activeConversationId = nil
        currentStreamingText = ""
        saveSessions()
    }
    
    private func runStreamPipeline(prompt: String, messageIndex: Int, customCwd: String?) async {
        guard let url = URL(string: "\(bridgeBaseURL)/stream") else {
            failMessage(at: messageIndex, error: "Invalid bridge URL")
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 600
        
        var payload: [String: Any] = [
            "prompt": prompt
        ]
        if let convId = activeConversationId {
            payload["conversation_id"] = convId
        }
        if let cwd = customCwd {
            payload["cwd"] = cwd
        }
        
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                failMessage(at: messageIndex, error: "Server returned error: \((response as? HTTPURLResponse)?.statusCode ?? 500)")
                return
            }
            
            self.isConnected = true
            
            for try await line in bytes.lines {
                if Task.isCancelled { break }
                
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("data:") else { continue }
                
                let jsonStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                guard let data = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }
                
                processStreamEvent(json, messageIndex: messageIndex)
            }
            
            finishMessage(at: messageIndex)
            
        } catch {
            if !Task.isCancelled {
                failMessage(at: messageIndex, error: error.localizedDescription)
            }
        }
    }
    
    private func processStreamEvent(_ json: [String: Any], messageIndex: Int) {
        guard messageIndex < messages.count else { return }
        let eventType = json["event"] as? String ?? ""
        
        switch eventType {
        case "init":
            if let convId = json["conversation_id"] as? String {
                self.activeConversationId = convId
                messages[messageIndex].conversationId = convId
                saveSessions()
            }
            
        case "step_update":
            if let update = json["step_update"] as? [String: Any] {
                let stepTypeRaw = update["step_type"] as? String ?? "agent_response"
                let stepIndex = update["step_index"] as? Int
                let stateRaw = update["state"] as? String ?? "ACTIVE"
                let textDelta = update["text_delta"] as? String ?? ""
                let duration = update["duration_seconds"] as? Double
                
                if stepTypeRaw == "agent_response" {
                    if !textDelta.isEmpty {
                        messages[messageIndex].finalResponse += textDelta
                        currentStreamingText = messages[messageIndex].finalResponse
                    }
                } else if stepTypeRaw == "tool" || stepTypeRaw == "tool_call" {
                    let toolInfo = update["tool_info"] as? [String: Any] ?? [:]
                    let toolName = update["tool_name"] as? String ?? toolInfo["name"] as? String ?? "Tool Execution"
                    
                    var paramsString = ""
                    if let params = toolInfo["parameters"] as? [String: Any] {
                        if let cmd = params["CommandLine"] as? String {
                            paramsString = "$ \(cmd)"
                        } else if let path = params["AbsolutePath"] as? String ?? params["TargetFile"] as? String ?? params["SearchPath"] as? String {
                            paramsString = path
                        } else if let query = params["query"] as? String ?? params["Query"] as? String {
                            paramsString = query
                        } else if let jsonData = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted),
                                  let str = String(data: jsonData, encoding: .utf8) {
                            paramsString = str
                        }
                    }
                    
                    let stdout = toolInfo["output"] as? String
                    let stepState: AGYStepState = (stateRaw == "DONE") ? .done : .active
                    let icon = iconForTool(toolName)
                    
                    // Update existing step if matching stepIndex found
                    if let stepIdx = stepIndex, let existingIdx = messages[messageIndex].steps.firstIndex(where: { $0.stepIndex == stepIdx }) {
                        messages[messageIndex].steps[existingIdx].state = stepState
                        if let dur = duration {
                            messages[messageIndex].steps[existingIdx].durationSeconds = dur
                        }
                        if let out = stdout, !out.isEmpty {
                            messages[messageIndex].steps[existingIdx].stdout = out
                            messages[messageIndex].steps[existingIdx].content = out
                        }
                    } else {
                        // Append new step
                        let step = AGYStep(
                            stepIndex: stepIndex,
                            type: .toolCall,
                            state: stepState,
                            title: "\(icon) \(toolName)",
                            content: stdout ?? paramsString,
                            toolName: toolName,
                            toolArgs: paramsString,
                            stdout: stdout,
                            durationSeconds: duration
                        )
                        messages[messageIndex].steps.append(step)
                    }
                } else if stepTypeRaw == "thought" {
                    let text = update["text"] as? String ?? ""
                    if !text.isEmpty {
                        let step = AGYStep(
                            stepIndex: stepIndex,
                            type: .thought,
                            state: .done,
                            title: "💭 Thinking",
                            content: text,
                            durationSeconds: duration
                        )
                        messages[messageIndex].steps.append(step)
                    }
                }
            }
            
        case "result":
            if let res = json["result"] as? [String: Any] {
                if let resp = res["response"] as? String, !resp.isEmpty {
                    messages[messageIndex].finalResponse = resp
                }
                if let usage = res["usage"] as? [String: Any], let total = usage["total_tokens"] as? Int {
                    messages[messageIndex].usageTokens = total
                }
            }
            saveSessions()
            
        case "completed":
            finishMessage(at: messageIndex)
            
        default:
            break
        }
    }
    
    private func iconForTool(_ name: String) -> String {
        switch name.lowercased() {
        case let s where s.contains("command"): return "❯"
        case let s where s.contains("file"): return "📄"
        case let s where s.contains("search") || s.contains("grep") || s.contains("find"): return "🔍"
        case let s where s.contains("browser"): return "🌐"
        case let s where s.contains("subagent"): return "🤖"
        default: return "⚙️"
        }
    }
    
    private func finishMessage(at index: Int) {
        guard index < messages.count else { return }
        messages[index].isRunning = false
        isRunning = false
        saveSessions()
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    private func failMessage(at index: Int, error: String) {
        guard index < messages.count else { return }
        messages[index].isRunning = false
        messages[index].finalResponse += "\n\n❌ Error: \(error)"
        isRunning = false
        saveSessions()
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
