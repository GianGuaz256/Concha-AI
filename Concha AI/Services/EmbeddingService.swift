//
//  EmbeddingService.swift
//  Concha AI
//
//  Local embeddings generation using simplified hash-based approach for MVP
//

import Foundation

@MainActor
@Observable
class EmbeddingService {
    static let shared = EmbeddingService()
    
    var isLoaded: Bool = false
    var loadError: String?
    
    private let embeddingDimension = 384
    
    private init() {}
    
    // MARK: - Model Loading
    
    func loadModel() async throws {
        // For MVP, we use a deterministic hash-based embedding approach
        // This provides reasonable semantic matching without requiring a neural embedding model
        // A production version would use a proper MLX embedding model
        isLoaded = true
    }
    
    // MARK: - Embedding Generation
    
    func generateEmbedding(for text: String) async -> [Float] {
        return generateSimpleEmbedding(for: text)
    }
    
    private func generateSimpleEmbedding(for text: String) -> [Float] {
        // Normalize text
        let normalizedText = text.lowercased()
            .components(separatedBy: .punctuationCharacters).joined()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        // Create a bag-of-words style embedding with hash bucketing
        var embedding = [Float](repeating: 0, count: embeddingDimension)
        
        // Character n-gram hashing for basic semantic capture
        for word in normalizedText {
            // Word-level hash
            let wordHash = abs(word.hashValue)
            let index = wordHash % embeddingDimension
            embedding[index] += 1.0
            
            // Character 3-grams for partial matching
            if word.count >= 3 {
                for i in 0...(word.count - 3) {
                    let startIndex = word.index(word.startIndex, offsetBy: i)
                    let endIndex = word.index(startIndex, offsetBy: 3)
                    let trigram = String(word[startIndex..<endIndex])
                    let trigramHash = abs(trigram.hashValue)
                    let trigramIndex = trigramHash % embeddingDimension
                    embedding[trigramIndex] += 0.5
                }
            }
        }
        
        // Normalize the embedding vector
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }
        
        return embedding
    }
    
    // MARK: - Similarity
    
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        
        var dotProduct: Float = 0
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magnitudeA += a[i] * a[i]
            magnitudeB += b[i] * b[i]
        }
        
        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        return magnitude > 0 ? dotProduct / magnitude : 0
    }
}
