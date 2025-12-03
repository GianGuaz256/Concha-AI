//
//  LLMService.swift
//  Concha AI
//
//  Local LLM inference using MLX
//

import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
@Observable
class LLMService {
    static let shared = LLMService()
    
    private var modelContainer: ModelContainer?
    
    var isLoaded: Bool = false
    var isGenerating: Bool = false
    var loadingProgress: String = ""
    var loadError: String?
    
    private let modelService = ModelService.shared
    
    private init() {}
    
    // MARK: - Model Loading
    
    func loadModel() async throws {
        guard let modelPath = modelService.llmModelPath else {
            throw LLMError.modelNotFound
        }
        
        loadingProgress = "Loading model..."
        print("🤖 Loading model from: \(modelPath.path)")
        
        // Verify all required files exist
        let fileManager = FileManager.default
        let requiredFiles = ["config.json", "model.safetensors", "tokenizer.json"]
        
        for file in requiredFiles {
            let filePath = modelPath.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: filePath.path) {
                print("❌ Missing required file: \(file)")
                throw LLMError.modelNotFound
            } else {
                print("✓ Found: \(file)")
            }
        }
        
        do {
            // Use the directory path directly without file:// scheme
            // MLX Swift expects just the directory path for local models
            print("📂 Model path: \(modelPath.path)")
            
            let configuration = ModelConfiguration(
                directory: modelPath
            )
            
            print("📦 Initializing model container...")
            print("   Loading from local directory")
            
            // Load the model using the factory
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: configuration
            ) { progress in
                Task { @MainActor in
                    self.loadingProgress = "Loading: \(Int(progress.fractionCompleted * 100))%"
                    print("⏳ Model loading: \(Int(progress.fractionCompleted * 100))%")
                }
            }
            
            self.modelContainer = container
            self.isLoaded = true
            self.loadingProgress = "Model ready"
            print("✅ Model loaded successfully!")
        } catch {
            print("❌ Model loading error: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Description: \(error.localizedDescription)")
            loadError = error.localizedDescription
            throw LLMError.loadFailed(error.localizedDescription)
        }
    }
    
    func unloadModel() {
        modelContainer = nil
        isLoaded = false
        loadingProgress = ""
    }
    
    // MARK: - Generation
    
    func generate(
        prompt: String,
        systemPrompt: String? = nil,
        memories: [String] = [],
        history: [Message] = []
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    guard let container = modelContainer else {
                        throw LLMError.modelNotLoaded
                    }
                    
                    isGenerating = true
                    
                    // Build the chat messages for MLX (use fully qualified type)
                    var chatMessages: [MLXLMCommon.Chat.Message] = []
                    
                    // System message
                    let system = systemPrompt ?? "You are a helpful AI assistant running locally on the user's device. Be concise and helpful."
                    var systemContent = system
                    if !memories.isEmpty {
                        systemContent += "\n\nRelevant memories from past conversations:\n"
                        for memory in memories {
                            systemContent += "- \(memory)\n"
                        }
                    }
                    chatMessages.append(.system(systemContent))
                    
                    // Add conversation history
                    let recentHistory = history.suffix(6)
                    for message in recentHistory {
                        switch message.role {
                        case .user:
                            chatMessages.append(.user(message.content))
                        case .assistant:
                            chatMessages.append(.assistant(message.content))
                        case .system:
                            break
                        }
                    }
                    
                    // Add current user message
                    chatMessages.append(.user(prompt))
                    
                    // Capture for sendable closure
                    let messages = chatMessages
                    
                    // Perform generation
                    try await container.perform { context in
                        var parameters = GenerateParameters()
                        parameters.temperature = 0.7
                        parameters.topP = 0.9
                        parameters.maxTokens = 512
                        
                        // Create user input from chat
                        let userInput = UserInput(chat: messages)
                        let input = try await context.processor.prepare(input: userInput)
                        
                        // Create cache
                        let cache = context.model.newCache(parameters: parameters)
                        
                        // Generate tokens
                        for try await item in try MLXLMCommon.generate(
                            input: input,
                            cache: cache,
                            parameters: parameters,
                            context: context
                        ) {
                            switch item {
                            case .chunk(let string):
                                continuation.yield(string)
                            case .info:
                                break
                            case .toolCall:
                                break
                            }
                        }
                    }
                    
                    isGenerating = false
                    continuation.finish()
                } catch {
                    isGenerating = false
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum LLMError: LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case loadFailed(String)
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Model files not found"
        case .modelNotLoaded:
            return "Model is not loaded"
        case .loadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}
