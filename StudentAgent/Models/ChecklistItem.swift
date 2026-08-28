//
//  ChecklistItem.swift
//  StudentAgent
//

import Foundation
import SwiftUI

public struct ChecklistItem: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var title: String
    public var notes: String?
    public var dueDate: Date?
    public var isCompleted: Bool
    public var completedAt: Date?
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
    
    // Format date in numerical MM/dd/yyyy format (e.g. 08/27/2026)
    public func formattedDateNumerical(_ date: Date?) -> String {
        guard let date = date else { return "No Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
    
    // Relative due text calculation: "due today", "in X days", "# day(s) ago"
    public var relativeDueText: String? {
        if isCompleted { return nil }
        guard let dueDate = dueDate else { return nil }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: dueDate)
        
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDue)
        let dayDiff = components.day ?? 0
        
        if dayDiff == 0 {
            return "Due today"
        } else if dayDiff == 1 {
            return "In 1 day"
        } else if dayDiff > 1 {
            return "In \(dayDiff) days"
        } else if dayDiff == -1 {
            return "1 day ago"
        } else {
            return "\(abs(dayDiff)) days ago"
        }
    }
    
    // Color coding for relative date badge
    public var relativeDueColor: Color {
        if isCompleted { return Color.grokTextSecondary }
        guard let dueDate = dueDate else { return Color.grokTextSecondary }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: dueDate)
        let dayDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
        
        if dayDiff < 0 {
            return Color.grokError // Overdue (red)
        } else if dayDiff == 0 {
            return Color.grokWarning // Due today (amber/orange)
        } else if dayDiff <= 2 {
            return Color.grokLinkBlue // Upcoming soon (blue)
        } else {
            return Color.grokTextSecondary // Future
        }
    }
    
    // Whether this completed item is within 24h retention window
    public var isWithin24HoursOfCompletion: Bool {
        guard isCompleted, let completedAt = completedAt else { return false }
        return Date().timeIntervalSince(completedAt) < 86400
    }
}
