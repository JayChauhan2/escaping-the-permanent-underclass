//
//  ChecklistStorage.swift
//  StudentAgent
//

import Foundation
import SwiftUI

@MainActor
public final class ChecklistStorage: ObservableObject {
    public static let shared = ChecklistStorage()
    
    @Published public var items: [ChecklistItem] = []
    
    private var dataDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("StudentAgent_Data", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var checklistFileURL: URL {
        dataDirectory.appendingPathComponent("checklist.json")
    }
    
    public init() {
        loadData()
    }
    
    // Active (uncompleted) items sorted by due date
    public var activeItems: [ChecklistItem] {
        items.filter { !$0.isCompleted }
            .sorted { (a, b) -> Bool in
                if let da = a.dueDate, let db = b.dueDate {
                    return da < db
                } else if a.dueDate != nil {
                    return true
                } else if b.dueDate != nil {
                    return false
                }
                return a.createdAt > b.createdAt
            }
    }
    
    // Completed items within past 24 hours
    public var completedWithin24Hours: [ChecklistItem] {
        items.filter { $0.isWithin24HoursOfCompletion }
            .sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
    }
    
    @discardableResult
    public func addItem(title: String, dueDate: Date? = nil, notes: String? = nil) -> ChecklistItem {
        let newItem = ChecklistItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes, dueDate: dueDate)
        items.insert(newItem, at: 0)
        saveData()
        return newItem
    }
    
    public func toggleItem(id: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isCompleted.toggle()
        if items[idx].isCompleted {
            items[idx].completedAt = Date()
        } else {
            items[idx].completedAt = nil
        }
        saveData()
    }
    
    public func updateItem(_ item: ChecklistItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        saveData()
    }
    
    public func deleteItem(id: String) {
        items.removeAll(where: { $0.id == id })
        saveData()
    }
    
    public func cleanupOldCompletedItems() {
        // Prune completed items older than 24 hours to keep storage lean
        items.removeAll(where: { $0.isCompleted && !$0.isWithin24HoursOfCompletion })
        saveData()
    }
    
    public func saveData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(items) {
            try? data.write(to: checklistFileURL, options: .atomic)
        }
    }
    
    public func loadData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = try? Data(contentsOf: checklistFileURL),
           let loaded = try? decoder.decode([ChecklistItem].self, from: data) {
            self.items = loaded
        }
    }
}
