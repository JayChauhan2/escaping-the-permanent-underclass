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
    @ObservedObject public var message: ChatMessageItem
    @ObservedObject public var orchestrator: AgentOrchestrator
    
    @State private var isCommitting: Bool = false
    @State private var currentStatus: CalendarActionStatus
    @State private var errorMessage: String?
    
    public init(action: CalendarAction, message: ChatMessageItem, orchestrator: AgentOrchestrator) {
        self.action = action
        self.message = message
        self.orchestrator = orchestrator
        self._currentStatus = State(initialValue: action.status)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Category Icon + Status Pill
            HStack(spacing: 6) {
                Image(systemName: action.type == .calendarEvent ? "calendar.badge.clock" : "checklist")
                    .foregroundColor(action.type == .calendarEvent ? Color.grokLinkBlue : Color.grokWarning)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(action.type == .calendarEvent ? "CALENDAR EVENT" : "APPLE REMINDER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.grokTextSecondary)
                
                Spacer()
                
                statusBadge
            }
            
            // Title & Info
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.grokTextPrimary)
                
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(Color.grokTextSecondary)
                    
                    Text(formattedDate(action.startDate))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.grokTextSecondary)
                }
                
                if let notes = action.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(Color.grokTextTertiary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            // 1-Tap Action Button (Disappears instantaneously on confirmation)
            if currentStatus == .proposed {
                Button(action: commitAction) {
                    HStack(spacing: 6) {
                        if isCommitting {
                            ProgressView()
                                .tint(Color.black)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                            Text(action.type == .calendarEvent ? "Add to Apple Calendar" : "Add to Apple Reminders")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.grokAccentWhite)
                    .foregroundColor(Color.black)
                    .clipShape(Capsule())
                }
                .buttonStyle(GrokPressableStyle(scale: 0.96))
                .disabled(isCommitting)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale))
            }
            
            if let error = errorMessage {
                Text("⚠️ \(error)")
                    .font(.caption)
                    .foregroundColor(Color.grokError)
            }
        }
        .padding(14)
        .background(Color.grokSurface1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(currentStatus == .confirmed ? Color.grokSuccess.opacity(0.4) : Color.grokDivider, lineWidth: 1)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: currentStatus)
        .onChange(of: action.status) { newStatus in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                currentStatus = newStatus
            }
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch currentStatus {
        case .proposed:
            Text("Pending Confirmation")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.grokLinkBlue.opacity(0.15))
                .foregroundColor(Color.grokLinkBlue)
                .clipShape(Capsule())
        case .confirmed:
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                Text("Scheduled in Apple \(action.type == .calendarEvent ? "Calendar" : "Reminders")")
            }
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.grokSuccess.opacity(0.15))
            .foregroundColor(Color.grokSuccess)
            .clipShape(Capsule())
        case .cancelled:
            Text("Dismissed")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.grokSurface3)
                .foregroundColor(Color.grokTextSecondary)
                .clipShape(Capsule())
        case .failed:
            Text("Failed")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.grokError.opacity(0.15))
                .foregroundColor(Color.grokError)
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
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    currentStatus = .confirmed
                }
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
