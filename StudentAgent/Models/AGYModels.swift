//
//  AGYModels.swift
//  StudentAgent
//

import Foundation
import SwiftUI

public enum AppMode: String, CaseIterable, Identifiable {
    case campus = "Campus"
    case work = "Work"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .campus: return "graduationcap.fill"
        case .work: return "terminal.fill"
        }
    }
    
    public var label: String {
        switch self {
        case .campus: return "Campus Mode"
        case .work: return "AGY Work Mode"
        }
    }
}

public enum AGYStepType: String, Codable {
    case userInput = "user_input"
    case thought = "thought"
    case toolCall = "tool_call"
    case agentResponse = "agent_response"
    case result = "result"
    case error = "error"
}

public enum AGYStepState: String, Codable {
    case active = "ACTIVE"
    case done = "DONE"
    case error = "ERROR"
}

public struct AGYStep: Identifiable, Equatable, Codable {
    public let id: String
    public var stepIndex: Int?
    public var type: AGYStepType
    public var state: AGYStepState
    public var title: String
    public var content: String
    public var toolName: String?
    public var toolArgs: String?
    public var stdout: String?
    public var timestamp: Date
    public var durationSeconds: Double?
    
    public init(
        id: String = UUID().uuidString,
        stepIndex: Int? = nil,
        type: AGYStepType,
        state: AGYStepState = .active,
        title: String,
        content: String = "",
        toolName: String? = nil,
        toolArgs: String? = nil,
        stdout: String? = nil,
        timestamp: Date = Date(),
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.type = type
        self.state = state
        self.title = title
        self.content = content
        self.toolName = toolName
        self.toolArgs = toolArgs
        self.stdout = stdout
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
    }
}

public struct AGYMessage: Identifiable, Equatable, Codable {
    public let id: String
    public var prompt: String
    public var conversationId: String?
    public var steps: [AGYStep]
    public var finalResponse: String
    public var isRunning: Bool
    public var timestamp: Date
    public var usageTokens: Int?
    
    public init(
        id: String = UUID().uuidString,
        prompt: String,
        conversationId: String? = nil,
        steps: [AGYStep] = [],
        finalResponse: String = "",
        isRunning: Bool = false,
        timestamp: Date = Date(),
        usageTokens: Int? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.conversationId = conversationId
        self.steps = steps
        self.finalResponse = finalResponse
        self.isRunning = isRunning
        self.timestamp = timestamp
        self.usageTokens = usageTokens
    }
}

public struct AGYSessionItem: Identifiable, Equatable, Codable {
    public let id: String
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [AGYMessage]
    public var conversationId: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String = "New AGY Session",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [AGYMessage] = [],
        conversationId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.conversationId = conversationId
    }
}
