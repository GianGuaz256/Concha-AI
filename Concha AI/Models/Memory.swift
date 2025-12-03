//
//  Memory.swift
//  Concha AI
//
//  Memory item model for RAG
//

import Foundation

struct Memory: Identifiable, Codable {
    let id: UUID
    let text: String
    let embedding: [Float]
    let createdAt: Date
    
    init(id: UUID = UUID(), text: String, embedding: [Float], createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.embedding = embedding
        self.createdAt = createdAt
    }
}

