//
//  GmailService.swift
//  StudentAgent
//

import Foundation
import AuthenticationServices
import CommonCrypto
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public final class GmailService: NSObject, EmailServiceProtocol, ASWebAuthenticationPresentationContextProviding {
    public static let shared = GmailService()
    
    public var providerName: String { "Gmail (Google OAuth)" }
    
    private let tokenKey = "gmail_access_token"
    private let refreshTokenKey = "gmail_refresh_token"
    
    public var isAuthenticated: Bool {
        let token = UserDefaults.standard.string(forKey: tokenKey)
        let refresh = UserDefaults.standard.string(forKey: refreshTokenKey)
        return (token != nil && !token!.isEmpty) || (refresh != nil && !refresh!.isEmpty)
    }
    
    public var accessToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }
    
    public var refreshToken: String? {
        UserDefaults.standard.string(forKey: refreshTokenKey)
    }
    
    // MARK: - OAuth 2.0 PKCE with Permanent Offline Refresh Token
    public func authenticate() async throws -> Bool {
        let clientID = AppConfig.gmailClientID
        let redirectURI = AppConfig.gmailRedirectURI
        let scopes = "https://www.googleapis.com/auth/gmail.readonly"
        
        guard !clientID.contains("YOUR_GOOGLE_CLIENT_ID") else {
            throw NSError(domain: "GmailService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gmail Client ID is not configured."])
        }
        
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        guard let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(encodedRedirect)&response_type=code&scope=\(encodedScopes)&access_type=offline&prompt=consent&code_challenge=\(codeChallenge)&code_challenge_method=S256") else {
            throw NSError(domain: "GmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Google OAuth URL."])
        }
        
        let authCode: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.googleusercontent.apps") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: NSError(domain: "GmailService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No authorization code returned."]))
                    return
                }
                
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
        
        return try await exchangeCodeForTokens(code: authCode, codeVerifier: codeVerifier, clientID: clientID, redirectURI: redirectURI)
    }
    
    private func exchangeCodeForTokens(code: String, codeVerifier: String, clientID: String, redirectURI: String) async throws -> Bool {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params: [String: String] = [
            "client_id": clientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        
        let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response from Google token server."])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errString = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GmailService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Token Exchange Failed (HTTP \(httpResponse.statusCode)): \(errString)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            return false
        }
        
        UserDefaults.standard.set(accessToken, forKey: tokenKey)
        if let refreshToken = json["refresh_token"] as? String {
            UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        }
        return true
    }
    
    // MARK: - Silent Auto-Refresh Engine
    public func getValidAccessToken() async throws -> String {
        if let token = accessToken, !token.isEmpty {
            return token
        }
        return try await refreshAccessToken()
    }
    
    public func refreshAccessToken() async throws -> String {
        guard let refToken = refreshToken, !refToken.isEmpty else {
            throw NSError(domain: "GmailService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No refresh token available. Please sign in via Settings."])
        }
        
        let clientID = AppConfig.gmailClientID
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params: [String: String] = [
            "client_id": clientID,
            "refresh_token": refToken,
            "grant_type": "refresh_token"
        ]
        
        let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errString = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GmailService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Silent token refresh failed: \(errString)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            throw NSError(domain: "GmailService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse refreshed token."])
        }
        
        UserDefaults.standard.set(newAccessToken, forKey: tokenKey)
        return newAccessToken
    }
    
    public func signOut() async throws {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
    }
    
    // Fetch Recent Emails with Auto-Refresh on 401
    public func fetchRecentEmails(hoursBack: Int = 0, maxCount: Int = 50) async throws -> [EmailItem] {
        var token = try await getValidAccessToken()
        
        var queryParam = ""
        if hoursBack > 0 {
            let days = max(1, Int(ceil(Double(hoursBack) / 24.0)))
            queryParam = "&q=newer_than:\(days)d"
        }
        
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=\(maxCount)\(queryParam)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var (data, response) = try await URLSession.shared.data(for: request)
        
        // If 401 expired, silently refresh token and retry immediately
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            token = try await refreshAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let retryResult = try await URLSession.shared.data(for: request)
            data = retryResult.0
            response = retryResult.1
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errStr = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gmail API Error: \(errStr)"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return []
        }
        
        var results: [EmailItem] = []
        for msg in messages.prefix(maxCount) {
            if let id = msg["id"] as? String, let item = try? await getEmailDetails(id: id) {
                results.append(item)
            }
        }
        return results
    }
    
    public func searchEmails(query: String, maxCount: Int = 25) async throws -> [EmailItem] {
        var token = try await getValidAccessToken()
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=\(maxCount)&q=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            token = try await refreshAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let retryResult = try await URLSession.shared.data(for: request)
            data = retryResult.0
            response = retryResult.1
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return []
        }
        
        var results: [EmailItem] = []
        for msg in messages.prefix(maxCount) {
            if let id = msg["id"] as? String, let item = try? await getEmailDetails(id: id) {
                results.append(item)
            }
        }
        return results
    }
    
    public func getEmailDetails(id: String) async throws -> EmailItem? {
        let token = try await getValidAccessToken()
        
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = dict["payload"] as? [String: Any],
              let headers = payload["headers"] as? [[String: String]] else {
            return nil
        }
        
        let subject = headers.first(where: { $0["name"]?.lowercased() == "subject" })?["value"] ?? "(No Subject)"
        let from = headers.first(where: { $0["name"]?.lowercased() == "from" })?["value"] ?? "Unknown"
        let snippet = dict["snippet"] as? String ?? ""
        
        let fullBody = extractBody(from: payload) ?? snippet
        
        return EmailItem(
            id: id,
            senderName: from,
            senderEmail: from,
            subject: subject,
            receivedDate: Date(),
            bodySnippet: snippet,
            fullBody: fullBody,
            urgency: OutlookService.classifyEmail(subject: subject, sender: from, body: fullBody)
        )
    }
    
    private func extractBody(from payload: [String: Any]) -> String? {
        if let body = payload["body"] as? [String: Any],
           let base64Data = body["data"] as? String,
           let text = decodeBase64URL(base64Data) {
            return cleanEmailText(text)
        }
        
        if let parts = payload["parts"] as? [[String: Any]] {
            for part in parts {
                let mimeType = part["mimeType"] as? String ?? ""
                if mimeType == "text/plain" || mimeType == "text/html" {
                    if let body = part["body"] as? [String: Any],
                       let base64Data = body["data"] as? String,
                       let text = decodeBase64URL(base64Data) {
                        return cleanEmailText(text)
                    }
                }
            }
        }
        return nil
    }
    
    private func decodeBase64URL(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func cleanEmailText(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - PKCE Utilities
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
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
