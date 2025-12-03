//
//  SetPasswordView.swift
//  Concha AI
//
//  First-time password setup
//

import SwiftUI

struct SetPasswordView: View {
    @Environment(AppState.self) private var appState
    
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmVisible: Bool = false
    @State private var showBiometricPrompt: Bool = false
    
    private let authService = AuthService()
    
    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    var isValidPassword: Bool {
        password.count >= 4
    }
    
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
                    
                    Text("LocalChat")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Create a password to protect your chats")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                // Password fields
                VStack(spacing: 20) {
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack {
                            if isPasswordVisible {
                                TextField("Enter password", text: $password)
                                    .textContentType(.newPassword)
                            } else {
                                SecureField("Enter password", text: $password)
                                    .textContentType(.newPassword)
                            }
                            
                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        
                        if !password.isEmpty && !isValidPassword {
                            Text("Password must be at least 4 characters")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "e94560"))
                        }
                    }
                    
                    // Confirm password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack {
                            if isConfirmVisible {
                                TextField("Confirm password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            } else {
                                SecureField("Confirm password", text: $confirmPassword)
                                    .textContentType(.newPassword)
                            }
                            
                            Button {
                                isConfirmVisible.toggle()
                            } label: {
                                Image(systemName: isConfirmVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    !confirmPassword.isEmpty && !passwordsMatch
                                    ? Color(hex: "e94560")
                                    : Color.white.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords don't match")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "e94560"))
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                
                // Create password button
                Button {
                    createPassword()
                } label: {
                    Text("Create Password")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: passwordsMatch && isValidPassword
                                    ? [Color(hex: "e94560"), Color(hex: "ff6b6b")]
                                    : [Color.gray, Color.gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(!passwordsMatch || !isValidPassword)
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Privacy note
                VStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.white.opacity(0.4))
                    Text("Your password is stored securely on this device only")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 32)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Enable \(authService.getBiometricType().displayName)?", isPresented: $showBiometricPrompt) {
            Button("Enable") {
                authService.isBiometricEnabled = true
                appState.onPasswordSet()
            }
            Button("Use Password Only") {
                authService.isBiometricEnabled = false
                appState.onPasswordSet()
            }
        } message: {
            Text("Use \(authService.getBiometricType().displayName) to quickly unlock the app without entering your password.")
        }
    }
    
    private func createPassword() {
        guard isValidPassword && passwordsMatch else { return }
        
        if authService.setPassword(password) {
            // Check if biometrics are available
            if authService.canUseBiometrics() {
                showBiometricPrompt = true
            } else {
                appState.onPasswordSet()
            }
        } else {
            errorMessage = "Failed to save password. Please try again."
            showError = true
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SetPasswordView()
        .environment(AppState())
}

