//
//  SettingsView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var orchestrator: AgentOrchestrator
    @ObservedObject private var storage = ChatStorage.shared
    
    @State private var apiKeyInput: String = AppConfig.activeDeepSeekAPIKey
    @State private var selectedModel: String = AppConfig.defaultModel
    @State private var showingExportSuccess: Bool = false
    @State private var showingRestoreSuccess: Bool = false
    
    public init(orchestrator: AgentOrchestrator) {
        self.orchestrator = orchestrator
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - 1. DeepSeek API
                Section(header: Text("DeepSeek API Configuration"), footer: Text("You can also set your API key in Secrets.swift.")) {
                    SecureField("Paste DeepSeek API Key", text: $apiKeyInput)
                    
                    Picker("Model", selection: $selectedModel) {
                        Text("DeepSeek Chat (V3)").tag("deepseek-chat")
                        Text("DeepSeek Reasoner (R1)").tag("deepseek-reasoner")
                    }
                    
                    Button("Save API Settings") {
                        AppConfig.activeDeepSeekAPIKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        #if canImport(UIKit)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif
                    }
                    .foregroundColor(.blue)
                }
                
                // MARK: - 2. Email Integration
                Section(header: Text("Student Email Source"), footer: Text("Choose where the agent fetches your emails. If you forwarded your student Outlook to Gmail, choose Gmail.")) {
                    Picker("Email Provider", selection: $orchestrator.currentProvider) {
                        ForEach(AppConfig.EmailProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    
                    if orchestrator.currentProvider == .outlook {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(OutlookService.shared.isAuthenticated ? "Connected ✓" : "Not Authenticated")
                                .foregroundColor(OutlookService.shared.isAuthenticated ? .green : .secondary)
                        }
                        
                        Button("Sign In to Student Outlook (Microsoft 365)") {
                            Task {
                                _ = try? await OutlookService.shared.authenticate()
                            }
                        }
                    } else if orchestrator.currentProvider == .gmail {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(GmailService.shared.isAuthenticated ? "Connected ✓" : "Not Authenticated")
                                .foregroundColor(GmailService.shared.isAuthenticated ? .green : .secondary)
                        }
                        
                        Button("Sign In to Google (Gmail)") {
                            Task {
                                _ = try? await GmailService.shared.authenticate()
                            }
                        }
                    } else {
                        Text("Using sample student inbox (Advisor, I-9, Student Gov, Syllabus).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - 3. Apple Calendar & EventKit
                Section(header: Text("Apple Calendar & Reminders"), footer: Text("The agent requires your explicit confirmation before adding events to Apple Calendar or Reminders.")) {
                    Button("Check / Request Calendar Permission") {
                        Task {
                            _ = await EventKitService.shared.requestCalendarAccess()
                            _ = await EventKitService.shared.requestRemindersAccess()
                        }
                    }
                }
                
                // MARK: - 4. Developer Telemetry & Debug Inspector
                Section(header: Text("Developer Debugging & Telemetry"), footer: Text("View live DeepSeek prompt payloads, raw AI completions, and tool execution logs for debugging.")) {
                    NavigationLink {
                        DebugLogsView()
                    } label: {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.purple)
                            Text("View AI Telemetry & Raw Logs")
                            Spacer()
                            Text("\(DebugLogger.shared.logs.count)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - 5. Memory & Backup (Survives Xcode Expiry)
                Section(
                    header: Text("Data Memory & Backups"),
                    footer: Text("Chat history is automatically saved to the Files app (Documents/StudentAgent_Backups). Even if your Xcode 7-day developer certificate expires, your data is never lost.")
                ) {
                    Button(action: {
                        storage.saveData()
                        showingExportSuccess = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export / Save Full Backup (.json)")
                        }
                    }
                    
                    Button(action: {
                        storage.loadData()
                        showingRestoreSuccess = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reload Chat History from Disk")
                        }
                    }
                    
                    if let url = BackupService.shared.getBackupFileURL() {
                        Text("Backup File: \(url.lastPathComponent)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Backup Exported!", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your chat logs and memory have been exported to the StudentAgent_Backups directory in Files.")
            }
            .alert("Reload Completed", isPresented: $showingRestoreSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Chat history reloaded successfully from local disk storage.")
            }
        }
    }
}
