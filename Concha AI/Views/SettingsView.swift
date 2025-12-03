//
//  SettingsView.swift
//  Concha AI
//
//  Settings sheet with TTS toggle and model info
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var ttsService = TTSService.shared
    @State private var modelService = ModelService.shared
    @State private var memoryService = MemoryService.shared
    @State private var chatHistory = ChatHistoryService.shared
    @State private var showLogoutConfirm: Bool = false
    @State private var showClearMemoriesConfirm: Bool = false
    @State private var showDownloadModels: Bool = false
    @State private var modelToDelete: ModelInfo?
    @State private var showClearChatsConfirm: Bool = false
    @State private var authService = AuthService()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0f0f1a")
                    .ignoresSafeArea()
                
                List {
                    // Voice section
                    Section {
                        Toggle(isOn: Binding(
                            get: { ttsService.isEnabled },
                            set: { _ in ttsService.toggle() }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Text-to-Speech")
                                    Text("Read responses aloud")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                        }
                        .tint(Color(hex: "e94560"))
                    } header: {
                        Text("Voice")
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    
                    // Model section
                    Section {
                        HStack {
                            Label {
                                Text("Current Model")
                            } icon: {
                                Image(systemName: "cpu")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                            Spacer()
                            Text(modelService.modelDisplayName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label {
                                Text("Downloaded Models")
                            } icon: {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                            Spacer()
                            Text("\(modelService.downloadedModels.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label {
                                Text("Storage Used")
                            } icon: {
                                Image(systemName: "internaldrive")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                            Spacer()
                            Text(modelService.storageUsed)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label {
                                Text("Inference")
                            } icon: {
                                Image(systemName: "bolt")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                            Spacer()
                            Text("On-device (MLX)")
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            showDownloadModels = true
                        } label: {
                            Label {
                                Text("Download More Models")
                            } icon: {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                        }
                    } header: {
                        Text("Model Info")
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    
                    // Downloaded models management
                    if !modelService.downloadedModels.isEmpty {
                        Section {
                            ForEach(modelService.downloadedModels) { model in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.displayName)
                                            .font(.headline)
                                        Text(model.size)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        modelToDelete = model
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            Text("Downloaded Models")
                        }
                        .listRowBackground(Color(hex: "1a1a2e"))
                    }
                    
                    // Memory section
                    Section {
                        HStack {
                            Label {
                                Text("Saved Memories")
                            } icon: {
                                Image(systemName: "brain")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                            Spacer()
                            Text("\(memoryService.memoryCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            showClearMemoriesConfirm = true
                        } label: {
                            Label {
                                Text("Clear All Memories")
                            } icon: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .foregroundColor(.red)
                        }
                        .disabled(memoryService.memoryCount == 0)
                    } header: {
                        Text("Memory")
                    } footer: {
                        Text("Memories help the AI remember important information from your conversations.")
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    
                    // Privacy section
                    Section {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Privacy")
                                    Text("All data stays on your device")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    } header: {
                        Text("Privacy")
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    
                    // Security section
                    Section {
                        // Biometric authentication toggle
                        if authService.canUseBiometrics() {
                            Toggle(isOn: Binding(
                                get: { authService.isBiometricEnabled },
                                set: { newValue in
                                    authService.isBiometricEnabled = newValue
                                }
                            )) {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(authService.getBiometricType().displayName)
                                        Text("Quick unlock without password")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: authService.getBiometricType().iconName)
                                        .foregroundColor(Color(hex: "e94560"))
                                }
                            }
                            .tint(Color(hex: "e94560"))
                        }
                        
                        Button {
                            showLogoutConfirm = true
                        } label: {
                            Label {
                                Text("Lock App")
                            } icon: {
                                Image(systemName: "lock")
                                    .foregroundColor(Color(hex: "e94560"))
                            }
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        if authService.canUseBiometrics() {
                            Text("Enable \(authService.getBiometricType().displayName) to unlock the app without entering your password.")
                        }
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    
                    // Debug section
                    Section {
                        Button(role: .destructive) {
                            showClearChatsConfirm = true
                        } label: {
                            Label {
                                Text("Clear All Chat History")
                            } icon: {
                                Image(systemName: "trash.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    } header: {
                        Text("Debug")
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                    
                    // About section
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 MVP")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Built with")
                            Spacer()
                            Text("MLX Swift")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("About")
                    }
                    .listRowBackground(Color(hex: "1a1a2e"))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "e94560"))
                }
            }
            .toolbarBackground(Color(hex: "1a1a2e"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("Lock App", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Lock", role: .destructive) {
                dismiss()
                appState.logout()
            }
        } message: {
            Text("You'll need to enter your password to access the app again.")
        }
        .alert("Clear Chat History", isPresented: $showClearChatsConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                chatHistory.resetDatabase()
            }
        } message: {
            Text("This will permanently delete all your chat conversations. This action cannot be undone.")
        }
        .alert("Clear Memories", isPresented: $showClearMemoriesConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                memoryService.deleteAllMemories()
            }
        } message: {
            Text("This will delete all saved memories. This cannot be undone.")
        }
        .alert("Delete Model", isPresented: Binding(
            get: { modelToDelete != nil },
            set: { if !$0 { modelToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    modelService.deleteModel(model)
                    modelToDelete = nil
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("Delete \(model.displayName)? This will free up \(model.size) of storage.")
            }
        }
        .sheet(isPresented: $showDownloadModels) {
            ModelDownloadView()
                .environment(appState)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}

