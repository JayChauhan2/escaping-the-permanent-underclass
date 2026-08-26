//
//  DebugLogsView.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct DebugLogsView: View {
    @ObservedObject private var logger = DebugLogger.shared
    @State private var selectedFilter: String = "ALL"
    @State private var showingCopiedAlert: Bool = false
    @State private var showingShareSheet: Bool = false
    
    private let filters = ["ALL", "API", "TOOLS", "ERRORS"]
    
    public init() {}
    
    private var filteredLogs: [DebugLogEntry] {
        switch selectedFilter {
        case "API":
            return logger.logs.filter { $0.type == .apiRequest || $0.type == .apiResponse }
        case "TOOLS":
            return logger.logs.filter { $0.type == .toolCall || $0.type == .eventKit }
        case "ERRORS":
            return logger.logs.filter { $0.type == .error }
        default:
            return logger.logs
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Filter segment
            Picker("Filter", selection: $selectedFilter) {
                ForEach(filters, id: \.self) { f in
                    Text(f).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Logs List
            if filteredLogs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No debug events recorded yet.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredLogs) { entry in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.payload)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    #if canImport(UIKit)
                                    UIPasteboard.general.string = entry.payload
                                    showingCopiedAlert = true
                                    #endif
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Raw Payload")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        } label: {
                            HStack(spacing: 8) {
                                badge(for: entry.type)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    
                                    Text(formattedTime(entry.timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("AI Telemetry & Logs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = logger.exportFormattedText()
                        showingCopiedAlert = true
                        #endif
                    }) {
                        Label("Copy All Telemetry", systemImage: "doc.on.doc")
                    }
                    
                    Button(role: .destructive, action: {
                        logger.clearLogs()
                    }) {
                        Label("Clear Logs", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Copied to Clipboard!", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) {}
        }
    }
    
    @ViewBuilder
    private func badge(for type: DebugEventType) -> some View {
        let (color, text): (Color, String) = {
            switch type {
            case .userPrompt: return (.blue, "USER")
            case .apiRequest: return (.purple, "REQ")
            case .apiResponse: return (.green, "RESP")
            case .toolCall: return (.orange, "TOOL")
            case .eventKit: return (.indigo, "CAL")
            case .error: return (.red, "ERR")
            default: return (.gray, "LOG")
            }
        }()
        
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
