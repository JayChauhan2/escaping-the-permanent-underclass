//
//  GmailService.swift
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

public final class GmailService: NSObject, EmailServiceProtocol, ASWebAuthenticationPresentationContextProviding {
    public static let shared = GmailService()
    
    public var providerName: String { "Gmail (Google OAuth)" }
    
    private let tokenKey = "gmail_access_token"
    
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
        let clientID = AppConfig.gmailClientID
        let redirectURI = AppConfig.gmailRedirectURI
        let scopes = "https://www.googleapis.com/auth/gmail.readonly"
        
        guard !clientID.contains("YOUR_GOOGLE_CLIENT_ID") else {
            print("[GmailService] Warning: Client ID not configured.")
            return false
        }
        
        guard let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=token&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw NSError(domain: "GmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Google OAuth URL."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.googleusercontent.apps") { callbackURL, error in
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
            return SimulatedEmailService.shared.getSampleStudentEmails()
        }
        
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=\(maxCount)&q=newer_than:2d")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return SimulatedEmailService.shared.getSampleStudentEmails()
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return []
        }
        
        var results: [EmailItem] = []
        for msg in messages.prefix(10) {
            if let id = msg["id"] as? String, let item = try? await getEmailDetails(id: id) {
                results.append(item)
            }
        }
        return results
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
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=\(maxCount)&q=\(encodedQuery)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return []
        }
        
        var results: [EmailItem] = []
        for msg in messages.prefix(8) {
            if let id = msg["id"] as? String, let item = try? await getEmailDetails(id: id) {
                results.append(item)
            }
        }
        return results
    }
    
    public func getEmailDetails(id: String) async throws -> EmailItem? {
        guard let token = accessToken else {
            return SimulatedEmailService.shared.getSampleStudentEmails().first(where: { $0.id == id })
        }
        
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
        
        return EmailItem(
            id: id,
            senderName: from,
            senderEmail: from,
            subject: subject,
            receivedDate: Date(),
            bodySnippet: snippet,
            fullBody: snippet,
            urgency: OutlookService.classifyEmail(subject: subject, sender: from, body: snippet)
        )
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

// MARK: - Simulated Email Service (for immediate testing & offline demo)
public final class SimulatedEmailService {
    public static let shared = SimulatedEmailService()
    
    public func getSampleStudentEmails() -> [EmailItem] {
        return [
            EmailItem(
                id: "msg_advisor_01",
                senderName: "Dr. Robert Vance (Academic Advisor)",
                senderEmail: "rvance@university.edu",
                subject: "URGENT: Mandatory Fall Degree Planning & Booking Appointment",
                receivedDate: Date().addingTimeInterval(-3600 * 2),
                bodySnippet: "Hi Jay, Please make sure to book your 1-on-1 academic advising session before the end of the week. Slots are filling up. Here is my booking link: https://calendly.com/advising-vance/fall24",
                isUnread: true,
                urgency: .urgent,
                extractedActionItems: [
                    "Book 1-on-1 academic advising appointment with Dr. Vance",
                    "Deadline: End of this week"
                ]
            ),
            EmailItem(
                id: "msg_sg_i9",
                senderName: "Student Government HR / Payroll",
                senderEmail: "studentgov-payroll@university.edu",
                subject: "Action Required: Complete Form I-9 for Student Government Employment",
                receivedDate: Date().addingTimeInterval(-3600 * 5),
                bodySnippet: "Hello, You must complete Section 1 of Form I-9 online and bring your original ID documents to the Campus Employment Office within 3 business days of hire.",
                isUnread: true,
                urgency: .urgent,
                extractedActionItems: [
                    "Fill out Form I-9 Section 1 online",
                    "Bring physical ID documents to Campus Employment Office within 3 days"
                ]
            ),
            EmailItem(
                id: "msg_sg_web",
                senderName: "Sarah Lin (Student Gov VP)",
                senderEmail: "slin@studentgov.org",
                subject: "Student Gov Portal - Broken navigation links on election page",
                receivedDate: Date().addingTimeInterval(-3600 * 8),
                bodySnippet: "Hey Jay, when you get a chance, can you take a look at the elections tab on the website? The mobile menu links are currently 404ing.",
                isUnread: true,
                urgency: .opportunity,
                extractedActionItems: [
                    "Fix broken navigation links on Student Government elections page"
                ]
            ),
            EmailItem(
                id: "msg_phys211",
                senderName: "Prof. Alan Turing (PHYS 211)",
                senderEmail: "aturing@physics.edu",
                subject: "PHYS 211: Welcome to Physics - Course Syllabus & First Homework Due Date",
                receivedDate: Date().addingTimeInterval(-3600 * 14),
                bodySnippet: "Welcome everyone. Please review the syllabus posted on the course website. Note that Homework 1 will be due next Tuesday at 11:59 PM.",
                isUnread: false,
                urgency: .course,
                extractedActionItems: [
                    "Review PHYS 211 syllabus",
                    "Submit Homework 1 by next Tuesday 11:59 PM"
                ],
                proposedEventDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
            ),
            EmailItem(
                id: "msg_clubs_01",
                senderName: "Campus Activities Board",
                senderEmail: "cab@university.edu",
                subject: "Fall Club Fair & Open Registrations this Thursday!",
                receivedDate: Date().addingTimeInterval(-3600 * 20),
                bodySnippet: "Join us in the Main Quad from 11 AM - 3 PM to explore over 150 student clubs, hackathons, and engineering societies.",
                isUnread: false,
                urgency: .newsletter,
                extractedActionItems: [
                    "Club Fair on Main Quad Thursday 11 AM - 3 PM"
                ]
            )
        ]
    }
}
