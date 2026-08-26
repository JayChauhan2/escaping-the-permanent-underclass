//
//  MessageBubbleView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct MessageBubbleView: View {
    @ObservedObject public var message: ChatMessageItem
    @ObservedObject public var orchestrator: AgentOrchestrator
    
    @State private var didCopy = false
    @State private var cursorVisible = true
    
    public init(message: ChatMessageItem, orchestrator: AgentOrchestrator) {
        self.message = message
        self.orchestrator = orchestrator
    }
    
    public var isUser: Bool { message.role == .user }
    
    public var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if isUser {
                // User Bubble: Right-aligned subtle slate container (#1E2126)
                HStack {
                    Spacer(minLength: 48)
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(Color.grokTextPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.grokSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.grokDivider, lineWidth: 0.5)
                        )
                }
            } else {
                // Assistant Transcript: Full width, clean typography with live streaming cursor
                VStack(alignment: .leading, spacing: 10) {
                    // Agent Header Indicator
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.grokLinkBlue)
                        
                        Text("AGENT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.grokTextSecondary)
                        
                        Spacer()
                        
                        if !message.isStreaming {
                            Button(action: copyResponse) {
                                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(didCopy ? Color.grokSuccess : Color.grokTextSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                    
                    // Body text with Grok streaming cursor
                    if message.isStreaming {
                        HStack(alignment: .bottom, spacing: 2) {
                            Text(message.content)
                                .font(.system(size: 15))
                                .lineSpacing(4)
                                .foregroundColor(Color.grokTextPrimary)
                            
                            Text("▍")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.grokLinkBlue)
                                .opacity(cursorVisible ? 1.0 : 0.1)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cursorVisible)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .onAppear {
                            cursorVisible = false
                        }
                    } else {
                        Text(LocalizedStringKey(message.content))
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .foregroundColor(Color.grokTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Embedded Email Citations
                    if !message.emailDigests.isEmpty {
                        EmailDigestView(emails: message.emailDigests)
                            .padding(.top, 2)
                    }
                    
                    // Proposed Action Cards (Calendar & Reminders)
                    if !message.proposedActions.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(message.proposedActions) { action in
                                ActionCardView(action: action, message: message, orchestrator: orchestrator)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
    
    private func copyResponse() {
        #if canImport(UIKit)
        UIPasteboard.general.string = message.content
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                didCopy = false
            }
        }
    }
}
