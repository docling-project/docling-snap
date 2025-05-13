//
//  SpeechTranscriptionModel.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/18/25.
//

import Foundation
import AVFoundation
import Speech
import SwiftUI
import Accelerate

final class WeakRef<T: AnyObject> {
    private(set) weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}

/// A helper for transcribing speech to text using SFSpeechRecognizer and AVAudioEngine.
actor SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }
    
    @MainActor var transcript: String = ""
    @MainActor var transcriptionTime: TimeInterval = 0
    @MainActor private var timer: Timer?
    @MainActor private var startTime: Date?
    
    @MainActor @Published var audioLevels: [Float] = Array(repeating: -1, count: 100)
    private let audioLevelUpdateQueue = DispatchQueue(label: "com.audioLevel.queue")
    
    private var audioEngine: AVAudioEngine?
    private let decayFactor: Float = 0.85
    
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    /**
     Initializes a new speech recognizer. If this is the first time you've used the class, it
     requests access to the speech recognizer and the microphone.
     */
    init() {
        recognizer = SFSpeechRecognizer()
        guard recognizer != nil else {
            transcribe(RecognizerError.nilRecognizer)
            return
        }
        
        Task {
            do {
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                transcribe(error)
            }
        }
    }
    
    @MainActor func startTranscribing() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let startTime = self.startTime else { return }
                self.transcriptionTime = Date().timeIntervalSince(startTime)
            }
        }
        
        Task {
            await transcribe()
        }
    }
    
    
    @MainActor func resetTranscript() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        transcriptionTime = 0
        audioLevels = Array(repeating: -1, count: 100)
        Task {
            await reset()
        }
    }
    
    @MainActor func stopTranscribing() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        transcriptionTime = 0
        audioLevels = Array(repeating: -1, count: 100)
        Task {
            await reset()
        }
    }
    
    /**
     Begin transcribing audio.
     
     Creates a `SFSpeechRecognitionTask` that transcribes speech to text until you call `stopTranscribing()`.
     The resulting transcription is continuously written to the published `transcript` property.
     */
    private func transcribe() {
        guard let recognizer, recognizer.isAvailable else {
            self.transcribe(RecognizerError.recognizerIsUnavailable)
            return
        }
        
        do {
            let weakSelf = WeakRef(self)
            let (audioEngine, request) = try Self.prepareEngine(weakSelf: weakSelf)
            self.audioEngine = audioEngine
            self.request = request
            
            self.task = recognizer.recognitionTask(with: request, resultHandler: { [weak self] result, error in
                self?.recognitionHandler(audioEngine: audioEngine, result: result, error: error)
            })
        } catch {
            self.reset()
            self.transcribe(error)
        }
    }
    
    /// Reset the speech recognizer.
    private func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
    }
    
    private static func prepareEngine(weakSelf: WeakRef<SpeechRecognizer>) throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return }
                        let frameLength = Int(buffer.frameLength)
                        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
                        
                        // Process audio levels using the extracted samples
                        Task {
                            await weakSelf.value?.processAudioData(samples)
                        }
        }
        audioEngine.prepare()
        try audioEngine.start()
        
        return (audioEngine, request)
    }
    
    nonisolated private func recognitionHandler(audioEngine: AVAudioEngine, result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        if let result {
            transcribe(result.bestTranscription.formattedString)
        }
    }
    
    
    nonisolated private func transcribe(_ message: String) {
        Task { @MainActor in
            transcript = message
        }
    }
    nonisolated private func transcribe(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        Task { @MainActor [errorMessage] in
            transcript = "<< \(errorMessage) >>"
        }
    }
}


extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}


extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { authorized in
                    continuation.resume(returning: authorized)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                requestRecordPermission { authorized in
                    continuation.resume(returning: authorized)
                }
            }
        }
    }
}

extension SpeechRecognizer {
        
    private func processAudioData(_ samples: [Float]) {
        audioLevelUpdateQueue.async { [weak self] in
            guard let self = self else { return }
            
            var rms: Float = 0
            vDSP_measqv(samples, 1, &rms, UInt(samples.count))
            rms = sqrtf(rms)
            
            // Improved audio level processing
            let db = 20 * log10f(rms)
            
            // Adjust the scaling range for more dynamic visualization
            let minDb: Float = -60 // Increase sensitivity to quiet sounds
            let maxDb: Float = -10 // Adjust for louder sounds
            let normalizedValue = max(0.1, min(1.0, (db - minDb) / (maxDb - minDb)))
            
            // Apply non-linear scaling for better visual effect
            let scaledValue = powf(normalizedValue, 0.7) // Adjust power for desired curve
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                var newLevels = self.audioLevels
                print("Samples", newLevels.count)
                if newLevels.count > 100 {
                    newLevels.removeFirst(1)
                }
                
                newLevels.append(scaledValue)
                
                self.audioLevels = newLevels
            }
        }
    }
}

