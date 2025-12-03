//
//  ModelDownloadView.swift
//  Concha AI
//
//  Model download progress screen
//

import SwiftUI

struct ModelDownloadView: View {
    @Environment(AppState.self) private var appState
    @State private var modelService = ModelService.shared
    @State private var showError: Bool = false
    @State private var isAnimating: Bool = false
    @State private var showClearDataConfirm: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 120, height: 120)
                    
                    if modelService.isDownloading {
                        Circle()
                            .trim(from: 0, to: modelService.downloadProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: modelService.downloadProgress)
                    }
                    
                    Image(systemName: modelService.isDownloading ? "arrow.down.circle" : "cpu")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating && modelService.isDownloading ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                // Title and description
                VStack(spacing: 12) {
                    Text(modelService.isDownloading ? "Downloading Model" : "Select AI Model")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(modelService.isDownloading 
                         ? modelService.currentDownloadFile 
                         : "Choose a model to download and run on your device")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Model selection (only show when not downloading)
                if !modelService.isDownloading {
                    VStack(spacing: 12) {
                        ForEach(ModelInfo.availableModels) { model in
                            ModelSelectionCard(
                                model: model,
                                isSelected: modelService.selectedModel.id == model.id,
                                isDownloaded: modelService.isModelDownloaded(model),
                                onSelect: {
                                    modelService.selectModel(model)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                // Model info card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(modelService.modelDisplayName)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Local LLM + Embeddings")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(modelService.modelSize)
                                .font(.headline)
                                .foregroundColor(Color(hex: "e94560"))
                            Text("Total size")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    if modelService.isDownloading {
                        VStack(spacing: 8) {
                            ProgressView(value: modelService.downloadProgress)
                                .tint(Color(hex: "e94560"))
                            
                            Text("\(Int(modelService.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 32)
                
                // Storage info
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.white.opacity(0.5))
                    
                    let availableGB = Double(modelService.checkAvailableStorage()) / 1_000_000_000
                    Text(String(format: "%.1f GB available", availableGB))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Download button
                if !modelService.isDownloading {
                    Button {
                        startDownload()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Model")
                        }
                        .font(.headline)
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
                    .padding(.horizontal, 32)
                }
                
                // Error message
                if let error = modelService.downloadError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "e94560"))
                        
                        Text("Download Failed")
                            .font(.headline)
                            .foregroundColor(Color(hex: "e94560"))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error Details:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        
                        Text("Check Xcode console (⌘⇧Y) for detailed logs")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                        
                        Button {
                            startDownload()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "e94560"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                // Network notice
                VStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .foregroundColor(.white.opacity(0.4))
                    Text("Wi-Fi recommended for download")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
                
                // Clear data button
                Button {
                    showClearDataConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Clear Downloaded Models")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                
                Spacer()
                    .frame(height: 32)
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onChange(of: modelService.isModelDownloaded) { _, isDownloaded in
            if isDownloaded {
                appState.onModelReady()
            }
        }
        .alert("Clear All Model Data", isPresented: $showClearDataConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearModelData()
            }
        } message: {
            Text("This will delete all downloaded model files (~700 MB). You'll need to re-download them to use the app.")
        }
    }
    
    private func startDownload() {
        Task {
            await modelService.downloadModels()
            if modelService.isModelDownloaded {
                appState.onModelReady()
            }
        }
    }
    
    private func clearModelData() {
        print("🗑️  Clearing all model data...")
        modelService.deleteModels()
        print("✅ Model data cleared")
        
        // Reset the download state
        Task {
            // Small delay to ensure file operations complete
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}

// MARK: - Model Selection Card

struct ModelSelectionCard: View {
    let model: ModelInfo
    let isSelected: Bool
    let isDownloaded: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            if !isDownloaded {
                onSelect()
            }
        } label: {
            HStack(spacing: 12) {
                // Selection/Status indicator
                ZStack {
                    if isDownloaded {
                        // Downloaded checkmark
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 24))
                    } else {
                        // Selection indicator
                        Circle()
                            .stroke(
                                isSelected ? Color(hex: "e94560") : Color.white.opacity(0.3),
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color(hex: "e94560"))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)
                            .foregroundColor(isDownloaded ? .white.opacity(0.6) : .white)
                        
                        Spacer()
                        
                        if isDownloaded {
                            Text("Downloaded")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(8)
                        } else {
                            Text(model.size)
                                .font(.caption)
                                .foregroundColor(Color(hex: "e94560"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "e94560").opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    
                    Text(isDownloaded ? "Already installed on this device" : model.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(
                isDownloaded
                    ? Color.white.opacity(0.02)
                    : isSelected
                        ? Color(hex: "e94560").opacity(0.1)
                        : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isDownloaded ? Color.green.opacity(0.3) : isSelected ? Color(hex: "e94560") : Color.white.opacity(0.1),
                        lineWidth: isDownloaded ? 1 : isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDownloaded)
        .opacity(isDownloaded ? 0.7 : 1.0)
    }
}

#Preview {
    ModelDownloadView()
        .environment(AppState())
}

