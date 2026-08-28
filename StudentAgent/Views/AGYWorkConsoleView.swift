//
//  AGYWorkConsoleView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct AGYWorkConsoleView: View {
    @ObservedObject private var service = AGYWorkService.shared
    @State private var inputText: String = ""
    @State private var showingSettings: Bool = false
    @FocusState private var isInputFocused: Bool
    
    private let quickCommands = [
        ("git status", "git status"),
        ("git diff", "git diff -U3"),
        ("Build", "build the iOS project and check for errors"),
        ("Tests", "run project tests"),
        ("Files", "list the main source files in the project")
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Console Top Status Bar
            consoleStatusBar
            
            // 2. Quick Command Chips
            quickChipsBar
            
            // 3. Main Terminal Transcript
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if service.messages.isEmpty {
                            emptyTerminalPlaceholder
                        } else {
                            ForEach(service.messages) { message in
                                AGYMessageCardView(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .onChange(of: service.messages.count) { _ in
                    if let last = service.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: service.currentStreamingText) { _ in
                    if let last = service.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
                .background(Color.grokDivider)
            
            // 4. Bottom Command Bar
            bottomCommandBar
        }
        .background(Color(red: 10/255, green: 11/255, blue: 13/255))
        .onAppear {
            Task {
                await service.checkHealth()
            }
        }
    }
    
    // Top Status Header
    private var consoleStatusBar: some View {
        HStack(spacing: 8) {
            // Status Dot
            Circle()
                .fill(service.isConnected ? Color.grokSuccess : Color.grokError)
                .frame(width: 8, height: 8)
            
            Text(service.isConnected ? "AGY REMOTE (CONNECTED)" : "AGY OFFLINE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(service.isConnected ? Color.grokSuccess : Color.grokError)
            
            Spacer()
            
            if !service.serverWorkspace.isEmpty {
                Text(service.serverWorkspace.components(separatedBy: "/").last ?? "StudentAgent")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.grokSurface2)
                    .foregroundColor(Color.grokTextSecondary)
                    .cornerRadius(4)
            }
            
            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                service.clearHistory()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(Color.grokTextTertiary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(red: 16/255, green: 18/255, blue: 22/255))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.grokDivider),
            alignment: .bottom
        )
    }
    
    // Quick Command Pills
    private var quickChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(quickCommands, id: \.0) { item in
                    Button(action: {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        service.sendPrompt(item.1)
                    }) {
                        HStack(spacing: 4) {
                            Text("❯")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.grokLinkBlue)
                            Text(item.0)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.grokTextPrimary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.grokSurface2)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.grokDivider, lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isRunning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(red: 12/255, green: 14/255, blue: 17/255))
    }
    
    // Empty state
    private var emptyTerminalPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 38))
                .foregroundColor(Color.grokLinkBlue.opacity(0.8))
            
            Text("Antigravity CLI Remote Studio")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(Color.grokTextPrimary)
            
            Text("Send tasks directly to your Mac Antigravity agent.\nExecutes file edits, git commands, builds, and full subagent pipelines.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.grokTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // Bottom command input bar
    private var bottomCommandBar: some View {
        VStack(spacing: 8) {
            if service.isRunning {
                Button(action: {
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    #endif
                    service.abortTask()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Abort AGY Execution")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.grokError.opacity(0.2))
                    .foregroundColor(Color.grokError)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.grokError.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }
            
            HStack(spacing: 8) {
                Text("❯")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.grokSuccess)
                
                TextField("Ask Antigravity to do anything...", text: $inputText)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color.grokTextPrimary)
                    .tint(Color.grokLinkBlue)
                    .focused($isInputFocused)
                    .disabled(service.isRunning)
                    .onSubmit(submitCommand)
                
                Button(action: submitCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isRunning ? Color.grokTextSecondary : Color.grokAccentWhite)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isRunning)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.grokSurface2)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.grokDivider, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(Color(red: 14/255, green: 16/255, blue: 19/255))
    }
    
    private func submitCommand() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !service.isRunning else { return }
        
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        
        inputText = ""
        isInputFocused = false
        service.sendPrompt(trimmed)
    }
}

public struct AGYMessageCardView: View {
    public let message: AGYMessage
    @State private var cursorVisible = true
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // User Prompt Banner
            HStack(alignment: .top, spacing: 6) {
                Text("❯")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.grokSuccess)
                
                Text(message.prompt)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.white)
                    .textSelection(.enabled)
                
                Spacer()
                
                if message.isRunning {
                    ProgressView()
                        .tint(Color.grokLinkBlue)
                        .scaleEffect(0.7)
                }
            }
            .padding(10)
            .background(Color(red: 22/255, green: 26/255, blue: 32/255))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.grokDivider, lineWidth: 0.8)
            )
            
            // Tool Execution Steps
            if !message.steps.isEmpty {
                VStack(spacing: 6) {
                    ForEach(message.steps) { step in
                        AGYStepRowView(step: step)
                    }
                }
            }
            
            // Final Output / Stream Content
            if !message.finalResponse.isEmpty || message.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11))
                            .foregroundColor(Color.grokLinkBlue)
                        Text("ANTIGRAVITY OUTPUT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.grokTextSecondary)
                    }
                    
                    Text(LocalizedStringKey(message.finalResponse))
                        .font(.system(size: 13, design: .monospaced))
                        .lineSpacing(3)
                        .foregroundColor(Color.grokTextPrimary)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(Color.grokSurface1)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.grokDivider, lineWidth: 0.8)
                )
            }
            
            // Footer usage info
            if let tokens = message.usageTokens {
                HStack {
                    Spacer()
                    Text("\(tokens) tokens used")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.grokTextTertiary)
                }
            }
        }
    }
}

public struct AGYStepRowView: View {
    public let step: AGYStep
    @State private var isExpanded: Bool = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: step.state == .done ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(step.state == .done ? Color.grokSuccess : Color.grokLinkBlue)
                    
                    Text(step.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.grokTextPrimary)
                    
                    Spacer()
                    
                    if let dur = step.durationSeconds {
                        Text(String(format: "%.1fs", dur))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.grokTextTertiary)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Color.grokTextTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.grokSurface2)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            if isExpanded && !step.content.isEmpty {
                Text(step.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.grokTextSecondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                    .textSelection(.enabled)
            }
        }
    }
}
