//
//  MessageBubbleView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct MessageBubbleView: View {
    public let message: ChatMessageItem
    @ObservedObject public var orchestrator: AgentOrchestrator
    
    public init(message: ChatMessageItem, orchestrator: AgentOrchestrator) {
        self.message = message
        self.orchestrator = orchestrator
    }
    
    public var isUser: Bool { message.role == .user }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                // Agent Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                // Message Body
                Text(LocalizedStringKey(message.content))
                    .font(.body)
                    .foregroundColor(isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? Color.blue
                            : {
                                #if canImport(UIKit)
                                return Color(UIColor.secondarySystemGroupedBackground)
                                #else
                                return Color.gray.opacity(0.12)
                                #endif
                            }()
                    )
                    .cornerRadius(18)
                
                // Embedded Email Digest if present
                if !message.emailDigests.isEmpty && !isUser {
                    EmailDigestView(emails: message.emailDigests)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Proposed Calendar Actions if present
                if !message.proposedActions.isEmpty && !isUser {
                    VStack(spacing: 8) {
                        ForEach(message.proposedActions) { action in
                            ActionCardView(action: action, message: message, orchestrator: orchestrator)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Timestamp
                Text(formattedTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
