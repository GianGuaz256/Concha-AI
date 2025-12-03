//
//  AppState.swift
//  Concha AI
//
//  Global app state management
//

import Foundation
import SwiftUI

enum AppScreen {
    case setPassword
    case login
    case modelDownload
    case chat
}

@MainActor
@Observable
class AppState {
    var currentScreen: AppScreen = .login
    var isAuthenticated: Bool = false
    var isModelReady: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    
    private let authService = AuthService()
    private let modelService = ModelService.shared
    
    init() {
        checkInitialState()
    }
    
    func checkInitialState() {
        if !authService.hasPassword {
            currentScreen = .setPassword
        } else {
            currentScreen = .login
        }
    }
    
    func onPasswordSet() {
        isAuthenticated = true
        checkModelState()
    }
    
    func onLoginSuccess() {
        isAuthenticated = true
        checkModelState()
    }
    
    func checkModelState() {
        if modelService.isModelDownloaded {
            currentScreen = .chat
            isModelReady = true
        } else {
            currentScreen = .modelDownload
        }
    }
    
    func onModelReady() {
        isModelReady = true
        currentScreen = .chat
    }
    
    func logout() {
        isAuthenticated = false
        currentScreen = .login
    }
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

