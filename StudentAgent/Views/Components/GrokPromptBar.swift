//
//  GrokPromptBar.swift
//  StudentAgent
//

import SwiftUI

public enum GrokSendState {
    case disabled
    case enabled
    case streaming
}

public struct GrokSendButton: View {
    public let state: GrokSendState
    public let action: () -> Void
    
    public init(state: GrokSendState, action: @escaping () -> Void) {
        self.state = state
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Group {
                switch state {
                case .streaming:
                    Image(systemName: "stop.fill")
                        .foregroundColor(Color.grokTextPrimary)
                        .font(.system(size: 13, weight: .bold))
                case .enabled:
                    Image(systemName: "arrow.up")
                        .foregroundColor(Color.black)
                        .font(.system(size: 15, weight: .bold))
                case .disabled:
                    Image(systemName: "arrow.up")
                        .foregroundColor(Color.grokTextSecondary)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .frame(width: 32, height: 32)
            .background(Circle().fill(buttonFill))
        }
        .buttonStyle(GrokPressableStyle(scale: 0.92))
        .disabled(state == .disabled)
    }
    
    private var buttonFill: Color {
        switch state {
        case .disabled:  return Color.grokSurface3
        case .enabled:   return Color.grokAccentWhite
        case .streaming: return Color.grokSurface3
        }
    }
}

public struct GrokPromptBar: View {
    @Binding public var text: String
    public var isProcessing: Bool
    public var onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    public init(text: Binding<String>, isProcessing: Bool, onSend: @escaping () -> Void) {
        self._text = text
        self.isProcessing = isProcessing
        self.onSend = onSend
    }
    
    private var sendState: GrokSendState {
        if isProcessing { return .streaming }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .disabled }
        return .enabled
    }
    
    public var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your student agent anything...", text: $text, axis: .vertical)
                .font(.system(size: 16))
                .foregroundColor(Color.grokTextPrimary)
                .tint(Color.grokLinkBlue)
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(.vertical, 4)
            
            GrokSendButton(state: sendState, action: {
                if !isProcessing {
                    onSend()
                }
            })
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.grokSurface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(isFocused ? Color.grokBorderFocused : Color.grokDivider, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.grokCanvas)
    }
}
