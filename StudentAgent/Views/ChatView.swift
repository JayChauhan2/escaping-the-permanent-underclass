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
    #if canImport(UIKit)
    @State private var attachedImage: UIImage? = nil
    #endif
    @State private var isSearchMode: Bool = false
    @State private var showingSettings: Bool = false
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
                
                // Centered Conversation Title & Provider Subtitle
                VStack(spacing: 2) {
                    Text(conversation.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.grokTextPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.grokSuccess)
                            .frame(width: 5, height: 5)
                        Text(orchestrator.currentProvider.rawValue.prefix(16))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.grokTextSecondary)
                    }
                }
                
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
            .padding(.vertical, 8)
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Floating Thinking Pill if Processing
            if let step = orchestrator.currentStep {
                GrokThinkingPill(step: step)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Grok Prompt Bar with Plus Button & Stop Generation & Search Mode
            #if canImport(UIKit)
            GrokPromptBar(
                text: $inputText,
                attachedImage: $attachedImage,
                isSearchMode: $isSearchMode,
                isProcessing: orchestrator.isProcessing,
                onSend: sendMessage,
                onStop: {
                    orchestrator.stopGeneration()
                }
            )
            #else
            GrokPromptBar(
                text: $inputText,
                isSearchMode: $isSearchMode,
                isProcessing: orchestrator.isProcessing,
                onSend: sendMessage,
                onStop: {
                    orchestrator.stopGeneration()
                }
            )
            #endif
        }
        .background(Color.grokCanvas.ignoresSafeArea())
        .sheet(isPresented: $showingSettings) {
            SettingsView(orchestrator: orchestrator)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color.grokAccentWhite.opacity(0.85))
            
            VStack(spacing: 6) {
                Text("Student AI Assistant")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.grokTextPrimary)
                
                Text("Search inbox, sync calendar deadlines, search the web with Tavily, or upload syllabus photos.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.grokTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 10) {
                promptChip(
                    title: "Check Inbox & Schedule Deadlines",
                    detail: "Find professor emails & propose calendar events",
                    prompt: "Check my recent emails from professors or advisors, summarize urgent updates, and propose calendar cards for any homework deadlines."
                )
                
                promptChip(
                    title: "Tavily Live Web Search",
                    detail: "Search campus events, course info & facts",
                    prompt: "Search the web for upcoming university academic deadlines and registration dates."
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
        #if canImport(UIKit)
        let imageToSend = attachedImage
        guard !text.isEmpty || imageToSend != nil else { return }
        #else
        guard !text.isEmpty else { return }
        #endif
        
        let searchActive = isSearchMode
        
        inputText = ""
        #if canImport(UIKit)
        attachedImage = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        isInputFocused = false
        isSearchMode = false
        
        let messageText = text.isEmpty ? "Refer to this attached image." : text
        
        if conversation.title == "New Conversation" {
            let words = messageText.components(separatedBy: " ").prefix(4).joined(separator: " ")
            conversation.title = words.isEmpty ? "Chat" : words
            conversation.updatedAt = Date()
        }
        
        #if canImport(UIKit)
        orchestrator.processUserMessage(
            text: messageText,
            conversationId: conversation.id,
            attachedImage: imageToSend,
            isSearchMode: searchActive
        )
        #else
        orchestrator.processUserMessage(
            text: messageText,
            conversationId: conversation.id,
            isSearchMode: searchActive
        )
        #endif
    }
}
