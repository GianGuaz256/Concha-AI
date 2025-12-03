//
//  Chat.swift
//  Concha AI
//
//  Chat conversation model
//

import Foundation

struct Chat: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var modelId: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), title: String = "New Chat", modelId: String, messages: [Message] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.modelId = modelId
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var preview: String {
        if let lastMessage = messages.last(where: { $0.role == .user }) {
            return lastMessage.content
        }
        return "No messages yet"
    }
    
    var modelDisplayName: String {
        ModelInfo.availableModels.first(where: { $0.id == modelId })?.displayName ?? "Unknown Model"
    }
}

