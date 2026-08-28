//
//  TavilySearchService.swift
//  StudentAgent
//

import Foundation

public struct TavilySearchResultItem: Identifiable, Codable {
    public var id: String { url }
    public let title: String
    public let url: String
    public let content: String
    public let score: Double?
}

public struct TavilySearchAPIResponse: Codable {
    public let query: String
    public let answer: String?
    public let results: [TavilySearchResultItem]
}

@MainActor
public final class TavilySearchService {
    public static let shared = TavilySearchService()
    
    private let endpoint = "https://api.tavily.com/search"
    private let logger = DebugLogger.shared
    
    private init() {}
    
    public func search(query: String, maxResults: Int = 5) async throws -> [TavilySearchResultItem] {
        let apiKey = AppConfig.activeTavilyAPIKey
        guard !apiKey.isEmpty && apiKey != "tvly-YOUR_TAVILY_API_KEY" else {
            logger.log(type: .error, title: "Tavily Search Failed", payload: "Missing Tavily API Key. Configure Tavily Key in Settings.")
            throw NSError(domain: "TavilySearchService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Tavily API key is missing or not configured. Add your Tavily key in Settings."])
        }
        
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "TavilySearchService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Tavily search endpoint URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "search_depth": "basic",
            "include_answer": true,
            "max_results": maxResults
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.httpBody = jsonData
        
        logger.log(type: .apiRequest, title: "Tavily Search Query", payload: "Query: \(query)\nPayload: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.log(type: .error, title: "Tavily API HTTP \(httpRes.statusCode)", payload: errorBody)
            throw NSError(domain: "TavilySearchService", code: httpRes.statusCode, userInfo: [NSLocalizedDescriptionKey: "Tavily API Error (\(httpRes.statusCode)): \(errorBody)"])
        }
        
        let decoded = try JSONDecoder().decode(TavilySearchAPIResponse.self, from: data)
        logger.log(type: .apiResponse, title: "Tavily Results Received", payload: "Found \(decoded.results.count) results for '\(query)'. Answer: \(decoded.answer ?? "N/A")")
        return decoded.results
    }
    
    public func searchFormattedSummary(query: String, maxResults: Int = 5) async -> String {
        do {
            let results = try await search(query: query, maxResults: maxResults)
            if results.isEmpty {
                return "No web search results found for '\(query)'."
            }
            
            var lines: [String] = []
            for (idx, item) in results.prefix(maxResults).enumerated() {
                lines.append("[\(idx + 1)] \(item.title)\nURL: \(item.url)\nSnippet: \(item.content)")
            }
            return lines.joined(separator: "\n\n")
        } catch {
            return "Web search failed for '\(query)': \(error.localizedDescription)"
        }
    }
}
