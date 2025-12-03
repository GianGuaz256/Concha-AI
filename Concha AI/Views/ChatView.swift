//
//  ChatView.swift
//  Concha AI
//
//  Main chat interface - Ollama-style
//

import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @State private var llmService = LLMService.shared
    @State private var memoryService = MemoryService.shared
    @State private var ttsService = TTSService.shared
    @State private var chatHistory = ChatHistoryService.shared
    
    @State private var currentChat: Chat?
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var showSettings: Bool = false
    @State private var showMemorySaved: Bool = false
    @State private var scrollToBottom: Bool = false
    @State private var showModelSelector: Bool = false
    @State private var showSidebar: Bool = false
    
    @FocusState private var isInputFocused: Bool
    
    private let modelService = ModelService.shared
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "0f0f1a")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Messages
                messagesView
                
                // Input area
                inputView
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showModelSelector) {
            ModelSelectorSheet(onSelect: { model in
                Task {
                    await switchModel(to: model)
                }
            })
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSidebar) {
            ChatSidebarView(
                isPresented: $showSidebar,
                selectedChat: $currentChat,
                onNewChat: {
                    createNewChat()
                },
                onSelectChat: { chat in
                    loadChat(chat)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .top) {
            if showMemorySaved {
                memorySavedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            await loadModel()
            loadOrCreateChat()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Sidebar toggle
            Button {
                showSidebar = true
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Model selector
            Button {
                if modelService.downloadedModels.count > 1 {
                    showModelSelector = true
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(llmService.isLoaded ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(modelService.modelDisplayName)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if modelService.downloadedModels.count > 1 {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Text("(local)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Memory count
            if memoryService.memoryCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                        .font(.system(size: 12))
                    Text("\(memoryService.memoryCount)")
                        .font(.system(size: 12, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "1a1a2e").opacity(0.8))
    }
    
    // MARK: - Messages
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                onRemember: { saveMemory(message.content) }
                            )
                            .id(message.id)
                        }
                    }
                    
                    // Loading indicator
                    if isLoading && (messages.isEmpty || !messages.last!.isStreaming) {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Color(hex: "e94560"))
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                    }
                    
                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: messages.last?.content) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))
            
            Text("Start a conversation")
                .font(.headline)
                .foregroundColor(.white.opacity(0.4))
            
            Text("Your AI assistant is running entirely on this device. Your conversations are private.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            
            // Quick action button
            Button {
                showSidebar = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sidebar.left")
                    Text("View Chat History")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .frame(minHeight: 300)
    }
    
    // MARK: - Input
    
    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 12) {
                // Text input
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            inputText.isEmpty || isLoading
                            ? AnyShapeStyle(Color.gray)
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        )
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "1a1a2e").opacity(0.95))
        }
    }
    
    // MARK: - Toast
    
    private var memorySavedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Memory saved")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "1a1a2e"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10)
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func loadModel() async {
        isLoading = true
        do {
            try await llmService.loadModel()
            try? await EmbeddingService.shared.loadModel()
        } catch {
            appState.showErrorMessage("Failed to load model: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard llmService.isLoaded else { return }
        
        // Create chat if none exists
        if currentChat == nil {
            createNewChat()
        }
        
        guard let chatId = currentChat?.id else {
            print("❌ No chat ID available")
            return
        }
        
        let userMessage = Message(role: .user, content: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
        messages.append(userMessage)
        
        // Save message to chat
        chatHistory.addMessage(userMessage, to: chatId)
        
        // Refresh current chat reference
        if let updatedChat = chatHistory.chats.first(where: { $0.id == chatId }) {
            currentChat = updatedChat
        }
        
        let prompt = inputText
        inputText = ""
        isInputFocused = false
        
        Task {
            await generateResponse(for: prompt)
        }
    }
    
    private func generateResponse(for prompt: String) async {
        isLoading = true
        
        // Retrieve relevant memories
        let relevantMemories = await memoryService.retrieveRelevantMemories(for: prompt)
        
        // Create assistant message placeholder
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        let messageIndex = messages.count - 1
        
        do {
            // Get message history (excluding the streaming message)
            let history = Array(messages.dropLast())
            
            // Stream the response
            let stream = llmService.generate(
                prompt: prompt,
                memories: relevantMemories,
                history: history
            )
            
            for try await token in stream {
                messages[messageIndex].content += token
            }
            
            // Mark as done streaming
            messages[messageIndex].isStreaming = false
            
            // Save assistant message to chat
            if let chatId = currentChat?.id {
                chatHistory.addMessage(messages[messageIndex], to: chatId)
                
                // Refresh current chat reference to get updated message count
                if let updatedChat = chatHistory.chats.first(where: { $0.id == chatId }) {
                    currentChat = updatedChat
                }
            }
            
            // Speak if TTS is enabled
            if ttsService.isEnabled {
                ttsService.speak(messages[messageIndex].content)
            }
        } catch {
            messages[messageIndex].content = "Sorry, I encountered an error: \(error.localizedDescription)"
            messages[messageIndex].isStreaming = false
            
            // Save error message to chat
            if let chatId = currentChat?.id {
                chatHistory.addMessage(messages[messageIndex], to: chatId)
            }
        }
        
        isLoading = false
    }
    
    private func saveMemory(_ text: String) {
        Task {
            let success = await memoryService.saveMemory(text: text)
            if success {
                withAnimation {
                    showMemorySaved = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showMemorySaved = false
                    }
                }
            }
        }
    }
    
    private func switchModel(to model: ModelInfo) async {
        print("🔄 Switching to model: \(model.displayName)")
        
        // Unload current model
        llmService.unloadModel()
        
        // Select new model
        modelService.selectModel(model)
        
        // Load new model
        do {
            try await llmService.loadModel()
            print("✅ Model switched successfully")
        } catch {
            print("❌ Failed to switch model: \(error)")
            appState.showErrorMessage("Failed to load \(model.displayName)")
        }
    }
    
    private func loadOrCreateChat() {
        // Refresh chat list from database first
        chatHistory.loadChats()
        
        print("🔍 loadOrCreateChat called - found \(chatHistory.chats.count) existing chats")
        
        // Load the most recent chat if available, otherwise start with empty state
        if let recentChat = chatHistory.chats.first {
            loadChat(recentChat)
        } else {
            // Don't auto-create a chat - let user create one when they send first message
            print("📭 No existing chats - waiting for user to start conversation")
        }
    }
    
    private func createNewChat() {
        print("🆕 Creating new chat with model: \(modelService.selectedModel.id)")
        
        let chat = chatHistory.createNewChat(modelId: modelService.selectedModel.id)
        currentChat = chat
        messages = []
        
        // Verify chat was created and persisted
        chatHistory.loadChats()
        if let persistedChat = chatHistory.chats.first(where: { $0.id == chat.id }) {
            currentChat = persistedChat
            print("✅ New chat created and verified: \(chat.id)")
        } else {
            print("❌ Failed to verify new chat in database - but keeping reference")
            // Keep the chat object even if not found in database immediately
        }
    }
    
    private func loadChat(_ chat: Chat) {
        // Reload from database to ensure we have the latest messages
        chatHistory.loadChats()
        
        guard let freshChat = chatHistory.chats.first(where: { $0.id == chat.id }) else {
            print("❌ Chat not found: \(chat.id)")
            return
        }
        
        currentChat = freshChat
        messages = freshChat.messages
        
        // Switch to the chat's model if different
        if freshChat.modelId != modelService.selectedModel.id {
            if let chatModel = ModelInfo.availableModels.first(where: { $0.id == freshChat.modelId }) {
                Task {
                    await switchModel(to: chatModel)
                }
            }
        }
        
        print("📖 Loaded chat: \(freshChat.title) with \(freshChat.messages.count) messages")
    }
}

// MARK: - Model Selector Sheet

struct ModelSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ModelInfo) -> Void
    
    @State private var modelService = ModelService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0f0f1a")
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    if modelService.downloadedModels.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "cpu")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No models downloaded")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    } else {
                        List {
                            ForEach(modelService.downloadedModels) { model in
                                Button {
                                    onSelect(model)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(model.displayName)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text(model.description)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        
                                        Spacer()
                                        
                                        if modelService.selectedModel.id == model.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(hex: "e94560"))
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(Color(hex: "1a1a2e"))
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Switch Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "e94560"))
                }
            }
            .toolbarBackground(Color(hex: "1a1a2e"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let onRemember: () -> Void
    
    @State private var showContextMenu: Bool = false
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isUser ? .white : .white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isUser
                        ? LinearGradient(
                            colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color(hex: "2a2a4a"), Color(hex: "2a2a4a")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            onRemember()
                        } label: {
                            Label("Remember this", systemImage: "brain")
                        }
                    }
                
                if message.isStreaming {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "e94560")).frame(width: 4, height: 4)
                        Circle().fill(Color(hex: "e94560").opacity(0.6)).frame(width: 4, height: 4)
                        Circle().fill(Color(hex: "e94560").opacity(0.3)).frame(width: 4, height: 4)
                    }
                    .padding(.leading, 8)
                }
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ChatView()
        .environment(AppState())
}

