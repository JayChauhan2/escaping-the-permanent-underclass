//
//  ChatView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ChatView: View {
    public let conversation: ConversationItem
    @ObservedObject public var orchestrator: AgentOrchestrator
    @ObservedObject private var storage = ChatStorage.shared
    
    public var onOpenSidebar: () -> Void
    public var onNewChat: () -> Void
    
    @State private var inputText: String = ""
    @State private var showingSettings: Bool = false
    @State private var activeMode: AgentMode = .executive
    @FocusState private var isInputFocused: Bool
    
    public init(
        conversation: ConversationItem,
        orchestrator: AgentOrchestrator,
        onOpenSidebar: @escaping () -> Void = {},
        onNewChat: @escaping () -> Void = {}
    ) {
        self.conversation = conversation
        self.orchestrator = orchestrator
        self.onOpenSidebar = onOpenSidebar
        self.onNewChat = onNewChat
    }
    
    private var messages: [ChatMessageItem] {
        storage.getMessages(for: conversation.id)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Grok Top Bar
            HStack(spacing: 12) {
                Button(action: onOpenSidebar) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.grokTextPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(GrokPressableStyle())
                
                Spacer()
                
                // Grok Center Mode Capsule
                modeTogglePill
                
                Spacer()
                
                Button(action: onNewChat) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.grokTextPrimary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(GrokPressableStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.grokCanvas)
            .overlay(Divider().background(Color.grokDivider), alignment: .bottom)
            
            // Messages Scroll Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if messages.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(messages) { msg in
                                MessageBubbleView(message: msg, orchestrator: orchestrator)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
                .contentShape(Rectangle())
                .onTapGesture {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                    isInputFocused = false
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Live Thinking / Step Progress Pill
            if let step = orchestrator.currentStep {
                GrokThinkingPill(step: step)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Grok Prompt Bar
            GrokPromptBar(
                text: $inputText,
                isProcessing: orchestrator.isProcessing,
                onSend: sendMessage
            )
        }
        .background(Color.grokCanvas.ignoresSafeArea())
        .sheet(isPresented: $showingSettings) {
            SettingsView(orchestrator: orchestrator)
        }
    }
    
    // Grok Mode Toggle Pill
    private var modeTogglePill: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    activeMode = .executive
                }
            }) {
                Text("Executive")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(activeMode == .executive ? Color.black : Color.grokTextSecondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(activeMode == .executive ? Color.grokAccentWhite : Color.clear)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    activeMode = .triage
                }
            }) {
                Text("Triage")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(activeMode == .triage ? Color.grokLinkBlue : Color.grokTextSecondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(activeMode == .triage ? Color.grokSurface1 : Color.clear)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background(Color.grokSurface1)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(Color.grokDivider, lineWidth: 1)
        )
    }
    
    // Minimalist Grok-style empty canvas
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            
            // Grok Monogram / Logo
            ZStack {
                Circle()
                    .fill(Color.grokSurface1)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().strokeBorder(Color.grokDivider, lineWidth: 1))
                
                Image(systemName: "graduationcap")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.grokTextPrimary)
            }
            
            VStack(spacing: 4) {
                Text("Student Agent")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.grokTextPrimary)
                
                Text("\(activeMode.rawValue) Mode • \(orchestrator.currentProvider.rawValue)")
                    .font(.system(size: 13))
                    .foregroundColor(Color.grokTextSecondary)
            }
            
            // Suggestion Chips
            VStack(spacing: 8) {
                promptChip(
                    title: "Triage Today's Urgent Emails",
                    detail: "Find advisor links, I-9 form, deadlines",
                    prompt: "Check my student emails from the last 24 hours. Summarize high urgency action items, course logistics, and club news in bullet points."
                )
                
                promptChip(
                    title: "Extract Deadlines to Apple Calendar",
                    detail: "Drafts calendar events with 1-tap confirmation",
                    prompt: "Look through recent emails for upcoming deadlines or advising meetings and propose calendar events."
                )
                
                promptChip(
                    title: "Student Government Tasks",
                    detail: "Website fixes, payroll forms, outreach",
                    prompt: "Search my emails for Student Government tasks, website updates, or I-9 paperwork and tell me what actions I need to take."
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Spacer(minLength: 40)
        }
    }
    
    private func promptChip(title: String, detail: String, prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            sendMessage()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.grokTextPrimary)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(Color.grokTextSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.grokTextSecondary)
            }
            .padding(12)
            .background(Color.grokSurface1)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.grokDivider, lineWidth: 1)
            )
        }
        .buttonStyle(GrokPressableStyle())
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        isInputFocused = false
        
        if conversation.title == "New Conversation" {
            let words = text.components(separatedBy: " ").prefix(4).joined(separator: " ")
            conversation.title = words.isEmpty ? "Chat" : words
            conversation.updatedAt = Date()
        }
        
        Task {
            await orchestrator.processUserMessage(
                text: text,
                conversationId: conversation.id,
                mode: activeMode
            )
        }
    }
}
