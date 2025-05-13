//
//  VLMEvaluator.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/14/25.
//

import SwiftUI
import MLX
import MLXLMCommon
import MLXRandom
import MLXVLM
import Hub

// Runtime configuration download

struct DoclingSnapModelConfiguration: Codable, Sendable {
    // static let configurationRepo = "HuggingFaceTB/smolvlm-app-config"

    let model: String
    let videoSystemPrompt: String
    let videoUserPrompt: String
    let photoSystemPrompt: String
    let photoUserPrompt: String
    let generationParameters: GenerationParameters

    struct GenerationParameters: Codable, Sendable {
        let temperature: Float
        let topP: Float
    }

    enum CodingKeys: String, CodingKey {
        case model
        case videoSystemPrompt
        case videoUserPrompt
        case photoSystemPrompt
        case photoUserPrompt
        case generationParameters = "generation"
    }
}

// FIXME: this is global because otherwise I have to access with `await` inside the async methods, will fix later
fileprivate var runtimeConfiguration: DoclingSnapModelConfiguration = DoclingSnapModelConfiguration(
    // model: "HuggingFaceTB/SmolVLM2-500M-Video-Instruct-mlx",
    model: "ds4sd/SmolDocling-256M-preview-mlx-bf16-docling-snap",


    videoSystemPrompt: "Convert this page to docling.",
    videoUserPrompt: "Convert this page to docling.",
    photoSystemPrompt: "Convert this page to docling.",
    photoUserPrompt: "Convert this page to docling.",

    // videoSystemPrompt: "Focus only on describing the key dramatic action or notable event occurring in this video segment. Skip general context or scene-setting details unless they are crucial to understanding the main action.",
    // videoUserPrompt: "What is the main action or notable event happening in this segment? Describe it in one brief sentence.",
    // photoSystemPrompt: "You are an image understanding model capable of describing the salient features of any image.",
    // photoUserPrompt: "Describe this image.",
    // generation: DoclingSnapModelConfiguration.GenerationParameters(temperature: 0.1, topP: 0.9)

    // -----------------------------------------------------------------------------------------------------
    // generationParameters: DoclingSnapModelConfiguration.GenerationParameters(temperature: 0.1, topP: 0.9)
    generationParameters: DoclingSnapModelConfiguration.GenerationParameters(temperature: 0.1, topP: 0.9)
)

@Observable
@MainActor
class VLMEvaluator {

    var running = false
    var customUserInput = ""
    var output = ""
    var modelInfo = "Initializing model..."
    var stat = ""

    let maxTokens = 1500

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

    /*
    func loadConfiguration(hub: HubApi) async throws -> DoclingSnapModelConfiguration {
        let filename = "config.json"
        let downloadedTo = try await hub.snapshot(from: DoclingSnapModelConfiguration.configurationRepo, matching: filename)
        let jsonURL = downloadedTo.appendingPathComponent(filename)
        let config = try JSONDecoder().decode(DoclingSnapModelConfiguration.self, from: try Data(contentsOf: jsonURL))

        // FIXME: remove this when we upgrade to swift-transformers with cache invalidation
        try? FileManager().removeItem(at: downloadedTo)

        return config
    }
    */

    /// load and return the model -- can be called multiple times, subsequent calls will
    /// just return the loaded model
    func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
                // limit the buffer cache
                MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

                // This may make things very slow when way over the limit
                // TODO: make this dependent on device + max number of frames
                let maxMetalMemory = Int(round(0.82 * Double(os_proc_available_memory())))
                MLX.GPU.set(memoryLimit: maxMetalMemory, relaxed: false)

                // Load runtime configuration
                // TODO: use a fallback if we can't download - ideally the one from the previous run
                // Fine-grained read-only token for the HuggingFaceTB org
                let hubApi = HubApi()
                // let config = try await loadConfiguration(hub: HubApi())
                // runtimeConfiguration = config
                let config = runtimeConfiguration

            let modelConfiguration = ModelConfiguration(id: config.model, defaultPrompt: config.photoUserPrompt)

                let modelContainer = try await VLMModelFactory.shared.loadContainer(hub: hubApi,
                    configuration: modelConfiguration
                ) { [modelConfiguration] progress in
                    Task { @MainActor in
                        self.modelInfo =
                            "Downloading model: \(Int(progress.fractionCompleted * 100))%"
                    }
                }

                let _ = await modelContainer.perform { context in
                    context.model.numParameters()
                }

                self.modelInfo = "Finished loading."
                loadState = .loaded(modelContainer)
                return modelContainer
            
        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    // TODO: various prompts for different tasks
    func generate(image: CIImage?, videoURL: URL?) async {
        guard !running else { return }

        running = true
        self.output = ""
        let orientedImage = image?.oriented(.right)
        
        do {
            let modelContainer = try await load()
            let result = try await modelContainer.perform { context in
                let images: [UserInput.Image] =
                    if let orientedImage {
                        [UserInput.Image.ciImage(orientedImage)]
                    } else {
                        []
                    }
                let videos: [UserInput.Video] =
                    if let videoURL {
                        [.url(videoURL)]
                    } else {
                        []
                    }

                let systemPrompt = videoURL != nil ? runtimeConfiguration.videoSystemPrompt : runtimeConfiguration.photoSystemPrompt
                let userPrompt = await customUserInput.isEmpty ? (videoURL != nil ? runtimeConfiguration.videoUserPrompt : runtimeConfiguration.photoUserPrompt):customUserInput
                
                // Note: the image order is different for smolvlm
                let messages: [Message] = [
                    [
                        "role": "system",
                        "content": [
                            [
                                "type": "text",
                                "text": systemPrompt,
                            ],
                        ]
                    ],
                    [
                        "role": "user",
                        "content": []
                            + images.map { _ in
                                ["type": "image"]
                            }
                            + videos.map { _ in
                                ["type": "video"]
                            }
                            + [["type": "text", "text": userPrompt]]
                    ]
                ]

                let userInput = UserInput(messages: messages, images: images, videos: videos)
                print("userInput in app... IMAGE SHOULD NOT BE EMPTY!")
                print(userInput)
                let input = try await context.processor.prepare(input: userInput)
                
                let generationParameters = MLXLMCommon.GenerateParameters(
                    temperature: runtimeConfiguration.generationParameters.temperature,
                    topP: runtimeConfiguration.generationParameters.topP
                )
                return try MLXLMCommon.generate(
                    input: input,
                    parameters: generationParameters,
                    context: context
                ) { tokens in
                    // update the output -- this will make the view show the text as it generates
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                        }
                    }

                    let last_t = [tokens.last ?? 0]
                    let decoded_token = context.tokenizer.decode(tokens: last_t)
                    print(decoded_token)
                    // TODO: Stop prediction after <end_of_utterance>
                    if decoded_token == "<end_of_utterance>" {
                        return .stop
                    }
                    
                    if tokens.count >= maxTokens {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            // update the text if needed, e.g. we haven't displayed because of displayEveryNTokens
            if result.output != self.output {
                self.output = result.output
            }
            self.stat = " Tokens/second: \(String(format: "%.3f", result.tokensPerSecond))"

        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }
}
