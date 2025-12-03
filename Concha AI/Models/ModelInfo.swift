//
//  ModelInfo.swift
//  Concha AI
//
//  Model information and configuration
//

import Foundation

struct ModelInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let repo: String
    let size: String
    let description: String
    let requiredFiles: [String]
    
    // Available models
    static let availableModels: [ModelInfo] = [
        ModelInfo(
            id: "llama-3.2-1b",
            name: "Llama-3.2-1B-Instruct",
            displayName: "Llama 3.2 1B",
            repo: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            size: "~700 MB",
            description: "Fast and capable, great for most tasks",
            requiredFiles: [
                "README.md",
                "config.json",
                "model.safetensors",
                "model.safetensors.index.json",
                "special_tokens_map.json",
                "tokenizer.json",
                "tokenizer_config.json"
            ]
        ),
        ModelInfo(
            id: "openelm-1.1b",
            name: "OpenELM-1_1B-Instruct",
            displayName: "OpenELM 1.1B",
            repo: "mlx-community/OpenELM-1_1B-Instruct-4bit",
            size: "~650 MB",
            description: "Apple's efficient language model",
            requiredFiles: [
                "README.md",
                "config.json",
                "model.safetensors",
                "model.safetensors.index.json",
                "special_tokens_map.json",
                "tokenizer.json",
                "tokenizer.model",  // SentencePiece tokenizer
                "tokenizer_config.json"
            ]
        )
    ]
}

