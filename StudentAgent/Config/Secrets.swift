//
//  Secrets.swift
//  StudentAgent
//
//  Created for Jay Chauhan.
//

import Foundation

public struct AppConfig {
    
    // MARK: - 1. INFERENCE MODEL CONFIGURATION
    public enum ModelProvider: String, CaseIterable, Identifiable {
        case localOllama = "Local Mac Ollama (qwen2.5:14b)"
        case deepseekCloud = "DeepSeek Cloud API"
        
        public var id: String { rawValue }
    }
    
    public static var defaultModelProvider: ModelProvider = .localOllama
    
    public static var activeModelProvider: ModelProvider {
        get {
            if let saved = UserDefaults.standard.string(forKey: "model_provider"),
               let p = ModelProvider(rawValue: saved) {
                return p
            }
            return defaultModelProvider
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "model_provider")
        }
    }
    
    // LOCAL OLLAMA CONFIGURATION (LOCAL FIRST):
    public static let defaultOllamaURL: String = "https://bestsellers-injection-argue-accept.trycloudflare.com"
    public static let defaultOllamaModel: String = "qwen2.5:14b"
    
    public static var activeOllamaURL: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: "ollama_url"), !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return saved
            }
            return defaultOllamaURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ollama_url")
        }
    }
    
    public static var activeOllamaModel: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: "ollama_model"), !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return saved
            }
            return defaultOllamaModel
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ollama_model")
        }
    }
    
    // DEEPSEEK CLOUD CONFIGURATION (OPTIONAL / SECONDARY):
    public static let defaultDeepSeekAPIKey: String = ""
    public static let deepSeekBaseURL: String = "https://api.deepseek.com"
    public static let defaultModel: String = "deepseek-chat"
    
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
    
    // DYNAMIC ENDPOINT RESOLUTION:
    public static var activeBaseURL: String {
        switch activeModelProvider {
        case .localOllama:
            return activeOllamaURL
        case .deepseekCloud:
            return deepSeekBaseURL
        }
    }
    
    public static var activeModel: String {
        switch activeModelProvider {
        case .localOllama:
            return activeOllamaModel
        case .deepseekCloud:
            if let saved = UserDefaults.standard.string(forKey: "deepseek_model"), !saved.isEmpty {
                return saved
            }
            return defaultModel
        }
    }
    
    public static var activeAPIKey: String {
        switch activeModelProvider {
        case .localOllama:
            return "ollama"
        case .deepseekCloud:
            return activeDeepSeekAPIKey
        }
    }
    
    // MARK: - 2. EMAIL INTEGRATION CONFIGURATION
    public enum EmailProvider: String, CaseIterable, Identifiable {
        case outlook = "Student Outlook (Microsoft 365)"
        case gmail = "Gmail (Google OAuth / App Password)"
        case simulated = "Demo / Simulated Inbox (for testing)"
        
        public var id: String { rawValue }
    }
    
    public static let defaultEmailProvider: EmailProvider = .gmail
    
    public static let outlookClientID: String = "YOUR_MICROSOFT_APP_CLIENT_ID"
    public static let outlookTenantID: String = "common"
    public static let outlookRedirectURI: String = "msauth.com.jaychauhan.studentagent://auth"
    
    public static let gmailClientID: String = "673791223308-9t7fq144ts0t0g8mko6m511uf3uq9j5j.apps.googleusercontent.com"
    public static let gmailRedirectURI: String = "com.googleusercontent.apps.673791223308-9t7fq144ts0t0g8mko6m511uf3uq9j5j:/oauth2redirect"
    
    // MARK: - 3. AGENT TIME DEFAULTS
    public static let defaultMorningReminderHour: Int = 9
    public static let defaultAfternoonReminderHour: Int = 14
    public static let defaultEveningReminderHour: Int = 18
    
    // MARK: - 4. TAVILY SEARCH API CONFIGURATION
    public static let defaultTavilyAPIKey: String = "tvly-YOUR_TAVILY_API_KEY"
    
    public static var activeTavilyAPIKey: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: "tavily_api_key"), !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return saved
            }
            return defaultTavilyAPIKey
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tavily_api_key")
        }
    }
}
