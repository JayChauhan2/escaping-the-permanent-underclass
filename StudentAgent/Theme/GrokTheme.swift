//
//  GrokTheme.swift
//  StudentAgent
//
//  Grok Design System Tokens (True-Black OLED, Monochrome + Link-Blue)
//

import SwiftUI

public extension Color {
    // MARK: - Canvas & Surfaces (True OLED Black)
    static let grokCanvas        = Color.black                                          // #000000
    static let grokSurface1      = Color(red: 0.086, green: 0.094, blue: 0.110)         // #16181C
    static let grokSurface2      = Color(red: 0.118, green: 0.129, blue: 0.149)         // #1E2126
    static let grokSurface3      = Color(red: 0.153, green: 0.165, blue: 0.180)         // #272A2E
    static let grokDivider       = Color(red: 0.184, green: 0.200, blue: 0.212)         // #2F3336
    static let grokBorderFocused = Color(red: 0.243, green: 0.255, blue: 0.275)         // #3E4146

    // MARK: - Text Hierarchy
    static let grokTextPrimary   = Color(red: 0.906, green: 0.914, blue: 0.918)         // #E7E9EA
    static let grokTextSecondary = Color(red: 0.443, green: 0.463, blue: 0.482)         // #71767B
    static let grokTextTertiary  = Color(red: 0.302, green: 0.318, blue: 0.337)         // #4D5156

    // MARK: - Functional & Accents
    static let grokAccentWhite   = Color.white                                          // #FFFFFF
    static let grokPressedWhite  = Color(red: 0.843, green: 0.859, blue: 0.863)         // #D7DBDC
    static let grokLinkBlue      = Color(red: 0.114, green: 0.608, blue: 0.941)         // #1D9BF0
    static let grokSuccess       = Color(red: 0.000, green: 0.729, blue: 0.486)         // #00BA7C
    static let grokError         = Color(red: 0.957, green: 0.129, blue: 0.180)         // #F4212E
    static let grokWarning       = Color(red: 1.000, green: 0.671, blue: 0.000)         // #FFAB00
}

// MARK: - Button Press Motion
public struct GrokPressableStyle: ButtonStyle {
    public var scale: CGFloat = 0.96
    public var opacity: CGFloat = 0.85
    
    public init(scale: CGFloat = 0.96, opacity: CGFloat = 0.85) {
        self.scale = scale
        self.opacity = opacity
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

public struct GrokCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 16
    public var isHighlighted: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .background(Color.grokSurface1)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(isHighlighted ? Color.grokLinkBlue.opacity(0.6) : Color.grokDivider, lineWidth: 1)
            )
    }
}

public extension View {
    func grokCard(cornerRadius: CGFloat = 16, isHighlighted: Bool = false) -> some View {
        modifier(GrokCardModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}
