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
    @State private var isAddingAll = false
    @State private var showingImagePreview = false
    
    public init(message: ChatMessageItem, orchestrator: AgentOrchestrator) {
        self.message = message
        self.orchestrator = orchestrator
    }
    
    public var isUser: Bool { message.role == .user }
    
    private var pendingActions: [CalendarAction] {
        message.proposedActions.filter { $0.status == .proposed }
    }
    
    public var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if isUser {
                // User Bubble: Selectable text + attached image + context menu
                HStack {
                    Spacer(minLength: 48)
                    VStack(alignment: .trailing, spacing: 8) {
                        #if canImport(UIKit)
                        if let img = message.attachmentImage {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 220, maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.grokDivider, lineWidth: 0.5)
                                )
                                .onTapGesture {
                                    showingImagePreview = true
                                }
                        }
                        #endif
                        
                        if !message.content.isEmpty {
                            Text(message.content)
                                .font(.system(size: 15))
                                .foregroundColor(Color.grokTextPrimary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.grokSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.grokDivider, lineWidth: 0.5)
                    )
                    .contextMenu {
                        Button {
                            copyText(message.content)
                        } label: {
                            Label("Copy Message", systemImage: "doc.on.doc")
                        }
                    }
                }
                #if canImport(UIKit)
                .sheet(isPresented: $showingImagePreview) {
                    if let img = message.attachmentImage {
                        NavigationStack {
                            ZStack {
                                Color.black.ignoresSafeArea()
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding()
                            }
                            .navigationTitle("Attached Reference")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        showingImagePreview = false
                                    }
                                    .foregroundColor(Color.grokAccentWhite)
                                }
                            }
                        }
                    }
                }
                #endif
            } else {
                // Assistant Transcript: Full width, selectable typography with live streaming cursor
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
                    
                    // Body text with Grok streaming cursor & textSelection
                    if message.isStreaming {
                        HStack(alignment: .bottom, spacing: 2) {
                            Text(message.content)
                                .font(.system(size: 15))
                                .lineSpacing(4)
                                .foregroundColor(Color.grokTextPrimary)
                                .textSelection(.enabled)
                            
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
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .contextMenu {
                                Button {
                                    copyText(message.content)
                                } label: {
                                    Label("Copy Response", systemImage: "doc.on.doc")
                                }
                            }
                    }
                    
                    // Embedded Email Citations
                    if !message.emailDigests.isEmpty {
                        EmailDigestView(emails: message.emailDigests)
                            .padding(.top, 2)
                    }
                    
                    // Embedded Checklist Preview
                    if !message.checklistItems.isEmpty {
                        ChecklistCardView(items: message.checklistItems)
                            .padding(.top, 2)
                    }
                    
                    // Proposed Action Cards (Calendar & Reminders)
                    if !message.proposedActions.isEmpty {
                        VStack(spacing: 8) {
                            // Bulk "Add All" header button when multiple items exist
                            if pendingActions.count > 1 {
                                Button(action: addAllPendingActions) {
                                    HStack(spacing: 6) {
                                        if isAddingAll {
                                            ProgressView()
                                                .tint(Color.black)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 14, weight: .bold))
                                            Text("Add All (\(pendingActions.count)) to Apple Device")
                                                .font(.system(size: 13, weight: .bold))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.grokAccentWhite)
                                    .foregroundColor(Color.black)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(GrokPressableStyle(scale: 0.96))
                                .disabled(isAddingAll)
                                .padding(.bottom, 2)
                            }
                            
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
    
    private func addAllPendingActions() {
        isAddingAll = true
        Task {
            for action in pendingActions {
                try? await orchestrator.confirmAction(action, message: message)
            }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            isAddingAll = false
        }
    }
    
    private func copyText(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    
    private func copyResponse() {
        copyText(message.content)
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
