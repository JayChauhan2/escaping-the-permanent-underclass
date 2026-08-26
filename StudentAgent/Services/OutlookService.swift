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
    
    public var providerName: String { "Student Outlook (Microsoft Graph)" }
    
    private let tokenKey = "ms_graph_access_token"
    private let refreshTokenKey = "ms_graph_refresh_token"
    
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
        let tenant = AppConfig.outlookTenantID
        let redirectURI = AppConfig.outlookRedirectURI
        let scopes = "Mail.Read User.Read offline_access"
        
        guard clientID != "YOUR_MICROSOFT_APP_CLIENT_ID" else {
            print("[OutlookService] Warning: Client ID not configured. Use demo inbox or set in Secrets.swift.")
            return false
        }
        
        guard let authURL = URL(string: "https://login.microsoftonline.com/\(tenant)/oauth2/v2.0/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&response_mode=query&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw NSError(domain: "OutlookService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OAuth URL."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "msauth.com.jaychauhan.studentagent") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: NSError(domain: "OutlookService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No auth code received."]))
                    return
                }
                
                // Exchange code for token
                Task {
                    do {
                        let success = try await self.exchangeCodeForToken(code: code)
                        continuation.resume(returning: success)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
    }
    
    private func exchangeCodeForToken(code: String) async throws -> Bool {
        let tokenURL = URL(string: "https://login.microsoftonline.com/\(AppConfig.outlookTenantID)/oauth2/v2.0/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": AppConfig.outlookClientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": AppConfig.outlookRedirectURI
        ]
        
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OutlookService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Token exchange failed."])
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let accessToken = json["access_token"] as? String {
            UserDefaults.standard.set(accessToken, forKey: tokenKey)
            if let refreshToken = json["refresh_token"] as? String {
                UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
            }
            return true
        }
        
        return false
    }
    
    public func signOut() async throws {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
    }
    
    public func fetchRecentEmails(hoursBack: Int = 48, maxCount: Int = 20) async throws -> [EmailItem] {
        guard let token = accessToken else {
            return SimulatedEmailService.shared.getSampleStudentEmails()
        }
        
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$top=\(maxCount)&$select=id,subject,from,receivedDateTime,bodyPreview,isRead&$orderby=receivedDateTime%20desc")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return SimulatedEmailService.shared.getSampleStudentEmails()
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["value"] as? [[String: Any]] else {
            return []
        }
        
        return values.compactMap { dict -> EmailItem? in
            let id = dict["id"] as? String ?? UUID().uuidString
            let subject = dict["subject"] as? String ?? "(No Subject)"
            let bodyPreview = dict["bodyPreview"] as? String ?? ""
            let isRead = dict["isRead"] as? Bool ?? false
            
            var senderName = "Unknown"
            var senderEmail = ""
            if let from = dict["from"] as? [String: Any],
               let emailAddress = from["emailAddress"] as? [String: Any] {
                senderName = emailAddress["name"] as? String ?? "Unknown"
                senderEmail = emailAddress["address"] as? String ?? ""
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let dateStr = dict["receivedDateTime"] as? String ?? ""
            let date = dateFormatter.date(from: dateStr) ?? Date()
            
            let urgency = Self.classifyEmail(subject: subject, sender: senderName, body: bodyPreview)
            
            return EmailItem(
                id: id,
                senderName: senderName,
                senderEmail: senderEmail,
                subject: subject,
                receivedDate: date,
                bodySnippet: bodyPreview,
                isUnread: !isRead,
                urgency: urgency
            )
        }
    }
    
    public func searchEmails(query: String, maxCount: Int = 15) async throws -> [EmailItem] {
        guard let token = accessToken else {
            return SimulatedEmailService.shared.getSampleStudentEmails().filter {
                $0.subject.localizedCaseInsensitiveContains(query) ||
                $0.senderName.localizedCaseInsensitiveContains(query) ||
                $0.bodySnippet.localizedCaseInsensitiveContains(query)
            }
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchString = "\"\(encodedQuery)\""
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$search=\(searchString)&$top=\(maxCount)&$select=id,subject,from,receivedDateTime,bodyPreview,isRead")!
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
        
        return values.compactMap { dict -> EmailItem? in
            let id = dict["id"] as? String ?? UUID().uuidString
            let subject = dict["subject"] as? String ?? "(No Subject)"
            let bodyPreview = dict["bodyPreview"] as? String ?? ""
            let isRead = dict["isRead"] as? Bool ?? false
            
            var senderName = "Unknown"
            var senderEmail = ""
            if let from = dict["from"] as? [String: Any],
               let emailAddress = from["emailAddress"] as? [String: Any] {
                senderName = emailAddress["name"] as? String ?? "Unknown"
                senderEmail = emailAddress["address"] as? String ?? ""
            }
            
            let urgency = Self.classifyEmail(subject: subject, sender: senderName, body: bodyPreview)
            
            return EmailItem(
                id: id,
                senderName: senderName,
                senderEmail: senderEmail,
                subject: subject,
                receivedDate: Date(),
                bodySnippet: bodyPreview,
                isUnread: !isRead,
                urgency: urgency
            )
        }
    }
    
    public func getEmailDetails(id: String) async throws -> EmailItem? {
        guard let token = accessToken else {
            return SimulatedEmailService.shared.getSampleStudentEmails().first(where: { $0.id == id })
        }
        
        let url = URL(string: "https://graph.microsoft.com/v1.0/me/messages/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let subject = dict["subject"] as? String ?? ""
        let bodyDict = dict["body"] as? [String: Any]
        let content = bodyDict?["content"] as? String ?? (dict["bodyPreview"] as? String ?? "")
        
        var senderName = "Unknown"
        var senderEmail = ""
        if let from = dict["from"] as? [String: Any],
           let emailAddress = from["emailAddress"] as? [String: Any] {
            senderName = emailAddress["name"] as? String ?? "Unknown"
            senderEmail = emailAddress["address"] as? String ?? ""
        }
        
        return EmailItem(
            id: id,
            senderName: senderName,
            senderEmail: senderEmail,
            subject: subject,
            receivedDate: Date(),
            bodySnippet: dict["bodyPreview"] as? String ?? "",
            fullBody: content,
            urgency: Self.classifyEmail(subject: subject, sender: senderName, body: content)
        )
    }
    
    public static func classifyEmail(subject: String, sender: String, body: String) -> EmailUrgency {
        let text = "\(subject) \(sender) \(body)".lowercased()
        if text.contains("advisor") || text.contains("schedule") || text.contains("i-9") || text.contains("i9") || text.contains("urgent") || text.contains("appointment") || text.contains("deadline") {
            return .urgent
        }
        if text.contains("prof") || text.contains("syllabus") || text.contains("homework") || text.contains("exam") || text.contains("assignment") || text.contains("lecture") || text.contains("canvas") || text.contains("class") {
            return .course
        }
        if text.contains("research") || text.contains("student government") || text.contains("internship") || text.contains("job") || text.contains("opportunity") {
            return .opportunity
        }
        if text.contains("club") || text.contains("newsletter") || text.contains("meeting") || text.contains("campus") {
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
