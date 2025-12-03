//
//  LoginView.swift
//  Concha AI
//
//  Returning user login screen
//

import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var failedAttempts: Int = 0
    @State private var showResetConfirm: Bool = false
    @State private var isAnimating: Bool = false
    @State private var isAuthenticating: Bool = false
    
    private let authService = AuthService()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 2).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Text("LocalChat")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Enter your password to continue")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                                .textContentType(.password)
                                .onSubmit { login() }
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .onSubmit { login() }
                        }
                        
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                showError ? Color(hex: "e94560") : Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                    .modifier(ShakeEffect(shakes: showError ? 2 : 0))
                    
                    if showError {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(Color(hex: "e94560"))
                    }
                }
                .padding(.horizontal, 32)
                
                // Biometric button (if enabled)
                if authService.isBiometricEnabled && authService.canUseBiometrics() {
                    Button {
                        Task {
                            await authenticateWithBiometrics()
                        }
                    } label: {
                        HStack {
                            Image(systemName: authService.getBiometricType().iconName)
                                .font(.title2)
                            Text("Use \(authService.getBiometricType().displayName)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(isAuthenticating)
                    .opacity(isAuthenticating ? 0.6 : 1)
                    .padding(.horizontal, 32)
                }
                
                // Login button
                Button {
                    login()
                } label: {
                    Text("Unlock")
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
                .disabled(password.isEmpty)
                .opacity(password.isEmpty ? 0.6 : 1)
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Reset app option
                Button {
                    showResetConfirm = true
                } label: {
                    Text("Forgot password? Reset app")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            isAnimating = true
            
            // Automatically trigger biometric authentication if enabled
            if authService.isBiometricEnabled && authService.canUseBiometrics() {
                Task {
                    await authenticateWithBiometrics()
                }
            }
        }
        .alert("Reset App", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("This will delete all your data including chats, memories, and downloaded models. This cannot be undone.")
        }
    }
    
    private func login() {
        guard !password.isEmpty else { return }
        
        if authService.validatePassword(password) {
            showError = false
            appState.onLoginSuccess()
        } else {
            failedAttempts += 1
            errorMessage = "Incorrect password"
            showError = true
            password = ""
            
            // Reset error after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showError = false
            }
        }
    }
    
    private func authenticateWithBiometrics() async {
        isAuthenticating = true
        
        let result = await authService.authenticateWithBiometrics()
        
        await MainActor.run {
            isAuthenticating = false
            
            switch result {
            case .success:
                showError = false
                appState.onLoginSuccess()
            case .failure(let error):
                // Only show error if it's not a user cancellation or fallback
                switch error {
                case .userCancel, .userFallback:
                    // User cancelled or wants to use password, don't show error
                    break
                default:
                    errorMessage = error.localizedDescription
                    showError = true
                    
                    // Reset error after a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showError = false
                    }
                }
            }
        }
    }
    
    private func resetApp() {
        authService.resetApp()
        ModelService.shared.deleteModels()
        appState.checkInitialState()
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(CGFloat(shakes) * .pi * 2) * 10
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}

