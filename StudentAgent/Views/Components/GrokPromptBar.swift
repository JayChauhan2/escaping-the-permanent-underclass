//
//  GrokPromptBar.swift
//  StudentAgent
//

import SwiftUI
import PhotosUI
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
    #if canImport(UIKit)
    @Binding public var attachedImage: UIImage?
    #endif
    public var isProcessing: Bool
    public var onSend: () -> Void
    public var onStop: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var showPhotosPicker: Bool = false
    
    #if canImport(UIKit)
    public init(
        text: Binding<String>,
        attachedImage: Binding<UIImage?>,
        isProcessing: Bool,
        onSend: @escaping () -> Void,
        onStop: @escaping () -> Void = {}
    ) {
        self._text = text
        self._attachedImage = attachedImage
        self.isProcessing = isProcessing
        self.onSend = onSend
        self.onStop = onStop
    }
    #else
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
    #endif
    
    private var hasContent: Bool {
        #if canImport(UIKit)
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil
        #else
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #endif
    }
    
    private var sendState: GrokSendState {
        if isProcessing { return .streaming }
        if !hasContent { return .disabled }
        return .enabled
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            #if canImport(UIKit)
            // Attached Image Preview Pill
            if let img = attachedImage {
                HStack(spacing: 8) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.grokDivider, lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Image Reference Attached")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.grokTextPrimary)
                        Text("Text & details will be analyzed")
                            .font(.system(size: 11))
                            .foregroundColor(Color.grokTextSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            attachedImage = nil
                            selectedPhotoItem = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.grokTextSecondary)
                    }
                }
                .padding(8)
                .background(Color.grokSurface2)
                .cornerRadius(12)
                .padding(.horizontal, 4)
                .transition(.scale.combined(with: .opacity))
            }
            #endif
            
            HStack(alignment: .bottom, spacing: 10) {
                #if canImport(UIKit)
                // Plus Button with iOS Native Glass Menu (Camera & Photos)
                Menu {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showCamera = true
                    }) {
                        Label("Camera", systemImage: "camera.fill")
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showPhotosPicker = true
                    }) {
                        Label("Photos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.grokTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.grokSurface2))
                }
                .buttonStyle(GrokPressableStyle(scale: 0.92))
                .photosPicker(
                    isPresented: $showPhotosPicker,
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                )
                .sheet(isPresented: $showCamera) {
                    CameraPickerView(image: $attachedImage)
                        .ignoresSafeArea()
                }
                .onChange(of: selectedPhotoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImg = UIImage(data: data) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                attachedImage = uiImg
                            }
                        }
                    }
                }
                #else
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.grokTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.grokSurface2))
                #endif
                
                TextField("Ask anything or reference an image...", text: $text, axis: .vertical)
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
