//
//  CalendarAction.swift
//  StudentAgent
//

import Foundation

public enum CalendarActionType: String, Codable {
    case calendarEvent = "event"
    case appleReminder = "reminder"
}

public enum CalendarActionStatus: String, Codable {
    case proposed = "proposed"
    case confirmed = "confirmed"
    case cancelled = "cancelled"
    case failed = "failed"
}

public struct CalendarAction: Identifiable, Codable, Hashable {
    public let id: String
    public var type: CalendarActionType
    public var title: String
    public var notes: String?
    public var startDate: Date
    public var endDate: Date?
    public var isAllDay: Bool
    public var status: CalendarActionStatus
    public var createdEventIdentifier: String?
    public var relatedEmailSubject: String?
    
    public init(
        id: String = UUID().uuidString,
        type: CalendarActionType = .calendarEvent,
        title: String,
        notes: String? = nil,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        status: CalendarActionStatus = .proposed,
        createdEventIdentifier: String? = nil,
        relatedEmailSubject: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate ?? startDate.addingTimeInterval(3600)
        self.isAllDay = isAllDay
        self.status = status
        self.createdEventIdentifier = createdEventIdentifier
        self.relatedEmailSubject = relatedEmailSubject
    }
}
