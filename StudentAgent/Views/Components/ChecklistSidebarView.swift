//
//  ChecklistSidebarView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ChecklistSidebarView: View {
    @ObservedObject private var storage = ChecklistStorage.shared
    
    @State private var newTaskTitle: String = ""
    @State private var selectedDueDate: Date = Date()
    @State private var includeDueDate: Bool = false
    @State private var showingDatePicker: Bool = false
    @FocusState private var isFieldFocused: Bool
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Checklist")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.grokTextPrimary)
                
                Spacer()
                
                Text("\(storage.activeItems.count) pending")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.grokSurface2)
                    .foregroundColor(Color.grokLinkBlue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            // Quick Add Input Bar
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Add a new task...", text: $newTaskTitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color.grokTextPrimary)
                        .tint(Color.grokLinkBlue)
                        .focused($isFieldFocused)
                        .onSubmit(addNewTask)
                    
                    Button(action: {
                        withAnimation {
                            includeDueDate.toggle()
                        }
                    }) {
                        Image(systemName: includeDueDate ? "calendar.badge.clock" : "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(includeDueDate ? Color.grokLinkBlue : Color.grokTextSecondary)
                            .padding(6)
                            .background(Color.grokSurface3)
                            .clipShape(Circle())
                    }
                    
                    Button(action: addNewTask) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.black)
                            .padding(6)
                            .background(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.grokTextSecondary : Color.grokAccentWhite)
                            .clipShape(Circle())
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.grokSurface2)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.grokDivider, lineWidth: 1)
                )
                
                // Optional Date Selector Expander
                if includeDueDate {
                    DatePicker("Due Date:", selection: $selectedDueDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.grokSurface2.opacity(0.6))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Tasks Scroll Area
            ScrollView {
                LazyVStack(spacing: 6) {
                    if storage.items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checklist.checked")
                                .font(.system(size: 32))
                                .foregroundColor(Color.grokTextTertiary)
                            Text("All caught up!")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.grokTextSecondary)
                            Text("Ask agent to add tasks or type above.")
                                .font(.system(size: 12))
                                .foregroundColor(Color.grokTextTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        // 1. Active Section
                        if !storage.activeItems.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ACTIVE TASKS")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.grokTextTertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 2)
                                
                                ForEach(storage.activeItems) { item in
                                    ChecklistRowItemView(item: item)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.grokSurface2.opacity(0.5))
                                        .cornerRadius(8)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteTask(item)
                                            } label: {
                                                Label("Delete Task", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        
                        // 2. Completed Section (Past 24H)
                        if !storage.completedWithin24Hours.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("COMPLETED (PAST 24H)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.grokTextTertiary)
                                    
                                    Spacer()
                                    
                                    Text("\(storage.completedWithin24Hours.count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.grokSuccess)
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 6)
                                .padding(.bottom, 2)
                                
                                ForEach(storage.completedWithin24Hours) { item in
                                    ChecklistRowItemView(item: item)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.grokSurface2.opacity(0.25))
                                        .cornerRadius(8)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteTask(item)
                                            } label: {
                                                Label("Delete Task", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .background(Color.grokSurface1)
    }
    
    private func addNewTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let due: Date? = includeDueDate ? selectedDueDate : nil
        storage.addItem(title: trimmed, dueDate: due)
        
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        
        newTaskTitle = ""
        includeDueDate = false
        isFieldFocused = false
    }
    
    private func deleteTask(_ item: ChecklistItem) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
        withAnimation {
            storage.deleteItem(id: item.id)
        }
    }
}
