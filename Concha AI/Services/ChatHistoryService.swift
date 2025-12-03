//
//  ChatHistoryService.swift
//  Concha AI
//
//  Chat history management with SQLite storage
//

import Foundation

@MainActor
@Observable
class ChatHistoryService {
    static let shared = ChatHistoryService()
    
    private let database = DatabaseManager.shared
    
    var chats: [Chat] = []
    var currentChat: Chat?
    
    private init() {
        loadChats()
    }
    
    // MARK: - Chat Operations
    
    func loadChats() {
        print("🔄 Loading chats from database...")
        chats = database.getAllChats()
        print("📚 Loaded \(chats.count) chats from database")
        
        if chats.isEmpty {
            print("⚠️ No chats found in database")
        } else {
            for (index, chat) in chats.enumerated() {
                print("  \(index + 1). \(chat.title) - \(chat.messages.count) messages")
            }
        }
    }
    
    func createNewChat(modelId: String) -> Chat {
        let chat = Chat(modelId: modelId)
        
        if database.insertChat(chat) {
            chats.insert(chat, at: 0)
            currentChat = chat
            print("✨ Created new chat: \(chat.id)")
        }
        
        return chat
    }
    
    func selectChat(_ chat: Chat) {
        currentChat = chat
        print("📖 Selected chat: \(chat.title)")
    }
    
    func updateChatTitle(_ chat: Chat, newTitle: String) {
        guard let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        
        var updatedChat = chat
        updatedChat.title = newTitle
        updatedChat.updatedAt = Date()
        
        if database.updateChat(updatedChat) {
            chats[index] = updatedChat
            if currentChat?.id == chat.id {
                currentChat = updatedChat
            }
        }
    }
    
    func deleteChat(_ chat: Chat) {
        if database.deleteChat(id: chat.id) {
            chats.removeAll { $0.id == chat.id }
            if currentChat?.id == chat.id {
                currentChat = nil
            }
            print("🗑️ Deleted chat: \(chat.title)")
        }
    }
    
    func addMessage(_ message: Message, to chatId: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else {
            print("⚠️ Chat not found for message: \(chatId)")
            return
        }
        
        // Save message to database
        if database.insertMessage(message, chatId: chatId) {
            // Update chat with new message
            chats[index].messages.append(message)
            chats[index].updatedAt = Date()
            
            // Auto-generate title from first user message
            if chats[index].messages.filter({ $0.role == .user }).count == 1 && message.role == .user {
                let title = generateTitle(from: message.content)
                chats[index].title = title
                _ = database.updateChat(chats[index])
            } else {
                _ = database.updateChat(chats[index])
            }
            
            // Update currentChat reference
            if currentChat?.id == chatId {
                currentChat = chats[index]
            }
            
            print("💬 Added message to chat \(chats[index].title): \(message.role) - \(message.content.prefix(30))...")
        } else {
            print("❌ Failed to save message to database")
        }
    }
    
    func updateMessageContent(_ message: Message, newContent: String, in chat: Chat) {
        guard let chatIndex = chats.firstIndex(where: { $0.id == chat.id }),
              let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }
        
        var updatedMessage = message
        updatedMessage.content = newContent
        
        chats[chatIndex].messages[messageIndex] = updatedMessage
        chats[chatIndex].updatedAt = Date()
        
        if currentChat?.id == chat.id {
            currentChat = chats[chatIndex]
        }
    }
    
    private func generateTitle(from text: String) -> String {
        let words = text.split(separator: " ").prefix(6)
        var title = words.joined(separator: " ")
        if text.split(separator: " ").count > 6 {
            title += "..."
        }
        return title.isEmpty ? "New Chat" : title
    }
    
    func deleteAllChats() {
        database.clearAllChats()
        chats.removeAll()
        currentChat = nil
        print("🗑️ All chats deleted")
    }
    
    func resetDatabase() {
        print("🔄 Resetting database...")
        database.clearAllChats()
        chats.removeAll()
        currentChat = nil
        print("✅ Database reset complete")
    }
}

