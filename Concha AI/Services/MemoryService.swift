//
//  MemoryService.swift
//  Concha AI
//
//  SQLite memory store with RAG retrieval
//

import Foundation

@MainActor
@Observable
class MemoryService {
    static let shared = MemoryService()
    
    private let database = DatabaseManager.shared
    private let embeddingService = EmbeddingService.shared
    
    var memories: [Memory] = []
    var memoryCount: Int { memories.count }
    
    private init() {
        loadMemories()
    }
    
    // MARK: - Memory Operations
    
    func loadMemories() {
        memories = database.getAllMemories()
    }
    
    func saveMemory(text: String) async -> Bool {
        // Generate embedding for the text
        let embedding = await embeddingService.generateEmbedding(for: text)
        
        let memory = Memory(text: text, embedding: embedding)
        
        if database.insertMemory(memory) {
            memories.insert(memory, at: 0)
            return true
        }
        
        return false
    }
    
    func deleteMemory(_ memory: Memory) {
        if database.deleteMemory(id: memory.id) {
            memories.removeAll { $0.id == memory.id }
        }
    }
    
    func deleteAllMemories() {
        if database.deleteAllMemories() {
            memories.removeAll()
        }
    }
    
    // MARK: - RAG Retrieval
    
    func retrieveRelevantMemories(for query: String, topK: Int = 3) async -> [String] {
        guard !memories.isEmpty else { return [] }
        
        // Generate embedding for the query
        let queryEmbedding = await embeddingService.generateEmbedding(for: query)
        
        // Calculate similarity scores for all memories
        var scoredMemories: [(memory: Memory, score: Float)] = []
        
        for memory in memories {
            let score = embeddingService.cosineSimilarity(queryEmbedding, memory.embedding)
            scoredMemories.append((memory, score))
        }
        
        // Sort by score (highest first) and take top K
        scoredMemories.sort { $0.score > $1.score }
        
        // Filter out low-similarity matches (threshold: 0.3)
        let relevantMemories = scoredMemories
            .prefix(topK)
            .filter { $0.score > 0.3 }
            .map { $0.memory.text }
        
        return Array(relevantMemories)
    }
}

