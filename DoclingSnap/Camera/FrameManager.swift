////
////  ContentView.swift
////  HuggingSnap
////
////  Created by Cyril Zakka on 2/11/25.
////
import AVFoundation

class FrameManager: NSObject, ObservableObject {
    static let shared = FrameManager()
    
    @Published var current: CVPixelBuffer?
    @Published var isStreamingPaused: Bool = false
    
    let videoOutputQueue = DispatchQueue(
        label: "com.raywenderlich.VideoOutputQ",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
    private override init() {
        super.init()
        
        CameraManager.shared.set(self, queue: videoOutputQueue)
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        CameraManager.shared.$isStreamingPaused
            .receive(on: RunLoop.main)
            .assign(to: &$isStreamingPaused)
    }
}

extension FrameManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isStreamingPaused else { return }
        
        if let buffer = sampleBuffer.imageBuffer {
            DispatchQueue.main.async {
                self.current = buffer
            }
        }
    }
}
