//
//  Secrets.swift
//  StudentAgent
//
//  Created for Jay Chauhan.
//

import Foundation

public struct AppConfig {
    
    // MARK: - 1. DEEPSEEK API CONFIGURATION
    // =========================================================================
    // 👉 DEEPSEEK API KEY:
    public static let defaultDeepSeekAPIKey: String = "sk-d48da34340ce4ba7a80c5f557733db62"
    // =========================================================================
    
    public static let deepSeekBaseURL: String = "https://api.deepseek.com"
    public static let defaultModel: String = "deepseek-chat" // or "deepseek-reasoner"
    
    // MARK: - 2. EMAIL INTEGRATION CONFIGURATION
    public enum EmailProvider: String, CaseIterable, Identifiable {
        case outlook = "Student Outlook (Microsoft 365)"
        case gmail = "Gmail (Google OAuth / App Password)"
        case simulated = "Demo / Simulated Inbox (for testing)"
        
        public var id: String { rawValue }
    }
    
    // Default email provider to use
    public static let defaultEmailProvider: EmailProvider = .gmail
    
    // MICROSOFT GRAPH (STUDENT OUTLOOK):
    public static let outlookClientID: String = "YOUR_MICROSOFT_APP_CLIENT_ID"
    public static let outlookTenantID: String = "common"
    public static let outlookRedirectURI: String = "msauth.com.jaychauhan.studentagent://auth"
    
    // GMAIL CONFIGURATION:
    public static let gmailClientID: String = "673791223308-9t7fq144ts0t0g8mko6m511uf3uq9j5j.apps.googleusercontent.com"
    public static let gmailRedirectURI: String = "com.googleusercontent.apps.673791223308-9t7fq144ts0t0g8mko6m511uf3uq9j5j:/oauth2redirect"
    
    // MARK: - 3. AGENT TIME DEFAULTS
    public static let defaultMorningReminderHour: Int = 9   // 9:00 AM
    public static let defaultAfternoonReminderHour: Int = 14 // 2:00 PM
    public static let defaultEveningReminderHour: Int = 18   // 6:00 PM
    
    // Dynamic access allowing in-app override from Settings
    public static var activeDeepSeekAPIKey: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: "deepseek_api_key"), !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return saved
            }
            return defaultDeepSeekAPIKey
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "deepseek_api_key")
        }
    }
}
