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
                // 1. Main Chat Surface (Hamburger button receives all taps unobstructed)
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
                
                // 2. Left Edge Swipe Zone (Starts below top bar so hamburger button is never blocked)
                if !showingSidebar {
                    VStack {
                        Color.clear
                            .frame(height: geometry.safeAreaInsets.top + 50)
                        
                        Color.clear
                            .frame(width: 32)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                                    .onChanged { value in
                                        if value.translation.width > 0 {
                                            isDragging = true
                                            dragOffset = min(sidebarWidth, value.translation.width)
                                        }
                                    }
                                    .onEnded { value in
                                        isDragging = false
                                        if value.translation.width > 40 || value.predictedEndTranslation.width > 100 {
                                            openSidebar()
                                        } else {
                                            closeSidebar()
                                        }
                                    }
                            )
                    }
                }
                
                // 3. Dark Backdrop Scrim
                if showingSidebar || isDragging {
                    let progress = min(1.0, max(0.0, (showingSidebar ? sidebarWidth + dragOffset : dragOffset) / sidebarWidth))
                    Color.black.opacity(Double(progress) * 0.65)
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeSidebar()
                        }
                        .gesture(
                            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                                .onChanged { value in
                                    if value.translation.width < 0 {
                                        isDragging = true
                                        dragOffset = value.translation.width
                                    }
                                }
                                .onEnded { value in
                                    isDragging = false
                                    if value.translation.width < -40 || value.predictedEndTranslation.width < -100 {
                                        closeSidebar()
                                    } else {
                                        openSidebar()
                                    }
                                }
                        )
                }
                
                // 4. Sliding Sidebar Drawer
                sidebarDrawer(geometry: geometry)
                    .frame(width: sidebarWidth)
                    .offset(x: calculatedDrawerOffset)
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: dragOffset)
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: showingSidebar)
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .global)
                            .onChanged { value in
                                if value.translation.width < 0 {
                                    isDragging = true
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                isDragging = false
                                if value.translation.width < -50 || value.predictedEndTranslation.width < -100 {
                                    closeSidebar()
                                } else {
                                    openSidebar()
                                }
                            }
                    )
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
    
    private var calculatedDrawerOffset: CGFloat {
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
        }
    }
    
    private func closeSidebar() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            showingSidebar = false
            dragOffset = 0
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
