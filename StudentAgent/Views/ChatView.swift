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
    
    @State private var inputText: String = ""
    @State private var showingSettings: Bool = false
    @FocusState private var isInputFocused: Bool
    
    public init(conversation: ConversationItem, orchestrator: AgentOrchestrator) {
        self.conversation = conversation
        self.orchestrator = orchestrator
    }
    
    private var messages: [ChatMessageItem] {
        storage.getMessages(for: conversation.id)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Messages Scroll Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(messages) { msg in
                                MessageBubbleView(message: msg, orchestrator: orchestrator)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 10)
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
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Live Step Pill (Visual Progress Indicator)
            if let step = orchestrator.currentStep {
                HStack(spacing: 8) {
                    Image(systemName: step.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text(step.text)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(0.7)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(12)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Bottom Input Bar
            HStack(spacing: 10) {
                TextField("Ask your student agent...", text: $inputText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(20)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || orchestrator.isProcessing ? .gray.opacity(0.4) : .blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || orchestrator.isProcessing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
            .overlay(Divider(), alignment: .top)
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Principal: Title + DeepSeek status in top navigation bar next to back button
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(conversation.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text("DeepSeek Active • \(orchestrator.currentProvider.rawValue.prefix(12))...")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(orchestrator: orchestrator)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 20)
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 26))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 4) {
                Text("Student Executive Agent")
                    .font(.headline)
                
                Text("Tap a quick chip below or ask to triage your emails.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Suggestion Chips
            VStack(spacing: 8) {
                promptChip(
                    title: "🔴 Triage Today's Urgent Emails",
                    subtitle: "Advisor links, I-9 form, urgent tasks",
                    prompt: "Check my student emails from the last 24 hours. Summarize high urgency action items, course logistics, and club news in bullet points."
                )
                
                promptChip(
                    title: "📅 Extract Deadlines to Schedule",
                    subtitle: "Proposes Apple Calendar events with confirmation",
                    prompt: "Look through recent emails for upcoming deadlines or advising meetings and propose calendar events."
                )
                
                promptChip(
                    title: "💼 Student Gov Tasks",
                    subtitle: "Filter for website updates & I-9 forms",
                    prompt: "Search my emails for Student Government tasks, website updates, or I-9 paperwork and tell me what actions I need to take."
                )
            }
            .padding(.horizontal, 16)
            
            Spacer(minLength: 20)
        }
    }
    
    private func promptChip(title: String, subtitle: String, prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            sendMessage()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
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
                conversationId: conversation.id
            )
        }
    }
}
