//
//  EmailItem.swift
//  StudentAgent
//

import Foundation

public enum EmailUrgency: String, Codable, CaseIterable {
    case urgent = "Urgent"         // Advisor appointments, I-9 forms, imminent deadlines
    case course = "Course"         // Syllabus, homework, lectures, assignments
    case opportunity = "Opportunity" // Jobs, research, internships, student gov
    case newsletter = "Announcement" // General campus news, clubs, alerts
    case general = "General"
    
    public var badgeColorHex: String {
        switch self {
        case .urgent: return "#FF3B30"
        case .course: return "#007AFF"
        case .opportunity: return "#34C759"
        case .newsletter: return "#FF9500"
        case .general: return "#8E8E93"
        }
    }
}

public struct EmailItem: Identifiable, Codable, Hashable {
    public let id: String
    public let senderName: String
    public let senderEmail: String
    public let subject: String
    public let receivedDate: Date
    public let bodySnippet: String
    public let fullBody: String?
    public var isUnread: Bool
    public var urgency: EmailUrgency
    public var extractedActionItems: [String]
    public var proposedEventDate: Date?
    
    public init(
        id: String = UUID().uuidString,
        senderName: String,
        senderEmail: String,
        subject: String,
        receivedDate: Date = Date(),
        bodySnippet: String,
        fullBody: String? = nil,
        isUnread: Bool = true,
        urgency: EmailUrgency = .general,
        extractedActionItems: [String] = [],
        proposedEventDate: Date? = nil
    ) {
        self.id = id
        self.senderName = senderName
        self.senderEmail = senderEmail
        self.subject = subject
        self.receivedDate = receivedDate
        self.bodySnippet = bodySnippet
        self.fullBody = fullBody
        self.isUnread = isUnread
        self.urgency = urgency
        self.extractedActionItems = extractedActionItems
        self.proposedEventDate = proposedEventDate
    }
}
