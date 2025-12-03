//
//  ModelService.swift
//  Concha AI
//
//  MLX model download and management
//

import Foundation

@MainActor
@Observable
class ModelService {
    static let shared = ModelService()
    
    // Selected model (defaults to Llama 3.2)
    var selectedModel: ModelInfo = ModelInfo.availableModels[0]
    
    // Computed properties from selected model
    var modelName: String { selectedModel.name }
    var modelDisplayName: String { selectedModel.displayName }
    var modelSize: String { selectedModel.size }
    
    private var modelRepo: String { selectedModel.repo }
    
    // Required files come from the selected model
    private var requiredFiles: [String] {
        selectedModel.requiredFiles
    }
    
    
    // State
    var downloadProgress: Double = 0
    var isDownloading: Bool = false
    var downloadError: String?
    var currentDownloadFile: String = ""
    
    // Storage info
    var storageUsed: String {
        let fileManager = FileManager.default
        guard let modelDir = modelDirectory else { return "0 MB" }
        
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: modelDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    var isModelDownloaded: Bool {
        return isModelDownloaded(selectedModel)
    }
    
    func isModelDownloaded(_ model: ModelInfo) -> Bool {
        guard let modelDir = modelDirectory else { return false }
        let fileManager = FileManager.default
        
        // Check new location first
        var allFilesExist = true
        for file in model.requiredFiles {
            let filePath = modelDir.appendingPathComponent("\(model.id)/\(file)")
            if !fileManager.fileExists(atPath: filePath.path) {
                allFilesExist = false
                break
            }
        }
        
        if allFilesExist {
            return true
        }
        
        // For Llama 3.2, check legacy location (old "llm" folder)
        if model.id == "llama-3.2-1b", let legacyPath = legacyLLMPath {
            var legacyFilesExist = true
            // Check with the old required files list (without tokenizer.model)
            let legacyFiles = [
                "README.md", "config.json", "model.safetensors",
                "model.safetensors.index.json", "special_tokens_map.json",
                "tokenizer.json", "tokenizer_config.json"
            ]
            for file in legacyFiles {
                let filePath = legacyPath.appendingPathComponent(file)
                if !fileManager.fileExists(atPath: filePath.path) {
                    legacyFilesExist = false
                    break
                }
            }
            
            if legacyFilesExist {
                print("📦 Found Llama 3.2 in legacy location, migrating...")
                migrateLegacyModel()
                return true
            }
        }
        
        return false
    }
    
    private func migrateLegacyModel() {
        guard let legacyPath = legacyLLMPath,
              let newPath = modelDirectory?.appendingPathComponent("llama-3.2-1b") else {
            return
        }
        
        let fileManager = FileManager.default
        
        do {
            // Check if legacy path exists
            guard fileManager.fileExists(atPath: legacyPath.path) else {
                print("❌ Legacy path doesn't exist")
                return
            }
            
            // Create new directory if needed
            try fileManager.createDirectory(at: newPath, withIntermediateDirectories: true)
            
            // Move all files from old to new location
            let files = try fileManager.contentsOfDirectory(at: legacyPath, includingPropertiesForKeys: nil)
            for file in files {
                let destination = newPath.appendingPathComponent(file.lastPathComponent)
                
                // Remove destination if it exists
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                
                try fileManager.moveItem(at: file, to: destination)
                print("✓ Migrated: \(file.lastPathComponent)")
            }
            
            // Remove old directory
            try fileManager.removeItem(at: legacyPath)
            print("✅ Migration complete! Removed legacy directory.")
            
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    var downloadedModels: [ModelInfo] {
        ModelInfo.availableModels.filter { isModelDownloaded($0) }
    }
    
    func deleteModel(_ model: ModelInfo) {
        guard let modelDir = modelDirectory else { return }
        let modelPath = modelDir.appendingPathComponent(model.id)
        try? FileManager.default.removeItem(at: modelPath)
        print("🗑️  Deleted model: \(model.displayName)")
    }
    
    var isEmbeddingModelDownloaded: Bool {
        // We use hash-based embeddings, so no download needed
        return true
    }
    
    var modelDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("models")
    }
    
    var llmModelPath: URL? {
        modelDirectory?.appendingPathComponent(selectedModel.id)
    }
    
    private var legacyLLMPath: URL? {
        // Old path before multi-model support
        modelDirectory?.appendingPathComponent("llm")
    }
    
    func selectModel(_ model: ModelInfo) {
        selectedModel = model
        print("📱 Selected model: \(model.displayName)")
    }
    
    private init() {}
    
    // MARK: - Download Methods
    
    func downloadModels() async {
        isDownloading = true
        downloadError = nil
        downloadProgress = 0
        
        print("📥 Starting model download...")
        print("📁 Model directory: \(modelDirectory?.path ?? "unknown")")
        
        do {
            // Create model directories
            print("📁 Creating model directories...")
            try createModelDirectories()
            
            // Download LLM (100% of progress - we're using local embeddings)
            print("🤖 Downloading LLM model from: \(modelRepo)")
            try await downloadLLMModel()
            
            // Note: Using hash-based embeddings instead of downloading a model
            print("🧠 Using local hash-based embeddings (no download needed)")
            downloadProgress = 1.0
            
            isDownloading = false
            print("✅ Model downloaded successfully")
        } catch let error as ModelError {
            let errorMsg = "ModelError: \(error.localizedDescription)"
            print("❌ Download failed: \(errorMsg)")
            downloadError = errorMsg
            isDownloading = false
        } catch let urlError as URLError {
            let errorMsg = "Network Error (\(urlError.code.rawValue)): \(urlError.localizedDescription)"
            print("❌ Download failed: \(errorMsg)")
            downloadError = errorMsg
            isDownloading = false
        } catch {
            let errorMsg = "\(type(of: error)): \(error.localizedDescription)"
            print("❌ Download failed: \(errorMsg)")
            downloadError = errorMsg
            isDownloading = false
        }
    }
    
    private func createModelDirectories() throws {
        let fileManager = FileManager.default
        
        if let llmPath = llmModelPath {
            try fileManager.createDirectory(at: llmPath, withIntermediateDirectories: true)
        }
    }
    
    private func downloadLLMModel() async throws {
        guard let llmPath = llmModelPath else {
            throw ModelError.directoryNotFound
        }
        
        let baseURL = "https://huggingface.co/\(modelRepo)/resolve/main/"
        
        for (index, file) in requiredFiles.enumerated() {
            currentDownloadFile = "LLM: \(file)"
            let fileURL = URL(string: baseURL + file)!
            let destinationURL = llmPath.appendingPathComponent(file)
            
            // Skip if already downloaded
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("⏭️  Skipping \(file) (already exists)")
                downloadProgress = Double(index + 1) / Double(requiredFiles.count)
                continue
            }
            
            print("⬇️  Downloading: \(file) from \(fileURL.absoluteString)")
            try await downloadFile(from: fileURL, to: destinationURL)
            print("✓ Downloaded: \(file)")
            downloadProgress = Double(index + 1) / Double(requiredFiles.count)
        }
    }
    
    
    private func downloadFile(from url: URL, to destination: URL) async throws {
        do {
            // Create URLRequest with proper headers for Hugging Face
            var request = URLRequest(url: url)
            request.setValue("LocalChat/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 60
            
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode) for \(url.lastPathComponent)")
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 401 {
                        print("❌ 401 Unauthorized - Hugging Face may require authentication or model doesn't exist")
                        print("   URL: \(url.absoluteString)")
                    } else if httpResponse.statusCode == 404 {
                        print("❌ 404 Not Found - File doesn't exist at this URL")
                        print("   URL: \(url.absoluteString)")
                    }
                    throw ModelError.downloadFailed
                }
            }
            
            let fileManager = FileManager.default
            
            // Remove existing file if present
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            
            // Move downloaded file to destination
            try fileManager.moveItem(at: tempURL, to: destination)
            
            // Verify file exists
            if fileManager.fileExists(atPath: destination.path) {
                let attrs = try fileManager.attributesOfItem(atPath: destination.path)
                let fileSize = attrs[.size] as? Int64 ?? 0
                print("💾 Saved: \(destination.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
            }
        } catch let error as URLError {
            print("❌ URLError downloading \(url.lastPathComponent): code=\(error.code.rawValue), \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ Error downloading \(url.lastPathComponent): \(error)")
            throw error
        }
    }
    
    func checkAvailableStorage() -> Int64 {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0
        }
        
        do {
            let values = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }
    
    func deleteModels() {
        guard let modelDir = modelDirectory else { return }
        try? FileManager.default.removeItem(at: modelDir)
    }
}

enum ModelError: LocalizedError {
    case directoryNotFound
    case downloadFailed
    case modelCorrupted
    case insufficientStorage
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "Could not find model directory"
        case .downloadFailed:
            return "Failed to download model files"
        case .modelCorrupted:
            return "Model files are corrupted"
        case .insufficientStorage:
            return "Not enough storage space"
        }
    }
}

