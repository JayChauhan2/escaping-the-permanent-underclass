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
    
    // Active (uncompleted) items preserving user order
    public var activeItems: [ChecklistItem] {
        items.filter { !$0.isCompleted }
    }
    
    public func moveActiveItemUp(id: String) {
        let active = activeItems
        guard let activeIdx = active.firstIndex(where: { $0.id == id }), activeIdx > 0 else { return }
        let prevItem = active[activeIdx - 1]
        
        guard let itemIdx = items.firstIndex(where: { $0.id == id }),
              let prevItemIdx = items.firstIndex(where: { $0.id == prevItem.id }) else { return }
        
        items.swapAt(itemIdx, prevItemIdx)
        saveData()
    }
    
    public func moveActiveItemDown(id: String) {
        let active = activeItems
        guard let activeIdx = active.firstIndex(where: { $0.id == id }), activeIdx < active.count - 1 else { return }
        let nextItem = active[activeIdx + 1]
        
        guard let itemIdx = items.firstIndex(where: { $0.id == id }),
              let nextItemIdx = items.firstIndex(where: { $0.id == nextItem.id }) else { return }
        
        items.swapAt(itemIdx, nextItemIdx)
        saveData()
    }
    
    public func moveActiveItemToTop(id: String) {
        guard let itemIdx = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: itemIdx)
        items.insert(item, at: 0)
        saveData()
    }
    
    public func moveActiveItemToBottom(id: String) {
        guard let itemIdx = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: itemIdx)
        // Find last active item index or end of array
        let uncompletedIndices = items.indices.filter { !items[$0].isCompleted }
        if let lastActive = uncompletedIndices.last {
            items.insert(item, at: lastActive + 1)
        } else {
            items.append(item)
        }
        saveData()
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
