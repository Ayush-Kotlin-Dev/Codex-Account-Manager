//
//  ContentView.swift
//  Codex-Account-Manager
//
//  Main UI for managing OpenAI accounts and switching between them
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var oauthService = OAuthService.shared
    
    @State private var showingAddAccount = false
    @State private var showingDeleteConfirmation: Account?
    
    var body: some View {
        NavigationStack {
            List {
                // Active Account Section
                if let activeAccount = accountStore.activeAccount {
                    Section("Active Account (Codex)") {
                        AccountRow(
                            account: activeAccount,
                            isActive: true,
                            onActivate: {},
                            onDelete: {}
                        )
                    }
                } else {
                    Section("Active Account (Codex)") {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("No account active in Codex")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // All Accounts Section
                Section("All Accounts") {
                    if accountStore.accounts.isEmpty {
                        ContentUnavailableView {
                            Label("No Accounts", systemImage: "person.crop.circle.badge.xmark")
                        } description: {
                            Text("Add your first OpenAI account to get started")
                        } actions: {
                            Button("Add Account") {
                                showingAddAccount = true
                            }
                        }
                    } else {
                        ForEach(accountStore.accounts) { account in
                            AccountRow(
                                account: account,
                                isActive: account.id == accountStore.activeAccountId,
                                onActivate: {
                                    Task {
                                        await accountStore.activateAccount(id: account.id)
                                    }
                                },
                                onDelete: {
                                    showingDeleteConfirmation = account
                                }
                            )
                        }
                    }
                }
                
                // Quick Actions Section
                if accountStore.accounts.count > 1 {
                    Section("Quick Actions") {
                        Button {
                            Task {
                                await accountStore.switchToNextAvailableAccount()
                            }
                        } label: {
                            Label("Switch to Next Account", systemImage: "arrow.right.circle")
                        }
                        .disabled(accountStore.isLoading)
                    }
                }
            }
            .navigationTitle("Codex Account Manager")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(oauthService.isAuthenticating)
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountView { account in
                    accountStore.addAccount(account)
                    showingAddAccount = false
                    
                    // Auto-activate if it's the first account
                    if accountStore.accounts.count == 1 {
                        Task {
                            await accountStore.activateAccount(id: account.id)
                        }
                    }
                }
            }
            .alert("Delete Account?", isPresented: .constant(showingDeleteConfirmation != nil), presenting: showingDeleteConfirmation) { account in
                Button("Cancel", role: .cancel) {
                    showingDeleteConfirmation = nil
                }
                Button("Delete", role: .destructive) {
                    accountStore.removeAccount(id: account.id)
                    showingDeleteConfirmation = nil
                }
            } message: { account in
                Text("Are you sure you want to remove \(account.email)? This will not affect your Codex CLI until you switch accounts.")
            }
            .alert("Error", isPresented: .constant(accountStore.errorMessage != nil)) {
                Button("OK") {
                    accountStore.errorMessage = nil
                }
            } message: {
                Text(accountStore.errorMessage ?? "")
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: Account
    let isActive: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                if isActive {
                    Circle()
                        .stroke(statusColor, lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Label(account.planDisplay, systemImage: "creditcard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if account.isExpired {
                        Text("Expired")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("Expires in \(formatDuration(account.expiresIn))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button("Activate") {
                    onActivate()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            if !isActive {
                Button {
                    onActivate()
                } label: {
                    Label("Activate", systemImage: "checkmark.circle")
                }
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var statusColor: Color {
        if isActive {
            return .green
        } else if account.isExpired {
            return .red
        } else if account.isRateLimited {
            return .orange
        } else {
            return .gray
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        if hours < 1 {
            let minutes = Int(interval) / 60
            return "\(minutes)m"
        } else if hours < 24 {
            return "\(hours)h"
        } else {
            let days = hours / 24
            return "\(days)d"
        }
    }
}

// MARK: - Add Account View

struct AddAccountView: View {
    let onAccountAdded: (Account) -> Void
    
    @StateObject private var oauthService = OAuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Add OpenAI Account")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if oauthService.isAuthenticating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Waiting for authentication...")
                            .foregroundStyle(.secondary)
                        
                        Text("A browser window has opened. Please complete the login.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Sign in with your OpenAI account to add it to Codex Account Manager.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                
                if let error = oauthService.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                
                Spacer()
                
                if !oauthService.isAuthenticating {
                    Button {
                        startAuthentication()
                    } label: {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open Browser & Sign In")
                        }
                        .frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(width: 400, height: 350)
            .navigationTitle("Add Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(oauthService.isAuthenticating)
                }
            }
        }
    }
    
    private func startAuthentication() {
        Task {
            do {
                let account = try await oauthService.authenticate()
                onAccountAdded(account)
            } catch {
                oauthService.authError = error.localizedDescription
            }
        }
    }
}

#Preview {
    ContentView()
}
