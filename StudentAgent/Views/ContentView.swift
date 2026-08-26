//
//  ContentView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ContentView: View {
    @StateObject private var orchestrator = AgentOrchestrator()
    @ObservedObject private var storage = ChatStorage.shared
    
    @State private var selectedConversation: ConversationItem?
    @State private var showingSidebar: Bool = false
    @State private var showingSettings: Bool = false
    @State private var searchQuery: String = ""
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    private let sidebarWidth: CGFloat = 300
    
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
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 1. Main Chat Surface (Full native interaction, buttons always work)
                if let convo = selectedConversation ?? storage.conversations.first {
                    ChatView(
                        conversation: convo,
                        orchestrator: orchestrator,
                        onOpenSidebar: {
                            openSidebar()
                        },
                        onNewChat: createNewChat
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Color.grokCanvas.ignoresSafeArea()
                }
                
                // 2. Dimming Backdrop when Drawer is open or being dragged open
                if showingSidebar || isDragging {
                    let progress: CGFloat = showingSidebar
                        ? min(1.0, max(0.0, (sidebarWidth + dragOffset) / sidebarWidth))
                        : min(1.0, max(0.0, dragOffset / sidebarWidth))
                    
                    Color.black.opacity(Double(progress) * 0.65)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeSidebar()
                        }
                }
                
                // 3. Sliding Sidebar Drawer
                sidebarDrawer(geometry: geometry)
                    .frame(width: sidebarWidth)
                    .offset(x: currentDrawerOffset)
                    .animation(isDragging ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.82), value: dragOffset)
                    .animation(isDragging ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.82), value: showingSidebar)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .onChanged { value in
                        let startX = value.startLocation.x
                        let translationX = value.translation.width
                        let translationY = abs(value.translation.height)
                        
                        // Prioritize horizontal gestures over vertical scrolling
                        if !showingSidebar {
                            // Swipe from left edge (wide 70pt zone across full screen height)
                            if startX < 70 && translationX > 0 && translationX > translationY {
                                isDragging = true
                                dragOffset = min(sidebarWidth, translationX)
                            }
                        } else {
                            // Dragging left to close when open
                            if translationX < 0 && abs(translationX) > translationY {
                                isDragging = true
                                dragOffset = translationX
                            }
                        }
                    }
                    .onEnded { value in
                        guard isDragging else { return }
                        isDragging = false
                        
                        let translationX = value.translation.width
                        let predictedX = value.predictedEndTranslation.width
                        
                        if showingSidebar {
                            if translationX < -50 || predictedX < -100 {
                                closeSidebar()
                            } else {
                                openSidebar()
                            }
                        } else {
                            if translationX > 50 || predictedX > 100 {
                                openSidebar()
                            } else {
                                closeSidebar()
                            }
                        }
                    }
            )
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
    
    private var currentDrawerOffset: CGFloat {
        if showingSidebar {
            return min(0, dragOffset)
        } else {
            return -sidebarWidth + max(0, dragOffset)
        }
    }
    
    private func openSidebar() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showingSidebar = true
            dragOffset = 0
            isDragging = false
        }
    }
    
    private func closeSidebar() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showingSidebar = false
            dragOffset = 0
            isDragging = false
        }
    }
    
    // Grok History Drawer
    private func sidebarDrawer(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: geometry.safeAreaInsets.top)
            
            // Header: Title & New Chat
            HStack {
                Text("Conversations")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.grokTextPrimary)
                
                Spacer()
                
                Button(action: {
                    closeSidebar()
                    createNewChat()
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.grokTextPrimary)
                        .padding(8)
                        .background(Color.grokSurface2)
                        .clipShape(Circle())
                }
                .buttonStyle(GrokPressableStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Search Box
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
                            closeSidebar()
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
                closeSidebar()
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
            
            Color.clear.frame(height: geometry.safeAreaInsets.bottom)
        }
        .background(Color.grokSurface1)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.grokDivider),
            alignment: .trailing
        )
        .ignoresSafeArea()
    }
    
    private func createNewChat() {
        let newConvo = storage.createConversation()
        selectedConversation = newConvo
    }
}
