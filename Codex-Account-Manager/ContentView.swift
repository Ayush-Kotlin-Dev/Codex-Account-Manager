//
//  ContentView.swift
//  Codex-Account-Manager
//
//  Refreshed account manager experience with adaptive split layout,
//  stronger information hierarchy, and one-tap primary actions.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var oauthService = OAuthService.shared
    @StateObject private var toastManager = ToastManager.shared

    @State private var showingAddAccount = false
    @State private var showingDeleteConfirmation = false
    @State private var accountPendingDelete: Account?
    @State private var selectedAccountId: UUID?
    @State private var activatingAccountId: UUID?
    @State private var searchText = ""
    @State private var filter: AccountFilter = .all
    @State private var sort: AccountSort = .recentlyAdded
    @State private var editingAccount: Account?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPane
        }
        .background(Theme.Colors.background)
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddAccount) {
            AddAccountSheet { account in
                handleNewAccount(account)
            }
        }
        .sheet(item: $editingAccount) { account in
            EditAccountSheet(account: account) { updated in
                accountStore.updateAccount(updated)
                toastManager.success("Saved account details")
            }
        }
        .alert("Delete Account?", isPresented: $showingDeleteConfirmation, presenting: accountPendingDelete) { account in
            Button("Cancel", role: .cancel) {
                accountPendingDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteAccount(account)
            }
        } message: { account in
            Text("Remove \(account.email)? This only removes it from this app.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if accountStore.accounts.count > 1 {
                    Button {
                        Task {
                            await accountStore.switchToNextAvailableAccount()
                            toastManager.success("Switched to next account")
                        }
                    } label: {
                        Label("Quick Switch", systemImage: "arrow.left.arrow.right")
                    }
                    .help("Switch to next available account")
                }

                Button {
                    showingAddAccount = true
                } label: {
                    if oauthService.isAuthenticating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Add Account", systemImage: "plus")
                    }
                }
                .disabled(oauthService.isAuthenticating)
            }
        }
        .onAppear {
            if selectedAccountId == nil {
                selectedAccountId = accountStore.activeAccountId ?? accountStore.accounts.first?.id
            }
        }
        .onChange(of: accountStore.accounts) { _, accounts in
            if accounts.isEmpty {
                selectedAccountId = nil
                return
            }
            if selectedAccountId == nil || !accounts.contains(where: { $0.id == selectedAccountId }) {
                selectedAccountId = accountStore.activeAccountId ?? accounts.first?.id
            }
        }
        .toastContainer()
        .frame(minWidth: 780, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            DashboardHeroCard(
                accountCount: accountStore.accounts.count,
                activeAccount: accountStore.activeAccount,
                availableCount: accountStore.availableAccounts.count
            )

            AccountFilterBar(
                searchText: $searchText,
                filter: $filter,
                sort: $sort,
                accountCount: filteredAndSortedAccounts.count
            )

            if filteredAndSortedAccounts.isEmpty {
                EmptyAccountsPanel(
                    hasAnyAccounts: !accountStore.accounts.isEmpty,
                    onAdd: { showingAddAccount = true },
                    onResetFilters: resetFilters
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(filteredAndSortedAccounts) { account in
                            AccountRowCard(
                                account: account,
                                isActive: account.id == accountStore.activeAccountId,
                                isSelected: account.id == selectedAccountId,
                                isActivating: activatingAccountId == account.id,
                                onSelect: {
                                    selectedAccountId = account.id
                                },
                                onActivate: {
                                    Task {
                                        await activateAccount(account)
                                    }
                                },
                                onEdit: {
                                    editingAccount = account
                                },
                                onDelete: {
                                    accountPendingDelete = account
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(.bottom, Theme.Spacing.sm)
                }
            }

            VersionFooter()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selected = selectedAccount {
            AccountDetailPanel(
                account: selected,
                isActive: selected.id == accountStore.activeAccountId,
                onActivate: {
                    Task {
                        await activateAccount(selected)
                    }
                },
                onEdit: {
                    editingAccount = selected
                },
                onDelete: {
                    accountPendingDelete = selected
                    showingDeleteConfirmation = true
                }
            )
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.background)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            EmptyStateView(
                icon: "person.2.slash",
                title: "No Account Selected",
                message: "Select an account from the list to view details and manage session status.",
                actionTitle: accountStore.accounts.isEmpty ? "Add Account" : nil,
                action: accountStore.accounts.isEmpty ? { showingAddAccount = true } : nil
            )
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.background)
        }
    }

    private var selectedAccount: Account? {
        guard let selectedAccountId else { return nil }
        return accountStore.accounts.first { $0.id == selectedAccountId }
    }

    private var filteredAndSortedAccounts: [Account] {
        let searched = accountStore.accounts.filter { account in
            if searchText.isEmpty {
                return true
            }
            let query = searchText.lowercased()
            return account.email.lowercased().contains(query)
                || account.displayName.lowercased().contains(query)
                || account.planDisplay.lowercased().contains(query)
        }

        let filtered = searched.filter { account in
            switch filter {
            case .all:
                return true
            case .active:
                return account.id == accountStore.activeAccountId
            case .available:
                return !account.isExpired && !account.isRateLimited
            case .expired:
                return account.isExpired
            case .rateLimited:
                return account.isRateLimited
            }
        }

        switch sort {
        case .recentlyAdded:
            return filtered.sorted { $0.addedAt > $1.addedAt }
        case .name:
            return filtered.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .expirySoonest:
            return filtered.sorted { $0.expiresAt < $1.expiresAt }
        }
    }

    private func activateAccount(_ account: Account) async {
        activatingAccountId = account.id
        await accountStore.activateAccount(id: account.id)
        activatingAccountId = nil

        if accountStore.errorMessage == nil {
            toastManager.success("Activated \(account.email)")
        } else {
            toastManager.error(accountStore.errorMessage ?? "Failed to activate account")
        }
    }

    private func handleNewAccount(_ account: Account) {
        accountStore.addAccount(account)
        selectedAccountId = account.id
        showingAddAccount = false
        toastManager.success("Account added successfully")

        if accountStore.accounts.count == 1 {
            Task {
                await accountStore.activateAccount(id: account.id)
            }
        }
    }

    private func deleteAccount(_ account: Account) {
        accountStore.removeAccount(id: account.id)
        if selectedAccountId == account.id {
            selectedAccountId = accountStore.activeAccountId ?? accountStore.accounts.first?.id
        }
        accountPendingDelete = nil
        toastManager.info("Account removed")
    }

    private func resetFilters() {
        searchText = ""
        filter = .all
        sort = .recentlyAdded
    }
}

private enum AccountFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case available = "Ready"
    case expired = "Expired"
    case rateLimited = "Limited"

    var id: String { rawValue }
}

private enum AccountSort: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently Added"
    case name = "Name"
    case expirySoonest = "Expiry"

    var id: String { rawValue }
}

private struct DashboardHeroCard: View {
    let accountCount: Int
    let activeAccount: Account?
    let availableCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Codex Account Manager")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Securely switch between OpenAI sessions")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.Gradient.hero)
                    .accessibilityHidden(true)
            }

            HStack(spacing: Theme.Spacing.xs) {
                CapsuleBadge(text: "\(accountCount) total", color: Theme.Colors.brand)
                CapsuleBadge(text: "\(availableCount) ready", color: Theme.Colors.success)
                if activeAccount != nil {
                    CapsuleBadge(text: "active", color: Theme.Colors.success, icon: "checkmark")
                }
            }
        }
        .panelStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct AccountFilterBar: View {
    @Binding var searchText: String
    @Binding var filter: AccountFilter
    @Binding var sort: AccountSort
    let accountCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            TextField("Search by email, name, or plan", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search accounts")

            HStack {
                Picker("Status", selection: $filter) {
                    ForEach(AccountFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sort", selection: $sort) {
                    ForEach(AccountSort.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Text("\(accountCount)")
                    .font(Theme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Colors.elevatedSurface)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(accountCount) accounts shown")
            }
        }
        .panelStyle()
    }
}

private struct AccountRowCard: View {
    let account: Account
    let isActive: Bool
    let isSelected: Bool
    let isActivating: Bool
    let onSelect: () -> Void
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.Spacing.sm) {
                AvatarView(email: account.email, size: 42, isActive: isActive)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(account.displayName)
                        .font(Theme.Typography.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(account.email)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: Theme.Spacing.xxs) {
                        CapsuleBadge(text: account.planDisplay, color: Theme.Colors.info)
                        CapsuleBadge(text: account.statusText, color: account.statusColor, icon: "circle.fill")
                    }
                }

                Spacer(minLength: Theme.Spacing.xs)

                VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.success)
                    } else if isActivating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Activate", action: onActivate)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }

                    Menu {
                        Button("Edit", action: onEdit)
                        if !isActive {
                            Button("Activate", action: onActivate)
                        }
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .interactiveRowStyle(isHighlighted: isSelected || isActive)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens account details")
    }
}

private struct AccountDetailPanel: View {
    let account: Account
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    AvatarView(email: account.email, size: 64, isActive: isActive)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(account.displayName)
                            .font(Theme.Typography.hero)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text(account.email)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        HStack(spacing: Theme.Spacing.xs) {
                            CapsuleBadge(text: account.planDisplay, color: Theme.Colors.info)
                            CapsuleBadge(text: account.statusText, color: account.statusColor, icon: "circle.fill")
                            if isActive {
                                CapsuleBadge(text: "Current Session", color: Theme.Colors.success, icon: "checkmark")
                            }
                        }
                    }

                    Spacer()
                }

                HStack(spacing: Theme.Spacing.sm) {
                    if isActive {
                        Label("Currently Active", systemImage: "checkmark.circle.fill")
                            .font(Theme.Typography.body.weight(.semibold))
                            .foregroundStyle(Theme.Colors.success)
                    } else {
                        Button(action: onActivate) {
                            Label("Activate Account", systemImage: "bolt.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Group {
                    Text("Session")
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    DetailLine(label: "Expires", value: expirationText)
                    DetailLine(label: "Added", value: account.addedAt.formatted(date: .abbreviated, time: .shortened))
                    DetailLine(label: "Last Used", value: account.lastUsedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not yet")
                }

                Group {
                    Text("Identifiers")
                        .font(Theme.Typography.section)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    DetailLine(label: "Account ID", value: account.accountId)
                    DetailLine(label: "Token State", value: account.isExpired ? "Expired" : "Valid")
                }
            }
            .panelStyle()
            .padding(.bottom, Theme.Spacing.md)
        }
        .accessibilityElement(children: .contain)
    }

    private var expirationText: String {
        if account.isExpired {
            return "Expired"
        }

        return account.expiresAt.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct DetailLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typography.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

private struct EmptyAccountsPanel: View {
    let hasAnyAccounts: Bool
    let onAdd: () -> Void
    let onResetFilters: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            EmptyStateView(
                icon: hasAnyAccounts ? "line.3.horizontal.decrease.circle" : "person.crop.circle.badge.plus",
                title: hasAnyAccounts ? "No Matching Accounts" : "No Accounts Yet",
                message: hasAnyAccounts
                    ? "Try clearing your search or filter to see more results."
                    : "Add your first account to manage Codex CLI authentication.",
                actionTitle: hasAnyAccounts ? "Clear Filters" : "Add Account",
                action: hasAnyAccounts ? onResetFilters : onAdd
            )
            .frame(minHeight: 260)
        }
        .panelStyle()
    }
}

private struct EditAccountSheet: View {
    let account: Account
    let onSave: (Account) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String
    @State private var planType: String

    init(account: Account, onSave: @escaping (Account) -> Void) {
        self.account = account
        self.onSave = onSave
        _nickname = State(initialValue: account.nickname ?? "")
        _planType = State(initialValue: account.planType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Display name", text: $nickname)
                        .textContentType(.nickname)

                    TextField("Plan", text: $planType)
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                }

                Section {
                    Text("UX Note: Display name is optional and only affects local UI labeling.")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = account
                        updated.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.planType = planType.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(planType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 320)
    }
}

struct VersionFooter: View {
    var body: some View {
        HStack {
            Spacer()
            Text("Version \(appVersion) (\(buildNumber))")
                .font(Theme.Typography.footnote)
                .foregroundStyle(Theme.Colors.textTertiary)
            Spacer()
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview("Main") {
    ContentView()
}

#Preview("Detail Card") {
    AccountDetailPanel(
        account: .previewActive,
        isActive: true,
        onActivate: {},
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .background(Theme.Colors.background)
}

#Preview("Edit Sheet") {
    EditAccountSheet(account: .previewActive) { _ in }
}

#Preview("Empty State") {
    EmptyAccountsPanel(hasAnyAccounts: false, onAdd: {}, onResetFilters: {})
        .padding()
        .background(Theme.Colors.background)
}

private extension Account {
    static var previewActive: Account {
        Account(
            email: "aya@example.com",
            nickname: "Ayush",
            accountId: "acct_12345",
            planType: "pro",
            accessToken: "token",
            refreshToken: "refresh",
            idToken: "id",
            expiresAt: .now.addingTimeInterval(60 * 60 * 5),
            addedAt: .now.addingTimeInterval(-60 * 60 * 24 * 3),
            lastUsedAt: .now.addingTimeInterval(-60 * 20)
        )
    }
}
