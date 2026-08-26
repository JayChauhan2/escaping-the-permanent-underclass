//
//  ContentView.swift
//  StudentAgent
//

import SwiftUI

public struct ContentView: View {
    @StateObject private var orchestrator = AgentOrchestrator()
    @ObservedObject private var storage = ChatStorage.shared
    
    @State private var selectedConversation: ConversationItem?
    @State private var showingSidebar: Bool = false
    @State private var showingSettings: Bool = false
    @State private var searchQuery: String = ""
    
    public init() {}
    
    private var filteredConversations: [ConversationItem] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return storage.conversations
        }
        return storage.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // Main Conversation Surface
            if let convo = selectedConversation ?? storage.conversations.first {
                ChatView(
                    conversation: convo,
                    orchestrator: orchestrator,
                    onOpenSidebar: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingSidebar = true
                        }
                    },
                    onNewChat: createNewChat
                )
            } else {
                Color.grokCanvas.ignoresSafeArea()
            }
            
            // Sliding Sidebar Drawer Overlay
            if showingSidebar {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingSidebar = false
                        }
                    }
                
                sidebarDrawer
                    .transition(.move(edge: .leading))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if selectedConversation == nil {
                selectedConversation = storage.conversations.first ?? storage.createConversation()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(orchestrator: orchestrator)
        }
    }
    
    // Grok History Drawer
    private var sidebarDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Header: App Title & New Chat
            HStack {
                Text("Conversations")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.grokTextPrimary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingSidebar = false
                    }
                    createNewChat()
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.grokTextPrimary)
                        .padding(8)
                        .background(Color.grokSurface2)
                        .clipShape(Circle())
                }
                .buttonStyle(GrokPressableStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Color.grokTextSecondary)
                
                TextField("Search chats...", text: $searchQuery)
                    .font(.system(size: 14))
                    .foregroundColor(Color.grokTextPrimary)
                    .tint(Color.grokLinkBlue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.grokSurface2)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.grokDivider, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            // Conversation List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredConversations) { convo in
                        Button(action: {
                            selectedConversation = convo
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingSidebar = false
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 13))
                                    .foregroundColor(selectedConversation?.id == convo.id ? Color.grokLinkBlue : Color.grokTextSecondary)
                                
                                Text(convo.title)
                                    .font(.system(size: 14, weight: selectedConversation?.id == convo.id ? .bold : .regular))
                                    .foregroundColor(selectedConversation?.id == convo.id ? Color.grokTextPrimary : Color.grokTextSecondary)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selectedConversation?.id == convo.id ? Color.grokSurface2 : Color.clear)
                            .cornerRadius(10)
                        }
                        .buttonStyle(GrokPressableStyle())
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Divider()
                .background(Color.grokDivider)
            
            // Bottom Settings Bar
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingSidebar = false
                }
                showingSettings = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(Color.grokTextPrimary)
                    
                    Text("Settings & Telemetry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.grokTextPrimary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.grokSurface1)
            }
            .buttonStyle(GrokPressableStyle())
        }
        .frame(width: 290)
        .background(Color.grokSurface1)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.grokDivider),
            alignment: .trailing
        )
        .ignoresSafeArea(.all, edges: .vertical)
    }
    
    private func createNewChat() {
        let newConvo = storage.createConversation()
        selectedConversation = newConvo
    }
}
