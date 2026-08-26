//
//  OutlookService.swift
//  StudentAgent
//

import Foundation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public final class OutlookService: NSObject, EmailServiceProtocol, ASWebAuthenticationPresentationContextProviding {
    public static let shared = OutlookService()
    
    public var providerName: String { "Student Outlook (Microsoft 365)" }
    
    private let tokenKey = "outlook_access_token"
    
    public var isAuthenticated: Bool {
        guard let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty else {
            return false
        }
        return true
    }
    
    public var accessToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }
    
    public func authenticate() async throws -> Bool {
        let clientID = AppConfig.outlookClientID
        let tenantID = AppConfig.outlookTenantID
        let redirectURI = AppConfig.outlookRedirectURI
        let scopes = "Mail.Read Calendars.ReadWrite offline_access User.Read"
        
        guard !clientID.contains("YOUR_MICROSOFT_APP_CLIENT_ID") else {
            throw NSError(domain: "OutlookService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Outlook Client ID is not configured."])
        }
        
        guard let authURL = URL(string: "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/authorize?client_id=\(clientID)&response_type=token&redirect_uri=\(redirectURI)&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw NSError(domain: "OutlookService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OAuth URL."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "msauth.com.jaychauhan.studentagent") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let fragment = callbackURL.fragment else {
                    continuation.resume(returning: false)
                    return
                }
                
                // Parse access_token from URL fragment
                let params = fragment.components(separatedBy: "&").reduce(into: [String: String]()) { dict, pair in
                    let parts = pair.components(separatedBy: "=")
                    if parts.count == 2 {
                        dict[parts[0]] = parts[1]
                    }
                }
                
                if let token = params["access_token"] {
                    UserDefaults.standard.set(token, forKey: self.tokenKey)
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
    }
    
    public func signOut() async throws {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
    
    public func fetchRecentEmails(hoursBack: Int = 48, maxCount: Int = 20) async throws -> [EmailItem] {
        guard let token = accessToken else {
            throw NSError(domain: "OutlookService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in to Outlook. Please sign in via Settings."])
        }
        
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$top=\(maxCount)&$select=id,subject,bodyPreview,body,from,receivedDateTime,isRead&$orderby=receivedDateTime%20desc")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OutlookService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch messages from Microsoft Graph."])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["value"] as? [[String: Any]] else {
            return []
        }
        
        var results: [EmailItem] = []
        for val in values {
            if let item = parseGraphMessage(val) {
                results.append(item)
            }
        }
        return results
    }
    
    public func searchEmails(query: String, maxCount: Int = 15) async throws -> [EmailItem] {
        guard let token = accessToken else {
            throw NSError(domain: "OutlookService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in to Outlook."])
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$search=\"\(encodedQuery)\"&$top=\(maxCount)&$select=id,subject,bodyPreview,body,from,receivedDateTime,isRead")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["value"] as? [[String: Any]] else {
            return []
        }
        
        var results: [EmailItem] = []
        for val in values {
            if let item = parseGraphMessage(val) {
                results.append(item)
            }
        }
        return results
    }
    
    public func getEmailDetails(id: String) async throws -> EmailItem? {
        guard let token = accessToken else { return nil }
        
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages/\(id)?$select=id,subject,bodyPreview,body,from,receivedDateTime,isRead")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return parseGraphMessage(dict)
    }
    
    private func parseGraphMessage(_ dict: [String: Any]) -> EmailItem? {
        guard let id = dict["id"] as? String else { return nil }
        let subject = dict["subject"] as? String ?? "(No Subject)"
        let bodyPreview = dict["bodyPreview"] as? String ?? ""
        let bodyDict = dict["body"] as? [String: Any]
        let fullBody = bodyDict?["content"] as? String ?? bodyPreview
        let isRead = dict["isRead"] as? Bool ?? false
        
        var senderName = "Unknown"
        var senderEmail = "unknown@university.edu"
        if let fromDict = dict["from"] as? [String: Any],
           let emailAddress = fromDict["emailAddress"] as? [String: Any] {
            senderName = emailAddress["name"] as? String ?? "Unknown"
            senderEmail = emailAddress["address"] as? String ?? "unknown@university.edu"
        }
        
        let dateStr = dict["receivedDateTime"] as? String ?? ""
        let date = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        
        let urgency = Self.classifyEmail(subject: subject, sender: senderName, body: fullBody)
        
        return EmailItem(
            id: id,
            senderName: senderName,
            senderEmail: senderEmail,
            subject: subject,
            receivedDate: date,
            bodySnippet: bodyPreview,
            fullBody: fullBody,
            isUnread: !isRead,
            urgency: urgency
        )
    }
    
    public static func classifyEmail(subject: String, sender: String, body: String) -> EmailUrgency {
        let combined = "\(subject) \(sender) \(body)".lowercased()
        
        if combined.contains("urgent") || combined.contains("i-9") || combined.contains("advising") ||
           combined.contains("calendly.com") || combined.contains("deadline") || combined.contains("action required") {
            return .urgent
        }
        if combined.contains("syllabus") || combined.contains("homework") || combined.contains("phys") ||
           combined.contains("exam") || combined.contains("assignment") || combined.contains("lecture") {
            return .course
        }
        if combined.contains("student gov") || combined.contains("job") || combined.contains("hiring") ||
           combined.contains("bug") || combined.contains("elections") || combined.contains("fix") {
            return .opportunity
        }
        if combined.contains("club") || combined.contains("fair") || combined.contains("newsletter") ||
           combined.contains("announcement") {
            return .newsletter
        }
        return .general
    }
    
    @MainActor
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #elseif canImport(AppKit)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
