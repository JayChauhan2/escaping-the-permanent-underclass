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
                Section(header: Text("DEEPSEEK API CONFIGURATION").foregroundColor(Color.grokTextSecondary)) {
                    SecureField("Paste DeepSeek API Key", text: $apiKeyInput)
                        .foregroundColor(Color.grokTextPrimary)
                    
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
                    .foregroundColor(Color.grokLinkBlue)
                }
                
                // MARK: - 2. Email Integration
                Section(header: Text("STUDENT EMAIL SOURCE").foregroundColor(Color.grokTextSecondary)) {
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
                                .foregroundColor(OutlookService.shared.isAuthenticated ? Color.grokSuccess : Color.grokTextSecondary)
                        }
                        
                        Button("Sign In to Student Outlook (Microsoft 365)") {
                            Task {
                                _ = try? await OutlookService.shared.authenticate()
                            }
                        }
                        .foregroundColor(Color.grokLinkBlue)
                    } else if orchestrator.currentProvider == .gmail {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(GmailService.shared.isAuthenticated ? "Connected ✓" : "Not Authenticated")
                                .foregroundColor(GmailService.shared.isAuthenticated ? Color.grokSuccess : Color.grokTextSecondary)
                        }
                        
                        Button("Sign In to Google (Gmail)") {
                            Task {
                                _ = try? await GmailService.shared.authenticate()
                            }
                        }
                        .foregroundColor(Color.grokLinkBlue)
                    } else {
                        Text("Using sample student inbox (Advisor, I-9, Student Gov, Syllabus).")
                            .font(.caption)
                            .foregroundColor(Color.grokTextSecondary)
                    }
                }
                
                // MARK: - 3. Apple Calendar & EventKit
                Section(header: Text("APPLE CALENDAR & REMINDERS").foregroundColor(Color.grokTextSecondary)) {
                    Button("Check / Request Calendar Permission") {
                        Task {
                            _ = await EventKitService.shared.requestCalendarAccess()
                            _ = await EventKitService.shared.requestRemindersAccess()
                        }
                    }
                    .foregroundColor(Color.grokLinkBlue)
                }
                
                // MARK: - 4. Developer Telemetry & Debug Inspector
                Section(header: Text("DEVELOPER DEBUGGING & TELEMETRY").foregroundColor(Color.grokTextSecondary)) {
                    NavigationLink {
                        DebugLogsView()
                    } label: {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(Color.grokLinkBlue)
                            Text("View AI Telemetry & Raw Logs")
                            Spacer()
                            Text("\(DebugLogger.shared.logs.count)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.grokTextSecondary)
                        }
                    }
                }
                
                // MARK: - 5. Memory & Backup (Survives Xcode Expiry)
                Section(header: Text("DATA MEMORY & BACKUPS").foregroundColor(Color.grokTextSecondary)) {
                    Button(action: {
                        storage.saveData()
                        showingExportSuccess = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export / Save Full Backup (.json)")
                        }
                    }
                    .foregroundColor(Color.grokLinkBlue)
                    
                    Button(action: {
                        storage.loadData()
                        showingRestoreSuccess = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reload Chat History from Disk")
                        }
                    }
                    .foregroundColor(Color.grokLinkBlue)
                    
                    if let url = BackupService.shared.getBackupFileURL() {
                        Text("Backup File: \(url.lastPathComponent)")
                            .font(.caption2)
                            .foregroundColor(Color.grokTextSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.grokCanvas.ignoresSafeArea())
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.grokAccentWhite)
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
        .preferredColorScheme(.dark)
    }
}
