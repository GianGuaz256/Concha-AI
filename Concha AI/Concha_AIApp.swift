//
//  Concha_AIApp.swift
//  Concha AI
//
//  Main app entry point with navigation routing
//

import SwiftUI

@main
struct Concha_AIApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            switch appState.currentScreen {
            case .setPassword:
                SetPasswordView()
                    .transition(.opacity)
            case .login:
                LoginView()
                    .transition(.opacity)
            case .modelDownload:
                ModelDownloadView()
                    .transition(.opacity)
            case .chat:
                ChatView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentScreen)
        .alert("Error", isPresented: Binding(
            get: { appState.showError },
            set: { appState.showError = $0 }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = appState.errorMessage {
                Text(error)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
