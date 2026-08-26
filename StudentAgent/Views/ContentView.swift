//
//  ContentView.swift
//  StudentAgent
//

import SwiftUI

public struct ContentView: View {
    @ObservedObject private var storage = ChatStorage.shared
    @StateObject private var orchestrator = AgentOrchestrator()
    @State private var selectedConversation: ConversationItem?
    @State private var showingSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar: Conversations List
            List(selection: $selectedConversation) {
                Section(header: Text("Conversations")) {
                    ForEach(storage.conversations) { conv in
                        NavigationLink(value: conv) {
                            HStack {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conv.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    
                                    Text(formattedDate(conv.updatedAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteConversations)
                }
            }
            .navigationTitle("Student Agent")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewConversation) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        } detail: {
            if let selected = selectedConversation {
                ChatView(conversation: selected, orchestrator: orchestrator)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    Text("Select or create a conversation to start.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("Start New Chat", action: createNewConversation)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                }
            }
        }
        .onAppear {
            if storage.conversations.isEmpty {
                createNewConversation()
            } else if selectedConversation == nil {
                selectedConversation = storage.conversations.first
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(orchestrator: orchestrator)
        }
    }
    
    private func createNewConversation() {
        let newConv = storage.createConversation(title: "New Conversation")
        selectedConversation = newConv
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conv = storage.conversations[index]
            storage.deleteConversation(conv)
        }
        if selectedConversation == nil || !storage.conversations.contains(where: { $0.id == selectedConversation?.id }) {
            selectedConversation = storage.conversations.first
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
