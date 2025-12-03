# Concha AI

A native iOS application that runs Large Language Models (LLMs) locally on your device using Apple's MLX framework. Concha AI provides a private, secure, and offline-capable AI chat experience with memory persistence and conversation history.

## Features

- 🧠 **Local LLM Inference** - Run AI models entirely on-device using MLX
- 🔒 **Privacy First** - All data stays on your device with password protection
- 👤 **Biometric Authentication** - Quick unlock with Face ID or Touch ID
- 💾 **Persistent Memory** - Conversation history and context saved locally
- 🎯 **Model Management** - Download and manage multiple AI models
- 🗣️ **Text-to-Speech** - Voice output for AI responses
- 📝 **Chat History** - Organized conversation management
- 🌙 **Dark Mode** - Beautiful dark interface optimized for iOS

## Architecture

### Core Components

```
Concha AI/
├── Models/           # Data models and app state
│   ├── AppState.swift
│   ├── Chat.swift
│   ├── Message.swift
│   ├── Memory.swift
│   └── ModelInfo.swift
├── Services/         # Business logic and external integrations
│   ├── AuthService.swift
│   ├── LLMService.swift
│   ├── ModelService.swift
│   ├── MemoryService.swift
│   ├── EmbeddingService.swift
│   ├── ChatHistoryService.swift
│   └── TTSService.swift
├── Views/            # SwiftUI views
│   ├── LoginView.swift
│   ├── SetPasswordView.swift
│   ├── ModelDownloadView.swift
│   ├── ChatView.swift
│   ├── ChatSidebarView.swift
│   └── SettingsView.swift
└── Utilities/        # Helper classes
    └── DatabaseManager.swift
```

### Key Technologies

- **SwiftUI** - Modern declarative UI framework
- **MLX** - Apple's machine learning framework for efficient on-device inference
- **MLXLLM** - LLM-specific MLX implementations
- **Swift Transformers** - Tokenization and model utilities
- **SQLite** - Local database for chat history and memories

## Screenshots

<!-- Screenshot 1: Chat Interface -->
![Chat Interface](assets/img/screenshot-chat.png)

<!-- Screenshot 2: Model Download -->
![Model Download](assets/img/screenshot-models.png)

<!-- Screenshot 3: Settings -->
![Settings](assets/img/screenshot-settings.png)

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+ (for development)

## Building the Project

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/concha-ai.git
cd concha-ai
```

### 2. Open in Xcode

```bash
open "Concha AI.xcodeproj"
```

### 3. Install Dependencies

Dependencies are managed via Swift Package Manager and will be automatically resolved by Xcode:

- [mlx-swift](https://github.com/ml-explore/mlx-swift) (v0.29.1)
- [mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples) (v2.29.1)
- [swift-transformers](https://github.com/huggingface/swift-transformers) (v1.0.0)
- [swift-jinja](https://github.com/huggingface/swift-jinja) (v2.2.0)
- [swift-collections](https://github.com/apple/swift-collections) (v1.3.0)
- [swift-numerics](https://github.com/apple/swift-numerics) (v1.1.1)
- [GzipSwift](https://github.com/1024jp/GzipSwift) (v6.0.1)

### 4. Build and Run

1. Select your target device or simulator
2. Press `⌘ + R` to build and run
3. On first launch, set up your password
4. Download a model from the model selection screen
5. Start chatting!

## How It Works

1. **Authentication** - Secure password-based access using local keychain storage
2. **Model Download** - Models are downloaded from Hugging Face and stored locally
3. **Inference** - MLX framework runs the model directly on the device's Neural Engine/GPU
4. **Memory System** - Conversations and context are embedded and stored for retrieval
5. **Database** - SQLite manages chat history, messages, and memory vectors

## Configuration

The app uses local storage for all configurations:
- Models are stored in the app's documents directory
- Database is created automatically on first launch
- No external API keys or cloud services required

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Add your license here]

## Acknowledgments

- Built with [MLX](https://github.com/ml-explore/mlx-swift) by Apple's ML Explore team
- Uses models from [Hugging Face](https://huggingface.co/)

---

**Note:** This app requires significant storage space for AI models (typically 2-8GB per model) and performs best on devices with Apple Silicon or recent A-series chips.

