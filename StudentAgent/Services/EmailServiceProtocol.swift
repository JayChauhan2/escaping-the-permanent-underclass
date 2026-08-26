//
//  EmailServiceProtocol.swift
//  StudentAgent
//

import Foundation

public protocol EmailServiceProtocol {
    var providerName: String { get }
    var isAuthenticated: Bool { get }
    
    func authenticate() async throws -> Bool
    func signOut() async throws
    func fetchRecentEmails(hoursBack: Int, maxCount: Int) async throws -> [EmailItem]
    func searchEmails(query: String, maxCount: Int) async throws -> [EmailItem]
    func getEmailDetails(id: String) async throws -> EmailItem?
}
