////
////  ContentView.swift
////  HuggingSnap
////
////  Created by Cyril Zakka on 2/11/25.
////

import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    
    
    static let shared = CameraManager()
    
    // Photo output
    private let photoOutput = AVCapturePhotoOutput()
    @Published private(set) var photo: Data?
    
    // Movie output
    private let movieOutput = AVCaptureMovieFileOutput()
    private var temporaryMovieURL: URL?
    @Published private(set) var isRecording = false
    @Published private(set) var movieURL: URL?
    
    @Published var error: CameraError?
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back
    
    let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.cyrilzakka.SessionQ")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var status = Status.unconfigured
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    
    private override init() {
        super.init()
        configure()
    }
    
    private func set(error: CameraError?) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized {
                    self.status = .unauthorized
                    self.set(error: .deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            set(error: .restrictedAuthorization)
        case .denied:
            status = .unauthorized
            set(error: .deniedAuthorization)
        case .authorized:
            break
        @unknown default:
            status = .unauthorized
            set(error: .unknownAuthorization)
        }
    }
    
    private func configureCaptureSession() {
        guard status == .unconfigured else {
            return
        }
        
        session.beginConfiguration()
        
        defer {
            session.commitConfiguration()
        }
        
        let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: cameraPosition)
        guard let camera = device else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            set(error: .createCaptureInput(error))
            status = .failed
            return
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .speed
            photoOutput.isLivePhotoCaptureEnabled = false
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            let videoConnection = videoOutput.connection(with: .video)
            videoConnection?.videoRotationAngle = 90
            videoConnection?.isVideoMirrored = true
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        status = .configured
    }
    
    private func configure() {
        checkPermissions()
        
        sessionQueue.async {
            self.configureCaptureSession()
            self.session.startRunning()
        }
    }
    
    func switchCamera() {
        sessionQueue.async {
            self.reconfigureCaptureSession()
        }
    }
    
    private func reconfigureCaptureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Remove existing input
        for input in session.inputs {
            session.removeInput(input)
        }
        
        // Toggle camera position
        cameraPosition = cameraPosition == .front ? .back : .front
        
        // Get new camera device
        let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: cameraPosition)
        
        guard let camera = device else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
            
            // Update video connection rotation
            if let videoConnection = videoOutput.connection(with: .video) {
                if cameraPosition == .front {
                    videoConnection.videoRotationAngle = 90
                } else {
                    videoConnection.videoRotationAngle = 90
                    videoConnection.isVideoMirrored = true
                }
            }
            
        } catch {
            set(error: .createCaptureInput(error))
            status = .failed
            return
        }
    }
    
    private func videoOrientation() -> AVCaptureVideoOrientation {
        let deviceOrientation = UIDevice.current.orientation
        
        switch deviceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight  // Note the flip for correct orientation
        case .landscapeRight:
            return .landscapeLeft   // Note the flip for correct orientation
        default:
            return .portrait // Default to portrait if face up/down or unknown
        }
    }
    
    func capturePhoto() {
        sessionQueue.async {
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.photoQualityPrioritization = .speed
            
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = self.videoOrientation()
            }
            
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func toggleRecording() {
        guard !movieOutput.isRecording else {
            stopRecording()
            return
        }
        startRecording()
    }
    
    private func startRecording() {
        sessionQueue.async {
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Couldn't create movie file")
                return
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let currentDate = dateFormatter.string(from: Date())
            let videoName = "video_\(currentDate).mov"
            let videoPath = documentsPath.appendingPathComponent(videoName)
            
            try? FileManager.default.removeItem(at: videoPath) // Remove existing file
            
            self.movieOutput.startRecording(to: videoPath, recordingDelegate: self)
            self.temporaryMovieURL = videoPath
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }
    
    private func stopRecording() {
        sessionQueue.async {
            self.movieOutput.stopRecording()
            DispatchQueue.main.async {
                self.isRecording = false
                if let tempURL = self.temporaryMovieURL {
                    self.movieURL = tempURL
                }
            }
        }
    }
    
    func set(
        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
        queue: DispatchQueue
    ) {
        sessionQueue.async {
            self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
        }
    }
    
    @Published private(set) var isStreamingPaused: Bool = false
    
    func toggleStreaming() {
        isStreamingPaused.toggle()
        
        if isStreamingPaused {
            session.stopRunning()
        } else {
            sessionQueue.async {
                self.session.startRunning()
            }
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            set(error: .photo(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            set(error: .photo(NSError(domain: "CameraError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create image data"])))
            return
        }
        
        DispatchQueue.main.async {
            self.photo = imageData
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            set(error: .movie(error))
            return
        }
        
        // Optionally notify about successful recording
        print("Video saved to: \(outputFileURL.path)")
    }
}
