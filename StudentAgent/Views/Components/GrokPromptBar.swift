//
//  GrokPromptBar.swift
//  StudentAgent
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum GrokSendState {
    case disabled
    case enabled
    case streaming
}

public struct GrokSendButton: View {
    public let state: GrokSendState
    public let onSend: () -> Void
    public let onStop: () -> Void
    
    public init(state: GrokSendState, onSend: @escaping () -> Void, onStop: @escaping () -> Void = {}) {
        self.state = state
        self.onSend = onSend
        self.onStop = onStop
    }
    
    public var body: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            if state == .streaming {
                onStop()
            } else if state == .enabled {
                onSend()
            }
        }) {
            Group {
                switch state {
                case .streaming:
                    Image(systemName: "stop.fill")
                        .foregroundColor(Color.grokTextPrimary)
                        .font(.system(size: 12, weight: .bold))
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
        case .streaming: return Color.grokSurface2
        }
    }
}

public struct GrokPromptBar: View {
    @Binding public var text: String
    public var isProcessing: Bool
    public var onSend: () -> Void
    public var onStop: () -> Void
    
    @FocusState private var isFocused: Bool
    
    public init(
        text: Binding<String>,
        isProcessing: Bool,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void = {}
    ) {
        self._text = text
        self.isProcessing = isProcessing
        self.onSend = onSend
        self.onStop = onStop
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
            
            GrokSendButton(
                state: sendState,
                onSend: onSend,
                onStop: onStop
            )
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
