//
//  AuthService.swift
//  Concha AI
//
//  Keychain-based password authentication with biometric support
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

class AuthService {
    private let serviceName = "com.concha-ai.localchat"
    private let accountName = "userPassword"
    private let biometricEnabledKey = "biometricAuthEnabled"
    
    var hasPassword: Bool {
        return getStoredPasswordHash() != nil
    }
    
    var isBiometricEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: biometricEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: biometricEnabledKey)
        }
    }
    
    // MARK: - Biometric Authentication
    
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func getBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    func authenticateWithBiometrics() async -> Result<Void, BiometricError> {
        guard isBiometricEnabled else {
            return .failure(.notEnabled)
        }
        
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                return .failure(.unavailable(error.localizedDescription))
            }
            return .failure(.unavailable("Biometric authentication is not available"))
        }
        
        let reason = "Unlock Concha AI"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                return .success(())
            } else {
                return .failure(.failed)
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel:
                return .failure(.userCancel)
            case .userFallback:
                return .failure(.userFallback)
            case .biometryNotAvailable:
                return .failure(.unavailable("Biometric authentication is not available"))
            case .biometryNotEnrolled:
                return .failure(.notEnrolled)
            case .biometryLockout:
                return .failure(.lockout)
            default:
                return .failure(.failed)
            }
        } catch {
            return .failure(.failed)
        }
    }
    
    func setPassword(_ password: String) -> Bool {
        let hash = hashPassword(password)
        return storePasswordHash(hash)
    }
    
    func validatePassword(_ password: String) -> Bool {
        guard let storedHash = getStoredPasswordHash() else {
            return false
        }
        let inputHash = hashPassword(password)
        return storedHash == inputHash
    }
    
    func resetApp() {
        // Delete password from keychain
        deletePasswordHash()
        
        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        
        // Clear documents directory (models, database)
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let contents = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for url in contents {
                    try fileManager.removeItem(at: url)
                }
            } catch {
                print("Error clearing documents: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func storePasswordHash(_ hash: String) -> Bool {
        // Delete any existing password first
        deletePasswordHash()
        
        guard let data = hash.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getStoredPasswordHash() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let hash = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return hash
    }
    
    private func deletePasswordHash() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Biometric Types

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }
    
    var iconName: String {
        switch self {
        case .none:
            return "lock"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }
}

enum BiometricError: Error {
    case notEnabled
    case notEnrolled
    case unavailable(String)
    case failed
    case userCancel
    case userFallback
    case lockout
    
    var localizedDescription: String {
        switch self {
        case .notEnabled:
            return "Biometric authentication is not enabled"
        case .notEnrolled:
            return "No biometric data is enrolled on this device"
        case .unavailable(let message):
            return message
        case .failed:
            return "Authentication failed"
        case .userCancel:
            return "Authentication was cancelled"
        case .userFallback:
            return "User chose to enter password"
        case .lockout:
            return "Biometric authentication is locked. Please try again later."
        }
    }
}

