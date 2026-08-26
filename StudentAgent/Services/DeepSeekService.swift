//
//  DeepSeekService.swift
//  StudentAgent
//

import Foundation

public struct DeepSeekMessage: Codable {
    public let role: String
    public let content: String?
    public let tool_calls: [DeepSeekToolCall]?
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
    public let function: DeepSeekFunctionCall
}

public struct DeepSeekFunctionCall: Codable {
    public let name: String
    public let arguments: String
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
}

public struct DeepSeekChatResponse: Codable {
    public struct Choice: Codable {
        public let message: DeepSeekMessage
        public let finish_reason: String?
    }
    public let choices: [Choice]
}

public final class DeepSeekService {
    public static let shared = DeepSeekService()
    
    private init() {}
    
    public func sendChatCompletion(
        messages: [DeepSeekMessage],
        tools: [DeepSeekToolDefinition]? = nil,
        model: String = AppConfig.defaultModel,
        apiKey: String = AppConfig.activeDeepSeekAPIKey
    ) async throws -> DeepSeekMessage {
        guard !apiKey.isEmpty && apiKey != "YOUR_DEEPSEEK_API_KEY_HERE" else {
            let err = NSError(
                domain: "DeepSeekService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "DeepSeek API key is missing. Please set your API key in Secrets.swift or in the app Settings."]
            )
            await DebugLogger.shared.log(type: .error, title: "API Key Missing", payload: err.localizedDescription)
            throw err
        }
        
        let url = URL(string: "\(AppConfig.deepSeekBaseURL)/v1/chat/completions")!
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
            max_tokens: 2048
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let encodedData = try encoder.encode(requestBody)
        request.httpBody = encodedData
        
        let requestJSONString = String(data: encodedData, encoding: .utf8) ?? ""
        await DebugLogger.shared.log(type: .apiRequest, title: "POST /v1/chat/completions (\(model))", payload: requestJSONString)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let err = NSError(domain: "DeepSeekService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])
            await DebugLogger.shared.log(type: .error, title: "Network Error", payload: err.localizedDescription)
            throw err
        }
        
        let rawResponseString = String(data: data, encoding: .utf8) ?? ""
        
        guard httpResponse.statusCode == 200 else {
            let err = NSError(domain: "DeepSeekService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "DeepSeek API Error (HTTP \(httpResponse.statusCode)): \(rawResponseString)"])
            await DebugLogger.shared.log(type: .error, title: "API Error (HTTP \(httpResponse.statusCode))", payload: rawResponseString)
            throw err
        }
        
        await DebugLogger.shared.log(type: .apiResponse, title: "DeepSeek Response (200 OK)", payload: rawResponseString)
        
        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let firstChoice = decoded.choices.first else {
            let err = NSError(domain: "DeepSeekService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No completion returned."])
            await DebugLogger.shared.log(type: .error, title: "Parse Error", payload: err.localizedDescription)
            throw err
        }
        
        return firstChoice.message
    }
}
