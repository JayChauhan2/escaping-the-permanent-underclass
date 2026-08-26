//
//  ActionCardView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ActionCardView: View {
    public let action: CalendarAction
    public let message: ChatMessageItem
    @ObservedObject public var orchestrator: AgentOrchestrator
    
    @State private var isCommitting: Bool = false
    @State private var errorMessage: String?
    
    public init(action: CalendarAction, message: ChatMessageItem, orchestrator: AgentOrchestrator) {
        self.action = action
        self.message = message
        self.orchestrator = orchestrator
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: action.type == .calendarEvent ? "calendar.badge.clock" : "checklist")
                    .foregroundColor(action.type == .calendarEvent ? .blue : .orange)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(action.type == .calendarEvent ? "Proposed Calendar Event" : "Proposed Reminder")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                statusBadge
            }
            
            // Title & Info
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate(action.startDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let notes = action.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                        .lineLimit(3)
                }
            }
            
            // Buttons
            if action.status == .proposed {
                HStack(spacing: 12) {
                    Button(action: {
                        commitAction()
                    }) {
                        HStack(spacing: 6) {
                            if isCommitting {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text(action.type == .calendarEvent ? "Add to Apple Calendar" : "Add to Reminders")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isCommitting)
                }
                .padding(.top, 4)
            }
            
            if let error = errorMessage {
                Text("⚠️ \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(action.status == .confirmed ? Color.green.opacity(0.4) : Color.blue.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch action.status {
        case .proposed:
            Text("Needs Confirmation")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        case .confirmed:
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                Text("Added to Apple \(action.type == .calendarEvent ? "Calendar" : "Reminders")")
            }
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .clipShape(Capsule())
        case .cancelled:
            Text("Dismissed")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.gray)
                .clipShape(Capsule())
        case .failed:
            Text("Failed")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .clipShape(Capsule())
        }
    }
    
    private func commitAction() {
        isCommitting = true
        errorMessage = nil
        
        Task {
            do {
                try await orchestrator.confirmAction(action, message: message)
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            } catch {
                errorMessage = error.localizedDescription
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                #endif
            }
            isCommitting = false
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
