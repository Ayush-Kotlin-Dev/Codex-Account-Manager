//
//  AccountStore.swift
//  Codex-Account-Manager
//
//  Manages account storage and persistence
//

import Foundation
import Combine

@MainActor
class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var activeAccountId: UUID?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storageFile: URL
    private let fileManager = FileManager.default
    
    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CodexAccountManager", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        self.storageFile = appDir.appendingPathComponent("accounts.json")
        loadAccounts()
    }
    
    // MARK: - Account Management
    
    func addAccount(_ account: Account) {
        // Remove existing account with same email
        accounts.removeAll { $0.email == account.email }
        accounts.append(account)
        saveAccounts()
        
        // Auto-set as active if first account
        if accounts.count == 1 {
            setActiveAccount(account.id)
        }
    }
    
    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        
        // Clear active if removed
        if activeAccountId == id {
            activeAccountId = accounts.first?.id
            if let newActiveId = activeAccountId {
                Task {
                    await activateAccount(id: newActiveId)
                }
            }
        }
        
        saveAccounts()
    }
    
    func updateAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        }
    }
    
    func setActiveAccount(_ id: UUID?) {
        activeAccountId = id
    }
    
    // MARK: - Codex Integration
    
    func activateAccount(id: UUID) async {
        guard let account = accounts.first(where: { $0.id == id }) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Check if token needs refresh
            var workingAccount = account
            if account.isExpired {
                workingAccount = try await refreshAccountIfNeeded(account)
            }
            
            // Write to Codex auth.json
            try CodexAuthWriter.writeAccount(workingAccount)
            
            // Update last used
            var updated = workingAccount
            updated.lastUsedAt = Date()
            updateAccount(updated)
            
            setActiveAccount(id)
            errorMessage = nil
            
        } catch {
            errorMessage = "Failed to activate account: \(error.localizedDescription)"
        }
    }
    
    func refreshAccountIfNeeded(_ account: Account) async throws -> Account {
        guard account.isExpired else { return account }
        
        let refreshed = try await OAuthService.shared.refreshAccessToken(
            refreshToken: account.refreshToken
        )
        
        guard let accountInfo = JWTDecoder.extractAccountInfo(from: refreshed.accessToken) else {
            throw OAuthError.invalidToken
        }
        
        var updated = account
        updated.accessToken = refreshed.accessToken
        updated.refreshToken = refreshed.refreshToken ?? account.refreshToken
        updated.expiresAt = accountInfo.expiresAt ?? Date().addingTimeInterval(TimeInterval(refreshed.expiresIn))
        
        updateAccount(updated)
        return updated
    }
    
    func switchToNextAvailableAccount() async {
        guard let currentId = activeAccountId else { return }
        
        let currentIndex = accounts.firstIndex { $0.id == currentId } ?? 0
        let nextIndex = (currentIndex + 1) % accounts.count
        let nextAccount = accounts[nextIndex]
        
        await activateAccount(id: nextAccount.id)
    }
    
    // MARK: - Persistence
    
    private func loadAccounts() {
        guard let data = try? Data(contentsOf: storageFile) else { return }
        
        do {
            let container = try JSONDecoder().decode(AccountStorage.self, from: data)
            self.accounts = container.accounts
            self.activeAccountId = container.activeAccountId
        } catch {
            print("[AccountStore] Failed to load accounts: \(error)")
        }
    }
    
    private func saveAccounts() {
        let container = AccountStorage(
            accounts: accounts,
            activeAccountId: activeAccountId
        )
        
        do {
            let data = try JSONEncoder().encode(container)
            try data.write(to: storageFile, options: .atomic)
        } catch {
            print("[AccountStore] Failed to save accounts: \(error)")
        }
    }
    
    var activeAccount: Account? {
        accounts.first { $0.id == activeAccountId }
    }
    
    var availableAccounts: [Account] {
        accounts.filter { !$0.isRateLimited && !$0.isExpired }
    }
}

// MARK: - Storage Container

private struct AccountStorage: Codable {
    let accounts: [Account]
    let activeAccountId: UUID?
}

enum OAuthError: Error, LocalizedError {
    case invalidToken
    case serverError(String)
    case networkError(Error)
    case invalidResponse
    case portInUse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Invalid or expired token"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .portInUse:
            return "Callback port already in use"
        case .timeout:
            return "Authentication timeout"
        }
    }
}
