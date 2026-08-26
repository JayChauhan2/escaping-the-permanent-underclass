//
//  AgentOrchestrator.swift
//  StudentAgent
//

import Foundation
import SwiftUI

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
    
    private let deepSeek = DeepSeekService.shared
    private let eventKit = EventKitService.shared
    private let storage = ChatStorage.shared
    private let debugLogger = DebugLogger.shared
    
    private var activeProcessingTask: Task<Void, Never>?
    
    public init() {}
    
    public var activeEmailService: EmailServiceProtocol {
        switch currentProvider {
        case .outlook: return OutlookService.shared
        case .gmail: return GmailService.shared
        case .simulated: return GmailService.shared
        }
    }
    
    // MARK: - Available Tools for DeepSeek
    private var availableTools: [DeepSeekToolDefinition] {
        return [
            DeepSeekToolDefinition(
                name: "fetch_recent_emails",
                description: "Fetches recent student emails from live Gmail/Outlook inbox with full message bodies.",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "hours_back": [
                            "type": "integer",
                            "description": "Number of hours back to check. Use 0 for no time restriction (fetch by raw count)."
                        ],
                        "max_count": [
                            "type": "integer",
                            "description": "Maximum number of emails to retrieve (e.g. 20, 50, or 100)"
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
                        ],
                        "max_count": [
                            "type": "integer",
                            "description": "Maximum number of matching emails to retrieve"
                        ]
                    ]),
                    "required": AnyCodable(["query"])
                ]
            ),
            DeepSeekToolDefinition(
                name: "propose_calendar_event",
                description: "Drafts a proposed Apple Calendar event in user local time for the user to review and confirm.",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "title": [
                            "type": "string",
                            "description": "Event title (e.g. 'ISG ILIAD Info Session 2')"
                        ],
                        "start_date_iso": [
                            "type": "string",
                            "description": "Start date-time in local time (e.g. '2026-09-04T17:30:00')"
                        ],
                        "end_date_iso": [
                            "type": "string",
                            "description": "End date-time in local time (e.g. '2026-09-04T18:30:00')"
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
                name: "commit_calendar_event",
                description: "Directly adds a confirmed event in user local time to Apple Calendar. Use when user confirms via chat ('Yes, add it', 'Go ahead', 'Add to calendar').",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "title": [
                            "type": "string",
                            "description": "Event title"
                        ],
                        "start_date_iso": [
                            "type": "string",
                            "description": "Local date-time string (e.g. '2026-09-04T17:30:00')"
                        ],
                        "end_date_iso": [
                            "type": "string",
                            "description": "Local end date-time string"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Notes or booking link"
                        ],
                        "is_all_day": [
                            "type": "boolean",
                            "description": "Whether all day"
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
                            "description": "Local due date-time string (e.g. '2026-09-04T17:00:00')"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Additional notes"
                        ]
                    ]),
                    "required": AnyCodable(["title"])
                ]
            ),
            DeepSeekToolDefinition(
                name: "commit_reminder",
                description: "Directly adds a confirmed reminder to Apple Reminders. Use when user confirms via chat.",
                parameters: [
                    "type": AnyCodable("object"),
                    "properties": AnyCodable([
                        "title": [
                            "type": "string",
                            "description": "Reminder task title"
                        ],
                        "due_date_iso": [
                            "type": "string",
                            "description": "Local due date-time string"
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Notes"
                        ]
                    ]),
                    "required": AnyCodable(["title"])
                ]
            )
        ]
    }
    
    // Caveman Mode System Instructions with Local Timezone
    private var systemPrompt: String {
        let tz = TimeZone.current
        let nowString = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short)
        return """
        Current Time: \(nowString).
        Local Timezone: \(tz.identifier) (UTC offset: \(tz.secondsFromGMT() / 3600) hours).
        
        # CAVEMAN MODE INSTRUCTIONS:
        - No filler: Drop articles (a, an, the), pleasantries, preambles, and conversational hedging.
        - Be direct: Short sentences, keywords, actionable steps.
        - Keep meaning: Preserve full technical accuracy, dates, links, names, and course details.
        - Structure: [Thing] [Action] [Reason] -> [Next Step].
        
        # OPERATING RULES:
        1. Only call email tools when user asks about emails, tasks, schedule, advisor, classes, or student gov.
        2. When creating start_date_iso or due_date_iso, ALWAYS specify exact local time (e.g. 5:30 PM on Sep 4 = '2026-09-04T17:30:00'). Do NOT convert to UTC.
        3. Propose calendar/reminder draft cards first.
        4. If user says 'add it', 'go ahead', 'confirm', or confirms in chat, use `commit_calendar_event` or `commit_reminder` immediately.
        """
    }
    
    public func processUserMessage(
        text: String,
        conversationId: String
    ) {
        activeProcessingTask?.cancel()
        
        activeProcessingTask = Task {
            await executeAgentTurn(text: text, conversationId: conversationId)
        }
    }
    
    public func stopGeneration() {
        activeProcessingTask?.cancel()
        activeProcessingTask = nil
        withAnimation {
            isProcessing = false
            currentStep = nil
        }
        debugLogger.log(type: .general, title: "Generation Stopped", payload: "User tapped stop button.")
    }
    
    private func executeAgentTurn(
        text: String,
        conversationId: String
    ) async {
        isProcessing = true
        currentStep = AgentExecutionStep(icon: "sparkles", text: "Thinking...")
        
        debugLogger.log(type: .userPrompt, title: "User Input", payload: text)
        
        let userMsg = ChatMessageItem(role: .user, content: text, conversationId: conversationId)
        storage.addMessage(userMsg)
        
        let history = storage.getMessages(for: conversationId)
        
        var apiMessages: [DeepSeekMessage] = [
            DeepSeekMessage(role: "system", content: systemPrompt)
        ]
        
        // Full conversation memory
        for msg in history {
            apiMessages.append(DeepSeekMessage(role: msg.roleRaw, content: msg.content))
        }
        
        do {
            var collectedActions: [CalendarAction] = []
            var collectedEmails: [EmailItem] = []
            var streamingMsg: ChatMessageItem? = nil
            
            var currentTurn = 0
            while currentTurn < 10 {
                if Task.isCancelled { break }
                currentTurn += 1
                
                let responseMessage = try await deepSeek.sendChatCompletionStream(
                    messages: apiMessages,
                    tools: availableTools,
                    onToken: { token in
                        if streamingMsg == nil {
                            let newMsg = ChatMessageItem(
                                role: .assistant,
                                content: token,
                                conversationId: conversationId,
                                isStreaming: true
                            )
                            streamingMsg = newMsg
                            self.storage.addMessage(newMsg)
                            self.currentStep = nil
                        } else {
                            streamingMsg?.content += token
                        }
                    }
                )
                
                if Task.isCancelled { break }
                apiMessages.append(responseMessage)
                
                if let toolCalls = responseMessage.tool_calls, !toolCalls.isEmpty {
                    for toolCall in toolCalls {
                        if Task.isCancelled { break }
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
                    if let msg = streamingMsg {
                        msg.isStreaming = false
                        if !collectedActions.isEmpty {
                            msg.proposedActions = collectedActions
                        }
                        if !collectedEmails.isEmpty {
                            msg.emailDigests = collectedEmails
                        }
                        self.storage.saveData()
                    } else {
                        let finalContent = responseMessage.content ?? "Here is what I found."
                        let assistantMsg = ChatMessageItem(
                            role: .assistant,
                            content: finalContent,
                            conversationId: conversationId,
                            isStreaming: false
                        )
                        if !collectedActions.isEmpty {
                            assistantMsg.proposedActions = collectedActions
                        }
                        if !collectedEmails.isEmpty {
                            assistantMsg.emailDigests = collectedEmails
                        }
                        storage.addMessage(assistantMsg)
                    }
                    break
                }
            }
        } catch {
            if !Task.isCancelled {
                debugLogger.log(type: .error, title: "Processing Error", payload: error.localizedDescription)
                let errorMsg = ChatMessageItem(
                    role: .assistant,
                    content: "⚠️ \(error.localizedDescription)",
                    conversationId: conversationId
                )
                storage.addMessage(errorMsg)
            }
        }
        
        withAnimation {
            isProcessing = false
            currentStep = nil
        }
    }
    
    private func describeToolCall(name: String) -> (icon: String, label: String) {
        switch name {
        case "fetch_recent_emails":
            return ("envelope.badge.shield.half.filled", "Reading inbox messages...")
        case "search_emails":
            return ("magnifyingglass", "Searching relevant emails...")
        case "propose_calendar_event":
            return ("calendar.badge.plus", "Drafting calendar event...")
        case "commit_calendar_event":
            return ("calendar.badge.checkmark", "Writing to Apple Calendar...")
        case "propose_reminder":
            return ("checklist", "Drafting reminder task...")
        case "commit_reminder":
            return ("checklist.checked", "Writing to Apple Reminders...")
        default:
            return ("gearshape.2.fill", "Executing tool...")
        }
    }
    
    private func parseDateLocal(_ string: String) -> Date? {
        // Strip trailing Z or +00:00 to interpret local hour representation directly in TimeZone.current
        let clean = string.replacingOccurrences(of: "Z", with: "")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        for format in formats {
            let df = DateFormatter()
            df.dateFormat = format
            df.timeZone = TimeZone.current
            df.locale = Locale(identifier: "en_US_POSIX")
            if let d = df.date(from: clean) {
                return d
            }
        }
        return ISO8601DateFormatter().date(from: string)
    }
    
    private func executeTool(
        name: String,
        argumentsJSON: String,
        collectedActions: inout [CalendarAction],
        collectedEmails: inout [EmailItem]
    ) async throws -> String {
        let args = (try? JSONSerialization.jsonObject(with: argumentsJSON.data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
        
        switch name {
        case "fetch_recent_emails":
            let hours = args["hours_back"] as? Int ?? 0
            let maxCount = args["max_count"] as? Int ?? 50
            let emails = try await activeEmailService.fetchRecentEmails(hoursBack: hours, maxCount: maxCount)
            collectedEmails.append(contentsOf: emails)
            
            let summaries = emails.map { item in
                return "From: \(item.senderName)\nSubject: \(item.subject)\nDate: \(item.receivedDate)\nFull Content:\n\(item.fullBody ?? item.bodySnippet)"
            }.joined(separator: "\n---\n")
            return summaries.isEmpty ? "No recent emails found." : summaries
            
        case "search_emails":
            let query = args["query"] as? String ?? ""
            let maxCount = args["max_count"] as? Int ?? 25
            let emails = try await activeEmailService.searchEmails(query: query, maxCount: maxCount)
            collectedEmails.append(contentsOf: emails)
            
            let summaries = emails.map { item in
                return "From: \(item.senderName)\nSubject: \(item.subject)\nFull Content:\n\(item.fullBody ?? item.bodySnippet)"
            }.joined(separator: "\n---\n")
            return summaries.isEmpty ? "No emails matching query '\(query)'." : summaries
            
        case "propose_calendar_event":
            let title = args["title"] as? String ?? "New Event"
            let startStr = args["start_date_iso"] as? String ?? ""
            let startDate = parseDateLocal(startStr) ?? Date().addingTimeInterval(86400)
            let endStr = args["end_date_iso"] as? String
            let endDate = endStr != nil ? parseDateLocal(endStr!) : nil
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
            
        case "commit_calendar_event":
            let title = args["title"] as? String ?? "Event"
            let startStr = args["start_date_iso"] as? String ?? ""
            let startDate = parseDateLocal(startStr) ?? Date().addingTimeInterval(86400)
            let endStr = args["end_date_iso"] as? String
            let endDate = endStr != nil ? parseDateLocal(endStr!) : nil
            let notes = args["notes"] as? String
            let isAllDay = args["is_all_day"] as? Bool ?? false
            
            let createdId = try await eventKit.commitCalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                notes: notes
            )
            debugLogger.log(type: .eventKit, title: "Calendar Event Committed", payload: "Title: \(title), ID: \(createdId)")
            
            let action = CalendarAction(
                type: .calendarEvent,
                title: title,
                notes: notes,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                status: .confirmed,
                createdEventIdentifier: createdId
            )
            collectedActions.append(action)
            return "SUCCESS: Event '\(title)' committed to Apple Calendar with ID: \(createdId)."
            
        case "propose_reminder":
            let title = args["title"] as? String ?? "Reminder"
            let dueStr = args["due_date_iso"] as? String
            let dueDate = dueStr != nil ? parseDateLocal(dueStr!) : nil
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
            
        case "commit_reminder":
            let title = args["title"] as? String ?? "Reminder"
            let dueStr = args["due_date_iso"] as? String
            let dueDate = dueStr != nil ? parseDateLocal(dueStr!) : nil
            let notes = args["notes"] as? String
            
            let createdId = try await eventKit.commitReminder(
                title: title,
                dueDate: dueDate,
                notes: notes
            )
            debugLogger.log(type: .eventKit, title: "Apple Reminder Committed", payload: "Title: \(title), ID: \(createdId)")
            
            let action = CalendarAction(
                type: .appleReminder,
                title: title,
                notes: notes,
                startDate: dueDate ?? Date(),
                status: .confirmed,
                createdEventIdentifier: createdId
            )
            collectedActions.append(action)
            return "SUCCESS: Reminder '\(title)' committed to Apple Reminders."
            
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
