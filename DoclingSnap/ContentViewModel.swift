//
//  ContentViewModel.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/13/25.
//

import CoreImage

class ContentViewModel: ObservableObject {
    @Published var error: Error?
    @Published var frame: CGImage?
    @Published var isRecording: Bool = false
    @Published var movieURL: URL?
    @Published var isStreamingPaused: Bool = false
    @Published var photo: Data?
    
    private let context = CIContext()
    
    private let cameraManager = CameraManager.shared
    private let frameManager = FrameManager.shared
    
    init() {
        setupSubscriptions()
    }
    
    func setupSubscriptions() {
        // swiftlint:disable:next array_init
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        frameManager.$current
            .receive(on: RunLoop.main)
            .compactMap { buffer in
                guard let image = CGImage.create(from: buffer) else {
                    return nil
                }
                
                let ciImage = CIImage(cgImage: image)
                
                return self.context.createCGImage(ciImage, from: ciImage.extent)
            }
            .assign(to: &$frame)
        
        cameraManager.$isRecording
                    .receive(on: RunLoop.main)
                    .assign(to: &$isRecording)
        
        cameraManager.$isStreamingPaused
                    .receive(on: RunLoop.main)
                    .assign(to: &$isStreamingPaused)
        
        cameraManager.$photo
            .receive(on: RunLoop.main)
            .assign(to: &$photo)
        
        cameraManager.$movieURL
            .receive(on: RunLoop.main)
            .assign(to: &$movieURL)
    }
    
    func switchCamera() {
        cameraManager.switchCamera()
    }
    
    func capturePhoto() {
        cameraManager.capturePhoto()
    }
    
    func toggleRecording() {
        cameraManager.toggleRecording()
    }
    
    func toggleStreaming() {
        cameraManager.toggleStreaming()
    }
}
