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
    @Published public var messages: [AGYMessage] = []
    @Published public var currentStreamingText: String = ""
    @Published public var connectionError: String? = nil
    
    private var activeTask: Task<Void, Never>? = nil
    
    public var bridgeBaseURL: String {
        let saved = UserDefaults.standard.string(forKey: "agy_bridge_url")
        if let saved = saved, !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return saved.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "http://172.16.53.85:11435"
    }
    
    public func setBridgeURL(_ urlString: String) {
        let cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(cleaned, forKey: "agy_bridge_url")
        Task {
            await checkHealth()
        }
    }
    
    public init() {
        Task {
            await checkHealth()
        }
    }
    
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
    
    public func sendPrompt(_ text: String, customCwd: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let message = AGYMessage(
            prompt: trimmed,
            conversationId: activeConversationId,
            isRunning: true
        )
        messages.append(message)
        let messageIndex = messages.count - 1
        
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
            messages[idx].finalResponse += "\n[⚠️ Task Aborted by User]"
        }
        
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
            }
            
        case "step_update":
            if let update = json["step_update"] as? [String: Any] {
                let stepTypeRaw = update["step_type"] as? String ?? "agent_response"
                let stateRaw = update["state"] as? String ?? "ACTIVE"
                let textDelta = update["text_delta"] as? String ?? ""
                let duration = update["duration_seconds"] as? Double
                
                if stepTypeRaw == "agent_response" {
                    messages[messageIndex].finalResponse += textDelta
                    currentStreamingText = messages[messageIndex].finalResponse
                } else if stepTypeRaw == "tool_call" {
                    let toolName = update["tool_name"] as? String ?? "tool"
                    let args = update["arguments"] as? String ?? ""
                    let step = AGYStep(
                        type: .toolCall,
                        state: stateRaw == "DONE" ? .done : .active,
                        title: "🛠 \(toolName)",
                        content: args,
                        toolName: toolName,
                        toolArgs: args,
                        durationSeconds: duration
                    )
                    messages[messageIndex].steps.append(step)
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
            
        case "completed":
            finishMessage(at: messageIndex)
            
        default:
            break
        }
    }
    
    private func finishMessage(at index: Int) {
        guard index < messages.count else { return }
        messages[index].isRunning = false
        isRunning = false
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    private func failMessage(at index: Int, error: String) {
        guard index < messages.count else { return }
        messages[index].isRunning = false
        messages[index].finalResponse += "\n\n❌ Error: \(error)"
        isRunning = false
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
