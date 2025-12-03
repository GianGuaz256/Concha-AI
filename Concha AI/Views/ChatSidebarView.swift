//
//  ChatSidebarView.swift
//  Concha AI
//
//  Sidebar with chat history list
//

import SwiftUI

struct ChatSidebarView: View {
    @Binding var isPresented: Bool
    @Binding var selectedChat: Chat?
    
    @State private var chatHistory = ChatHistoryService.shared
    @State private var modelService = ModelService.shared
    @State private var showDeleteConfirm: Bool = false
    @State private var chatToDelete: Chat?
    
    let onNewChat: () -> Void
    let onSelectChat: (Chat) -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "0f0f1a")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Conversations")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(hex: "1a1a2e"))
                
                // New chat button
                Button {
                    onNewChat()
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("New Chat")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Chat list
                if chatHistory.chats.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.2))
                        
                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Start a new chat to begin")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                        
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(chatHistory.chats) { chat in
                                ChatListItem(
                                    chat: chat,
                                    isSelected: selectedChat?.id == chat.id,
                                    onSelect: {
                                        onSelectChat(chat)
                                        isPresented = false
                                    },
                                    onDelete: {
                                        chatToDelete = chat
                                        showDeleteConfirm = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .onAppear {
            // Refresh chat list when sidebar appears
            chatHistory.loadChats()
            print("📚 Sidebar opened - \(chatHistory.chats.count) chats available")
        }
        .alert("Delete Chat", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                chatToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let chat = chatToDelete {
                    chatHistory.deleteChat(chat)
                    if selectedChat?.id == chat.id {
                        selectedChat = nil
                    }
                }
                chatToDelete = nil
            }
        } message: {
            if let chat = chatToDelete {
                Text("Delete \"\(chat.title)\"? This cannot be undone.")
            }
        }
    }
}

// MARK: - Chat List Item

struct ChatListItem: View {
    let chat: Chat
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(chat.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Model badge
                        Text(chat.modelDisplayName)
                            .font(.caption2)
                            .foregroundColor(Color(hex: "e94560"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "e94560").opacity(0.2))
                            .cornerRadius(4)
                        
                        // Message count
                        Text("\(chat.messages.count) messages")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Spacer()
                        
                        // Time ago
                        Text(timeAgo(chat.updatedAt))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                // Delete button
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                isSelected
                    ? Color(hex: "e94560").opacity(0.15)
                    : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color(hex: "e94560") : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        
        if seconds < 60 {
            return "now"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes)m"
        } else if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours)h"
        } else {
            let days = Int(seconds / 86400)
            return "\(days)d"
        }
    }
}

#Preview {
    ChatSidebarView(
        isPresented: .constant(true),
        selectedChat: .constant(nil),
        onNewChat: {},
        onSelectChat: { _ in }
    )
}

