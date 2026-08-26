//
//  EmailDigestView.swift
//  StudentAgent
//

import SwiftUI

public struct EmailDigestView: View {
    public let emails: [EmailItem]
    
    public init(emails: [EmailItem]) {
        self.emails = emails
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.badge.fill")
                    .foregroundColor(.indigo)
                Text("Relevant Emails Referenced (\(emails.count))")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            
            ForEach(emails) { email in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(email.senderName)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            
                            Text(email.subject)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Text(email.urgency.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: email.urgency.badgeColorHex).opacity(0.15))
                            .foregroundColor(Color(hex: email.urgency.badgeColorHex))
                            .clipShape(Capsule())
                    }
                    
                    if !email.bodySnippet.isEmpty {
                        Text(email.bodySnippet)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(10)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
    }
}

// Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
