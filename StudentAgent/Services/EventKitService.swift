//
//  EventKitService.swift
//  StudentAgent
//

import Foundation
import EventKit

public final class EventKitService {
    public static let shared = EventKitService()
    
    private let eventStore = EKEventStore()
    
    private init() {}
    
    // MARK: - Permissions
    public func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                print("[EventKitService] Calendar access error: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    public func requestRemindersAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToReminders()
            } catch {
                print("[EventKitService] Reminders access error: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Calendar Events
    public func commitCalendarEvent(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        notes: String? = nil,
        location: String? = nil
    ) async throws -> String {
        let granted = await requestCalendarAccess()
        guard granted else {
            throw NSError(domain: "EventKitService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Calendar permission denied. Please enable in iOS Settings."])
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600)
        event.isAllDay = isAllDay
        event.notes = notes
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier ?? UUID().uuidString
    }
    
    // MARK: - Apple Reminders
    public func commitReminder(
        title: String,
        dueDate: Date? = nil,
        notes: String? = nil,
        priority: Int = 1
    ) async throws -> String {
        let granted = await requestRemindersAccess()
        guard granted else {
            throw NSError(domain: "EventKitService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Reminders permission denied. Please enable in iOS Settings."])
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.priority = priority
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        if let dueDate = dueDate {
            let calendar = Calendar.current
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }
        
        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }
    
    // MARK: - Query Calendar
    public func fetchEvents(startDate: Date, endDate: Date) async -> [EKEvent] {
        let granted = await requestCalendarAccess()
        guard granted else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
}
