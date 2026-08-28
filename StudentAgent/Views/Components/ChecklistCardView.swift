//
//  ChecklistCardView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ChecklistCardView: View {
    public let items: [ChecklistItem]
    @ObservedObject private var storage = ChecklistStorage.shared
    
    public init(items: [ChecklistItem]) {
        self.items = items
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .foregroundColor(Color.grokLinkBlue)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("RUNNING CHECKLIST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.grokTextSecondary)
                
                Spacer()
                
                Text("\(storage.activeItems.count) active")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.grokSurface3)
                    .foregroundColor(Color.grokTextSecondary)
                    .clipShape(Capsule())
            }
            
            // Items List
            VStack(spacing: 6) {
                // Active Items
                ForEach(storage.activeItems) { item in
                    ChecklistRowItemView(item: item)
                }
                
                // Completed Section (Past 24 Hours)
                if !storage.completedWithin24Hours.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("COMPLETED (PAST 24H)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.grokTextTertiary)
                            
                            Spacer()
                            
                            Text("\(storage.completedWithin24Hours.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.grokSuccess)
                        }
                        .padding(.top, 4)
                        
                        ForEach(storage.completedWithin24Hours) { item in
                            ChecklistRowItemView(item: item)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.grokSurface1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.grokDivider, lineWidth: 1)
        )
    }
}

public struct ChecklistRowItemView: View {
    public let item: ChecklistItem
    @ObservedObject private var storage = ChecklistStorage.shared
    
    public init(item: ChecklistItem) {
        self.item = item
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Interactive Bullet: Dot -> Checkmark
            Button(action: toggleCheck) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(item.isCompleted ? Color.grokSuccess : Color.grokTextSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            
            // Task Title & Optional Notes
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: item.isCompleted ? .regular : .medium))
                    .foregroundColor(item.isCompleted ? Color.grokTextSecondary : Color.grokTextPrimary)
                    .strikethrough(item.isCompleted, color: Color.grokTextTertiary)
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 11))
                        .foregroundColor(Color.grokTextTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 8)
            
            // Date & Relative Badge Column
            VStack(alignment: .trailing, spacing: 2) {
                if let dueDate = item.dueDate {
                    Text(item.formattedDateNumerical(dueDate))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(item.isCompleted ? Color.grokTextSecondary : Color.grokTextPrimary)
                }
                
                if !item.isCompleted {
                    if let relativeText = item.relativeDueText {
                        Text(relativeText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(item.relativeDueColor)
                    }
                } else if let completedAt = item.completedAt {
                    Text("Done \(item.formattedDateNumerical(completedAt))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.grokSuccess.opacity(0.85))
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleCheck() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            storage.toggleItem(id: item.id)
        }
    }
}
