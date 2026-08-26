//
//  AgentOrchestrator.swift
//  StudentAgent
//

import Foundation
import SwiftUI

public enum AgentMode: String, CaseIterable, Identifiable {
    case executive = "Executive"
    case triage = "Triage"
    
    public var id: String { rawValue }
}

public struct AgentExecutionStep: Identifiable, Equatable {
    public let id = UUID()
    public let icon: String
    public let text: String
    public let timestamp = Date()
}

@MainActor
public final class AgentOrchestrator: ObservableObject {
    @Published public var isProcessing: Bool = false
    @Published public var currentStep: AgentExecutionStep?
    @Published public var currentProvider: AppConfig.EmailProvider = AppConfig.defaultEmailProvider
    @Published public var activeMode: AgentMode = .executive
    
    private let deepSeek = DeepSeekService.shared
    private let eventKit = EventKitService.shared
    private let storage = ChatStorage.shared
    private let debugLogger = DebugLogger.shared
    
    public init() {}
    
    public var activeEmailService: EmailServiceProtocol {
        switch currentProvider {
        case .outlook: return OutlookService.shared
        case .gmail: return GmailService.shared
        case .simulated: return SimulatedEmailServiceWrapper.shared
        }
    }
    
    // MARK: - Available Tools for DeepSeek
    private var availableTools: [DeepSeekToolDefinition] {
        return [
            DeepSeekToolDefinition(
                name: "fetch_recent_emails",
                description: "Fetches recent student emails from Outlook/Gmail inbox.",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "hours_back": [
                            "type": "integer",
                            "description": "Number of hours back to check (e.g. 24 or 48)"
                        ],
                        "max_count": [
                            "type": "integer",
                            "description": "Maximum number of emails to retrieve (e.g. 10)"
                        ]
                    ]),
                    "required": AnyCodable([])
                ]
            ),
            DeepSeekToolDefinition(
                name: "search_emails",
                description: "Searches inbox for specific keywords (e.g. 'advisor', 'I-9', 'PHYS 211', 'student government', 'syllabus').",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "query": [
                            "type": "string",
                            "description": "Search keyword or query"
                        ]
                    ]),
                    "required": AnyCodable(["query"])
                ]
            ),
            DeepSeekToolDefinition(
                name: "propose_calendar_event",
                description: "Drafts a proposed Apple Calendar event for the user to review and confirm.",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "title": [
                            "type": "string",
                            "description": "Event title (e.g. 'Academic Advising with Dr. Vance')"
                        ],
                        "start_date_iso": [
                            "type": "string",
                            "description": "ISO 8601 start date-time string (e.g. 2026-08-27T14:00:00Z)"
                        ],
                        "end_date_iso": [
                            "type": "string",
                            "description": "ISO 8601 end date-time string"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Notes, booking link, or email context"
                        ],
                        "is_all_day": [
                            "type": "boolean",
                            "description": "Whether the event lasts all day"
                        ]
                    ]),
                    "required": AnyCodable(["title", "start_date_iso"])
                ]
            ),
            DeepSeekToolDefinition(
                name: "propose_reminder",
                description: "Drafts a proposed Apple Reminder task for the user to confirm.",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "title": [
                            "type": "string",
                            "description": "Reminder task title (e.g. 'Submit Form I-9 online')"
                        ],
                        "due_date_iso": [
                            "type": "string",
                            "description": "ISO 8601 due date-time string"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Additional notes"
                        ]
                    ]),
                    "required": AnyCodable(["title"])
                ]
            )
        ]
    }
    
    private func generateSystemPrompt(mode: AgentMode) -> String {
        let nowString = ISO8601DateFormatter().string(from: Date())
        
        if mode == .triage {
            return """
            You are in TRIAGE MODE for an undergraduate student on iOS.
            Current Time: \(nowString).
            
            YOUR JOB IN TRIAGE MODE:
            1. Scrutinize student inbox messages ruthlessly.
            2. Automatically fetch recent emails if needed to identify upcoming deadlines, advisor bookings, urgent I-9 paperwork, or professor announcements.
            3. Draft proposed Apple Calendar and Reminder actions for every actionable deadline found.
            4. Keep output in ultra-brief, bulleted lists with urgency ratings (🔴 High, 🟡 Medium, 🟢 Low).
            """
        } else {
            return """
            You are in EXECUTIVE MODE for an undergraduate student on iOS.
            Current Time: \(nowString).
            
            YOUR JOB IN EXECUTIVE MODE:
            1. Act as a strategic personal assistant.
            2. Answer questions, assist with class prep, explain concepts, and draft emails or messages.
            3. Only call email tools when explicitly asked to look at emails or tasks.
            4. Keep responses concise, structured, and mobile-friendly.
            """
        }
    }
    
    public func processUserMessage(
        text: String,
        conversationId: String,
        mode: AgentMode = .executive
    ) async {
        isProcessing = true
        self.activeMode = mode
        currentStep = AgentExecutionStep(icon: "sparkles", text: "Thinking...")
        
        debugLogger.log(type: .userPrompt, title: "User Input (\(mode.rawValue) Mode)", payload: text)
        
        let userMsg = ChatMessageItem(role: .user, content: text, conversationId: conversationId)
        storage.addMessage(userMsg)
        
        let history = storage.getMessages(for: conversationId)
        
        var apiMessages: [DeepSeekMessage] = [
            DeepSeekMessage(role: "system", content: generateSystemPrompt(mode: mode))
        ]
        
        for msg in history.suffix(8) {
            apiMessages.append(DeepSeekMessage(role: msg.roleRaw, content: msg.content))
        }
        
        do {
            var collectedActions: [CalendarAction] = []
            var collectedEmails: [EmailItem] = []
            
            var currentTurn = 0
            while currentTurn < 3 {
                currentTurn += 1
                
                let responseMessage = try await deepSeek.sendChatCompletion(
                    messages: apiMessages,
                    tools: availableTools
                )
                
                apiMessages.append(responseMessage)
                
                if let toolCalls = responseMessage.tool_calls, !toolCalls.isEmpty {
                    for toolCall in toolCalls {
                        let stepInfo = describeToolCall(name: toolCall.function.name)
                        withAnimation {
                            self.currentStep = AgentExecutionStep(icon: stepInfo.icon, text: stepInfo.label)
                        }
                        
                        debugLogger.log(
                            type: .toolCall,
                            title: "Executing Tool: \(toolCall.function.name)",
                            payload: toolCall.function.arguments
                        )
                        
                        let toolResult = try await executeTool(
                            name: toolCall.function.name,
                            argumentsJSON: toolCall.function.arguments,
                            collectedActions: &collectedActions,
                            collectedEmails: &collectedEmails
                        )
                        
                        debugLogger.log(
                            type: .toolCall,
                            title: "Tool Output: \(toolCall.function.name)",
                            payload: toolResult
                        )
                        
                        apiMessages.append(DeepSeekMessage(
                            role: "tool",
                            content: toolResult,
                            tool_call_id: toolCall.id,
                            name: toolCall.function.name
                        ))
                    }
                } else {
                    withAnimation {
                        self.currentStep = AgentExecutionStep(icon: "pencil.line", text: "Finalizing response...")
                    }
                    
                    let assistantContent = responseMessage.content ?? "Here is what I found."
                    let assistantMsg = ChatMessageItem(
                        role: .assistant,
                        content: assistantContent,
                        conversationId: conversationId
                    )
                    
                    if !collectedActions.isEmpty {
                        assistantMsg.proposedActions = collectedActions
                    }
                    if !collectedEmails.isEmpty {
                        assistantMsg.emailDigests = collectedEmails
                    }
                    
                    storage.addMessage(assistantMsg)
                    break
                }
            }
        } catch {
            debugLogger.log(type: .error, title: "Processing Error", payload: error.localizedDescription)
            let errorMsg = ChatMessageItem(
                role: .assistant,
                content: "⚠️ Error: \(error.localizedDescription)",
                conversationId: conversationId
            )
            storage.addMessage(errorMsg)
        }
        
        withAnimation {
            isProcessing = false
            currentStep = nil
        }
    }
    
    private func describeToolCall(name: String) -> (icon: String, label: String) {
        switch name {
        case "fetch_recent_emails":
            return ("envelope.badge.shield.half.filled", "Reading recent emails...")
        case "search_emails":
            return ("magnifyingglass", "Searching relevant emails...")
        case "propose_calendar_event":
            return ("calendar.badge.plus", "Drafting calendar event...")
        case "propose_reminder":
            return ("checklist", "Drafting reminder task...")
        default:
            return ("gearshape.2.fill", "Executing tool...")
        }
    }
    
    private func executeTool(
        name: String,
        argumentsJSON: String,
        collectedActions: inout [CalendarAction],
        collectedEmails: inout [EmailItem]
    ) async throws -> String {
        let args = (try? JSONSerialization.jsonObject(with: argumentsJSON.data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
        let isoFormatter = ISO8601DateFormatter()
        
        switch name {
        case "fetch_recent_emails":
            let hours = args["hours_back"] as? Int ?? 48
            let maxCount = args["max_count"] as? Int ?? 10
            let emails = try await activeEmailService.fetchRecentEmails(hoursBack: hours, maxCount: maxCount)
            collectedEmails.append(contentsOf: emails)
            
            let summaries = emails.map { item in
                return "From: \(item.senderName) | Subject: \(item.subject) | Date: \(item.receivedDate) | Snippet: \(item.bodySnippet)"
            }.joined(separator: "\n---\n")
            return summaries.isEmpty ? "No recent emails found." : summaries
            
        case "search_emails":
            let query = args["query"] as? String ?? ""
            let emails = try await activeEmailService.searchEmails(query: query, maxCount: 10)
            collectedEmails.append(contentsOf: emails)
            
            let summaries = emails.map { item in
                return "From: \(item.senderName) | Subject: \(item.subject) | Snippet: \(item.bodySnippet)"
            }.joined(separator: "\n---\n")
            return summaries.isEmpty ? "No emails matching query '\(query)'." : summaries
            
        case "propose_calendar_event":
            let title = args["title"] as? String ?? "New Event"
            let startStr = args["start_date_iso"] as? String ?? ""
            let startDate = isoFormatter.date(from: startStr) ?? Date().addingTimeInterval(86400)
            let endStr = args["end_date_iso"] as? String
            let endDate = endStr != nil ? isoFormatter.date(from: endStr!) : nil
            let notes = args["notes"] as? String
            let isAllDay = args["is_all_day"] as? Bool ?? false
            
            let action = CalendarAction(
                type: .calendarEvent,
                title: title,
                notes: notes,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                status: .proposed
            )
            collectedActions.append(action)
            return "Drafted calendar event '\(title)' for: \(startDate)."
            
        case "propose_reminder":
            let title = args["title"] as? String ?? "Reminder"
            let dueStr = args["due_date_iso"] as? String
            let dueDate = dueStr != nil ? isoFormatter.date(from: dueStr!) : nil
            let notes = args["notes"] as? String
            
            let action = CalendarAction(
                type: .appleReminder,
                title: title,
                notes: notes,
                startDate: dueDate ?? Date(),
                status: .proposed
            )
            collectedActions.append(action)
            return "Drafted reminder '\(title)'."
            
        default:
            return "Tool \(name) executed."
        }
    }
    
    public func confirmAction(_ action: CalendarAction, message: ChatMessageItem) async throws {
        var createdId: String? = nil
        switch action.type {
        case .calendarEvent:
            createdId = try await eventKit.commitCalendarEvent(
                title: action.title,
                startDate: action.startDate,
                endDate: action.endDate,
                isAllDay: action.isAllDay,
                notes: action.notes
            )
            debugLogger.log(type: .eventKit, title: "Calendar Event Committed", payload: "Title: \(action.title), ID: \(createdId ?? "")")
        case .appleReminder:
            createdId = try await eventKit.commitReminder(
                title: action.title,
                dueDate: action.startDate,
                notes: action.notes
            )
            debugLogger.log(type: .eventKit, title: "Apple Reminder Committed", payload: "Title: \(action.title), ID: \(createdId ?? "")")
        }
        
        storage.updateActionStatus(
            actionId: action.id,
            in: message.id,
            conversationId: message.conversationId,
            newStatus: .confirmed,
            eventId: createdId
        )
    }
}

// Wrapper for Simulated Service
public final class SimulatedEmailServiceWrapper: EmailServiceProtocol {
    public static let shared = SimulatedEmailServiceWrapper()
    public var providerName: String { "Simulated Student Inbox" }
    public var isAuthenticated: Bool { true }
    
    public func authenticate() async throws -> Bool { true }
    public func signOut() async throws {}
    
    public func fetchRecentEmails(hoursBack: Int, maxCount: Int) async throws -> [EmailItem] {
        return SimulatedEmailService.shared.getSampleStudentEmails()
    }
    
    public func searchEmails(query: String, maxCount: Int) async throws -> [EmailItem] {
        return SimulatedEmailService.shared.getSampleStudentEmails().filter {
            $0.subject.localizedCaseInsensitiveContains(query) ||
            $0.bodySnippet.localizedCaseInsensitiveContains(query)
        }
    }
    
    public func getEmailDetails(id: String) async throws -> EmailItem? {
        return SimulatedEmailService.shared.getSampleStudentEmails().first(where: { $0.id == id })
    }
}
