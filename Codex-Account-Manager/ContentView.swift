//
//  ContentView.swift
//  Codex-Account-Manager
//
//  Modern UI for managing OpenAI accounts with card-based design
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var oauthService = OAuthService.shared
    @StateObject private var toastManager = ToastManager.shared
    
    @State private var showingAddAccount = false
    @State private var showingDeleteConfirmation: Account?
    @State private var hoveredAccountId: UUID?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Header Card
                    HeaderCard(
                        accountCount: accountStore.accounts.count,
                        activeAccount: accountStore.activeAccount
                    )
                    
                    // Active Account Section
                    if let activeAccount = accountStore.activeAccount {
                        ActiveAccountCard(account: activeAccount)
                    }
                    
                    // Accounts Grid
                    if accountStore.accounts.isEmpty {
                        EmptyStateView(
                            icon: "person.crop.circle.badge.plus",
                            title: "No Accounts Yet",
                            message: "Add your first OpenAI account to start managing your Codex CLI access",
                            actionTitle: "Add Account",
                            action: { showingAddAccount = true }
                        )
                        .frame(height: 300)
                    } else {
                        AccountsSection(
                            accounts: accountStore.accounts,
                            activeAccountId: accountStore.activeAccountId,
                            hoveredAccountId: $hoveredAccountId,
                            onActivate: { account in
                                Task {
                                    await activateAccount(account)
                                }
                            },
                            onDelete: { account in
                                showingDeleteConfirmation = account
                            }
                        )
                    }
                    
                    // Quick Actions
                    if accountStore.accounts.count > 1 {
                        QuickActionsCard {
                            Task {
                                await accountStore.switchToNextAvailableAccount()
                                toastManager.success("Switched to next account")
                            }
                        }
                    }

                    // Version Footer
                    VersionFooter()
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Codex Account Manager")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AddAccountButton(isLoading: oauthService.isAuthenticating) {
                        showingAddAccount = true
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                AddAccountSheet { account in
                    handleNewAccount(account)
                }
            }
            .alert("Delete Account?", isPresented: .constant(showingDeleteConfirmation != nil), presenting: showingDeleteConfirmation) { account in
                Button("Cancel", role: .cancel) {
                    showingDeleteConfirmation = nil
                }
                Button("Delete", role: .destructive) {
                    deleteAccount(account)
                }
            } message: { account in
                Text("Remove \(account.email)? This won't affect your OpenAI account, only removes it from this app.")
            }
            .toastContainer()
        }
        .frame(minWidth: 520, minHeight: 500)
    }
    
    private func activateAccount(_ account: Account) async {
        await accountStore.activateAccount(id: account.id)
        if accountStore.errorMessage == nil {
            toastManager.success("Activated \(account.email)")
        } else {
            toastManager.error(accountStore.errorMessage ?? "Failed to activate account")
        }
    }
    
    private func handleNewAccount(_ account: Account) {
        accountStore.addAccount(account)
        showingAddAccount = false
        toastManager.success("Account added successfully")
        
        // Auto-activate if it's the first account
        if accountStore.accounts.count == 1 {
            Task {
                await accountStore.activateAccount(id: account.id)
            }
        }
    }
    
    private func deleteAccount(_ account: Account) {
        accountStore.removeAccount(id: account.id)
        showingDeleteConfirmation = nil
        toastManager.info("Account removed")
    }
}

// MARK: - Header Card

struct HeaderCard: View {
    let accountCount: Int
    let activeAccount: Account?
    
    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Account Manager")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.text)
                
                HStack(spacing: Theme.Spacing.sm) {
                    StatusPill(
                        text: "\(accountCount) account" + (accountCount == 1 ? "" : "s"),
                        color: .blue
                    )
                    
                    if activeAccount != nil {
                        StatusPill(
                            text: "Active",
                            color: .green,
                            icon: "checkmark"
                        )
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(Theme.Typography.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Active Account Card

struct ActiveAccountCard: View {
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label("Currently Active", systemImage: "checkmark.seal.fill")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.green)
                
                Spacer()
            }
            
            HStack(spacing: Theme.Spacing.md) {
                AvatarView(email: account.email, size: 48, isActive: true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Colors.text)
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(account.planDisplay)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                        
                        Text("•")
                            .foregroundStyle(Theme.Colors.tertiaryText)
                        
                        if account.isExpired {
                            Text("Session expired")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Expires in \(formatDuration(account.expiresIn))")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Gradients.success.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                )
        )
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

// MARK: - Accounts Section

struct AccountsSection: View {
    let accounts: [Account]
    let activeAccountId: UUID?
    @Binding var hoveredAccountId: UUID?
    let onActivate: (Account) -> Void
    let onDelete: (Account) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("All Accounts")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)
            
            LazyVStack(spacing: Theme.Spacing.md) {
                ForEach(accounts) { account in
                    AccountCard(
                        account: account,
                        isActive: account.id == activeAccountId,
                        isHovered: hoveredAccountId == account.id,
                        onActivate: { onActivate(account) },
                        onDelete: { onDelete(account) }
                    )
                    .onHover { hovering in
                        withAnimation(Theme.Animation.fast) {
                            hoveredAccountId = hovering ? account.id : nil
                        }
                    }
                }
            }
        }
    }
}

struct AccountCard: View {
    let account: Account
    let isActive: Bool
    let isHovered: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void
    
    var status: StatusIndicator.Status {
        if isActive { return .active }
        if account.isExpired { return .expired }
        if account.isRateLimited { return .rateLimited }
        return .inactive
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarView(email: account.email, size: 40, isActive: isActive)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.text)
                
                HStack(spacing: Theme.Spacing.sm) {
                    Text(account.planDisplay)
                        .font(Theme.Typography.small)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    
                    StatusBadge(account: account)
                }
            }
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: onActivate) {
                    Text("Activate")
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(
                            isActive ? Color.green.opacity(0.4) : Theme.Colors.divider,
                            lineWidth: isActive ? 2 : 0.5
                        )
                )
        )
        .shadow(
            color: isHovered ? .black.opacity(0.08) : .clear,
            radius: isHovered ? 8 : 0,
            x: 0,
            y: isHovered ? 4 : 0
        )
        .contentShape(Rectangle())
        .contextMenu {
            if !isActive {
                Button(action: onActivate) {
                    Label("Activate", systemImage: "checkmark.circle")
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
        .animation(Theme.Animation.fast, value: isHovered)
        .animation(Theme.Animation.normal, value: isActive)
    }
}

struct StatusBadge: View {
    let account: Account
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: statusIcon)
                .font(.system(size: 8))
            Text(statusText)
        }
        .font(Theme.Typography.small)
        .foregroundStyle(statusColor)
    }
    
    private var statusColor: Color {
        if account.isExpired { return .red }
        if account.isRateLimited { return .orange }
        return .green
    }
    
    private var statusIcon: String {
        if account.isExpired { return "xmark" }
        if account.isRateLimited { return "exclamationmark" }
        return "checkmark"
    }
    
    private var statusText: String {
        if account.isExpired { return "Expired" }
        if account.isRateLimited { return "Limited" }
        return "Ready"
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    let onSwitch: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "arrow.right.arrow.left.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick Switch")
                    .font(Theme.Typography.body)
                    .fontWeight(.medium)
                
                Text("Instantly switch to the next available account")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            Button(action: onSwitch) {
                Label("Switch", systemImage: "arrow.right")
                    .font(Theme.Typography.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.Colors.secondaryBackground)
        )
    }
}

// MARK: - Add Account Button

struct AddAccountButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "plus")
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Version Footer

struct VersionFooter: View {
    var body: some View {
        HStack {
            Spacer()

            VStack(spacing: 2) {
                Text("Codex Account Manager")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Text("Version \(appVersion) (Build \(buildNumber))")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    ContentView()
}
