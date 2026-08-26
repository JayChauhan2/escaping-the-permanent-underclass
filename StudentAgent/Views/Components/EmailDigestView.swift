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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "envelope.badge")
                    .foregroundColor(Color.grokLinkBlue)
                    .font(.system(size: 12))
                Text("REFERENCED INBOX MESSAGES (\(emails.count))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.grokTextSecondary)
            }
            .padding(.bottom, 2)
            
            ForEach(emails) { email in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(email.senderName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.grokTextPrimary)
                                    .lineLimit(1)
                                
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(Color.grokLinkBlue)
                                    .font(.system(size: 11))
                            }
                            
                            Text(email.subject)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.grokTextPrimary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Text(email.urgency.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(urgencyColor(email.urgency).opacity(0.18))
                            .foregroundColor(urgencyColor(email.urgency))
                            .clipShape(Capsule())
                    }
                    
                    if !email.bodySnippet.isEmpty {
                        Text(email.bodySnippet)
                            .font(.system(size: 12))
                            .foregroundColor(Color.grokTextSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(Color.grokSurface2)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.grokDivider, lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(Color.grokSurface1)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.grokDivider, lineWidth: 1)
        )
    }
    
    private func urgencyColor(_ urgency: EmailUrgency) -> Color {
        switch urgency {
        case .urgent: return Color.grokError
        case .course: return Color.grokLinkBlue
        case .opportunity: return Color.grokSuccess
        case .newsletter: return Color.grokWarning
        case .general: return Color.grokTextSecondary
        }
    }
}
