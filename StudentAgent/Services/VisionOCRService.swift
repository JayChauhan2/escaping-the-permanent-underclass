//
//  VisionOCRService.swift
//  StudentAgent
//

import Foundation
#if canImport(UIKit)
import UIKit
import Vision

public final class VisionOCRService {
    public static let shared = VisionOCRService()
    
    private init() {}
    
    public func recognizeText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
}
#else
public final class VisionOCRService {
    public static let shared = VisionOCRService()
    public func recognizeText(from image: Any) async -> String { "" }
}
#endif
