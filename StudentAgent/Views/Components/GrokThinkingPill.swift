//
//  GrokThinkingPill.swift
//  StudentAgent
//

import SwiftUI

public struct GrokThinkingPill: View {
    public let step: AgentExecutionStep
    @State private var isPulsing = false
    
    public var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.grokLinkBlue.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .scaleEffect(isPulsing ? 1.3 : 0.9)
                    .opacity(isPulsing ? 0.6 : 0.2)
                
                Image(systemName: step.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.grokLinkBlue)
            }
            
            Text(step.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.grokTextPrimary)
            
            Spacer()
            
            // Subtle typing wave dots
            HStack(spacing: 3) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(Color.grokTextSecondary)
                        .frame(width: 4, height: 4)
                        .opacity(isPulsing ? 0.9 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(idx) * 0.15),
                            value: isPulsing
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.grokSurface1)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.grokDivider, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

