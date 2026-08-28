//
//  DeepSeekService.swift
//  StudentAgent
//

import Foundation

public struct DeepSeekMessage: Codable {
    public let role: String
    public var content: String?
    public var tool_calls: [DeepSeekToolCall]?
    public let tool_call_id: String?
    public let name: String?
    
    public init(role: String, content: String?, tool_calls: [DeepSeekToolCall]? = nil, tool_call_id: String? = nil, name: String? = nil) {
        self.role = role
        self.content = content
        self.tool_calls = tool_calls
        self.tool_call_id = tool_call_id
        self.name = name
    }
}

public struct DeepSeekToolCall: Codable, Identifiable {
    public let id: String
    public let type: String
    public var function: DeepSeekFunctionCall
    
    public init(id: String, type: String = "function", function: DeepSeekFunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

public struct DeepSeekFunctionCall: Codable {
    public var name: String
    public var arguments: String
    
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

public struct DeepSeekToolDefinition: Codable {
    public let type: String
    public let function: DeepSeekFunctionDefinition
    
    public init(name: String, description: String, parameters: [String: AnyCodable]) {
        self.type = "function"
        self.function = DeepSeekFunctionDefinition(name: name, description: description, parameters: parameters)
    }
}

public struct DeepSeekFunctionDefinition: Codable {
    public let name: String
    public let description: String
    public let parameters: [String: AnyCodable]
}

public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else if let arrVal = try? container.decode([AnyCodable].self) {
            value = arrVal.map { $0.value }
        } else {
            value = ""
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let dictVal = value as? [String: Any] {
            let mapped = dictVal.mapValues { AnyCodable($0) }
            try container.encode(mapped)
        } else if let arrVal = value as? [Any] {
            let mapped = arrVal.map { AnyCodable($0) }
            try container.encode(mapped)
        }
    }
}

public struct DeepSeekChatRequest: Codable {
    public let model: String
    public let messages: [DeepSeekMessage]
    public let tools: [DeepSeekToolDefinition]?
    public let tool_choice: String?
    public let temperature: Double?
    public let max_tokens: Int?
    public let stream: Bool?
}

public struct DeepSeekStreamChunk: Codable {
    public struct Choice: Codable {
        public struct Delta: Codable {
            public let role: String?
            public let content: String?
            public let tool_calls: [StreamToolCall]?
        }
        public struct StreamToolCall: Codable {
            public let index: Int?
            public let id: String?
            public let type: String?
            public struct StreamFunction: Codable {
                public let name: String?
                public let arguments: String?
            }
            public let function: StreamFunction?
        }
        public let delta: Delta?
        public let finish_reason: String?
    }
    public let choices: [Choice]?
}

public final class DeepSeekService {
    public static let shared = DeepSeekService()
    
    private init() {}
    
    // Streaming Chat Completion (Max Tokens 8192)
    public func sendChatCompletionStream(
        messages: [DeepSeekMessage],
        tools: [DeepSeekToolDefinition]? = nil,
        model: String = AppConfig.activeModel,
        apiKey: String = AppConfig.activeAPIKey,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> DeepSeekMessage {
        guard !apiKey.isEmpty && apiKey != "YOUR_DEEPSEEK_API_KEY_HERE" else {
            let err = NSError(
                domain: "DeepSeekService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "API key is missing. Please set your API key in Settings."]
            )
            await DebugLogger.shared.log(type: .error, title: "API Key Missing", payload: err.localizedDescription)
            throw err
        }
        
        let rawBase = AppConfig.activeBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointString = rawBase.hasSuffix("/v1") ? "\(rawBase)/chat/completions" : "\(rawBase)/v1/chat/completions"
        guard let url = URL(string: endpointString) else {
            throw NSError(domain: "DeepSeekService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint: \(endpointString)"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DeepSeekChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            tool_choice: tools != nil ? "auto" : nil,
            temperature: 0.3,
            max_tokens: 8192,
            stream: true
        )
        
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(requestBody)
        request.httpBody = encodedData
        
        let requestJSONString = String(data: encodedData, encoding: .utf8) ?? ""
        await DebugLogger.shared.log(type: .apiRequest, title: "POST /v1/chat/completions (Stream)", payload: requestJSONString)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DeepSeekService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "DeepSeekService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode) error."])
        }
        
        var accumulatedContent = ""
        var accumulatedToolCalls: [Int: (id: String, name: String, args: String)] = [:]
        
        for try await line in bytes.lines {
            if Task.isCancelled { break }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data: ") else { continue }
            
            let payload = String(trimmed.dropFirst(6))
            if payload == "[DONE]" { break }
            
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(DeepSeekStreamChunk.self, from: data),
                  let firstChoice = chunk.choices?.first else {
                continue
            }
            
            if let contentPiece = firstChoice.delta?.content, !contentPiece.isEmpty {
                accumulatedContent += contentPiece
                await onToken(contentPiece)
            }
            
            if let deltaTools = firstChoice.delta?.tool_calls {
                for dt in deltaTools {
                    let idx = dt.index ?? 0
                    var current = accumulatedToolCalls[idx] ?? (id: dt.id ?? "call_\(idx)", name: "", args: "")
                    if let id = dt.id, !id.isEmpty { current.id = id }
                    if let name = dt.function?.name { current.name += name }
                    if let args = dt.function?.arguments { current.args += args }
                    accumulatedToolCalls[idx] = current
                }
            }
        }
        
        var finalToolCalls: [DeepSeekToolCall]? = nil
        if !accumulatedToolCalls.isEmpty {
            finalToolCalls = accumulatedToolCalls.keys.sorted().map { idx in
                let item = accumulatedToolCalls[idx]!
                return DeepSeekToolCall(
                    id: item.id,
                    type: "function",
                    function: DeepSeekFunctionCall(name: item.name, arguments: item.args)
                )
            }
        }
        
        await DebugLogger.shared.log(
            type: .apiResponse,
            title: "DeepSeek Stream Finished",
            payload: "Content length: \(accumulatedContent.count) chars | Tool calls: \(finalToolCalls?.count ?? 0)"
        )
        
        return DeepSeekMessage(
            role: "assistant",
            content: accumulatedContent.isEmpty ? nil : accumulatedContent,
            tool_calls: finalToolCalls
        )
    }
}
