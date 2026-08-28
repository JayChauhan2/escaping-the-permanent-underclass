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
    @ObservedObject private var checklistStorage = ChecklistStorage.shared
    
    public enum SidebarTab: String, CaseIterable {
        case chats = "Chats"
        case checklist = "Checklist"
    }
    
    @Namespace private var sidebarTabNamespace
    @AppStorage("app_mode") private var selectedAppMode: AppMode = .campus
    @State private var selectedConversation: ConversationItem?
    @State private var selectedSidebarTab: SidebarTab = .chats
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
        ZStack(alignment: .leading) {
            // 1. Main Application Surface with Top Mode Switcher
            VStack(spacing: 0) {
                // Top Global Bar: Sidebar Trigger + Segmented Mode Switcher + Action
                HStack(spacing: 8) {
                    Button(action: openSidebar) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color.grokTextPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(GrokPressableStyle())
                    
                    Spacer(minLength: 4)
                    
                    // Native iOS Liquid Glass Sliding Segmented Picker
                    Picker("App Mode", selection: $selectedAppMode) {
                        Label("Campus", systemImage: "graduationcap.fill")
                            .tag(AppMode.campus)
                        Label("AGY Work", systemImage: "terminal.fill")
                            .tag(AppMode.work)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    
                    Spacer(minLength: 4)
                    
                    if selectedAppMode == .campus {
                        Button(action: createNewChat) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color.grokTextPrimary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(GrokPressableStyle())
                    } else {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color.grokTextPrimary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(GrokPressableStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.grokCanvas)
                .overlay(Divider().background(Color.grokDivider), alignment: .bottom)
                
                // Mode Content Views
                if selectedAppMode == .campus {
                    if let convo = selectedConversation ?? storage.conversations.first {
                        ChatView(
                            conversation: convo,
                            orchestrator: orchestrator,
                            onOpenSidebar: openSidebar,
                            onNewChat: createNewChat,
                            showsHeader: false
                        )
                    } else {
                        Color.grokCanvas.ignoresSafeArea()
                    }
                } else {
                    AGYWorkConsoleView()
                }
            }
            
            // 2. Dimming Backdrop
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
            sidebarDrawer
                .frame(width: sidebarWidth)
                .offset(x: currentDrawerOffset)
                .animation(isDragging ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.82), value: dragOffset)
                .animation(isDragging ? nil : .interactiveSpring(response: 0.28, dampingFraction: 0.82), value: showingSidebar)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .onChanged { value in
                    let startX = value.startLocation.x
                    let translationX = value.translation.width
                    let translationY = abs(value.translation.height)
                    
                    guard abs(translationX) > translationY * 1.1 else { return }
                    
                    if !showingSidebar {
                        // Swipe right to open
                        if startX < 240 && translationX > 0 {
                            isDragging = true
                            dragOffset = min(sidebarWidth, translationX)
                        }
                    } else {
                        // Swipe left to close anywhere
                        if translationX < 0 {
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
                        if translationX < -40 || predictedX < -80 {
                            closeSidebar()
                        } else {
                            openSidebar()
                        }
                    } else {
                        if translationX > 40 || predictedX > 80 {
                            openSidebar()
                        } else {
                            closeSidebar()
                        }
                    }
                }
        )
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
    
    // Grok History & Checklist Drawer
    private var sidebarDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Tab Selector: Rectangular Sliding Liquid Glass Switcher (Chats vs Checklist)
            HStack(spacing: 0) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Button(action: {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedSidebarTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .chats ? "bubble.left.and.bubble.right" : "checklist")
                                .font(.system(size: 12, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            
                            if tab == .checklist && checklistStorage.activeItems.count > 0 {
                                Text("\(checklistStorage.activeItems.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.grokLinkBlue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedSidebarTab == tab ? Color.grokTextPrimary : Color.grokTextSecondary)
                    .background {
                        if selectedSidebarTab == tab {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.grokSurface3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                                .matchedGeometryEffect(id: "SIDEBAR_TAB_PILL", in: sidebarTabNamespace)
                        }
                    }
                }
            }
            .padding(3)
            .background(Color.grokSurface2)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            if selectedSidebarTab == .checklist {
                ChecklistSidebarView()
            } else {
                // Header: Title & Top New Chat
                HStack {
                    Text("Conversations")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.grokTextPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        closeSidebar()
                        createNewChat()
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.grokTextPrimary)
                            .padding(7)
                            .background(Color.grokSurface2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(GrokPressableStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                
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
                .padding(.bottom, 10)
                
                // Conversation List
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredConversations) { convo in
                            Button(action: {
                                selectedConversation = convo
                                closeSidebar()
                            }) {
                                HStack {
                                    Text(convo.title)
                                        .font(.system(size: 14, weight: selectedConversation?.id == convo.id ? .bold : .regular))
                                        .foregroundColor(selectedConversation?.id == convo.id ? Color.grokTextPrimary : Color.grokTextSecondary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(selectedConversation?.id == convo.id ? Color.grokSurface2 : Color.clear)
                                .cornerRadius(10)
                            }
                            .buttonStyle(GrokPressableStyle())
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    deleteChat(convo)
                                }) {
                                    Label("Delete Conversation", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            Divider()
                .background(Color.grokDivider)
            
            // Bottom Bar: Settings + Thumb-Friendly New Chat Button
            HStack(spacing: 8) {
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.grokSurface2)
                    .cornerRadius(10)
                }
                .buttonStyle(GrokPressableStyle())
                
                Button(action: {
                    closeSidebar()
                    createNewChat()
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.grokTextPrimary)
                        .padding(10)
                        .background(Color.grokSurface2)
                        .clipShape(Circle())
                }
                .buttonStyle(GrokPressableStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.grokSurface1)
        }
        .background(Color.grokSurface1)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.grokDivider),
            alignment: .trailing
        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    private func createNewChat() {
        let newConvo = storage.createConversation()
        selectedConversation = newConvo
    }
    
    private func deleteChat(_ convo: ConversationItem) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
        withAnimation {
            storage.deleteConversation(id: convo.id)
            if selectedConversation?.id == convo.id {
                selectedConversation = storage.conversations.first
            }
        }
    }
}
