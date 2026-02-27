//
//  AddAccountSheet.swift
//  Codex-Account-Manager
//
//  OAuth authentication sheet with clear state feedback.
//

import SwiftUI

struct AddAccountSheet: View {
    let onAccountAdded: (Account) -> Void

    @StateObject private var oauthService = OAuthService.shared
    @StateObject private var toastManager = ToastManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: Theme.Spacing.sm)

                ZStack {
                    Circle()
                        .fill(Theme.Gradient.hero.opacity(0.16))
                        .frame(width: 104, height: 104)

                    if oauthService.isAuthenticating {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Theme.Colors.brand)
                    } else {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(Theme.Gradient.hero)
                    }
                }
                .accessibilityHidden(true)

                VStack(spacing: Theme.Spacing.xs) {
                    Text(oauthService.isAuthenticating ? "Authenticating" : "Add OpenAI Account")
                        .font(Theme.Typography.title)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(
                        oauthService.isAuthenticating
                        ? "Finish sign-in in your browser. This screen updates automatically."
                        : "Sign in with OpenAI to add an account for Codex CLI session switching."
                    )
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                }

                if oauthService.isAuthenticating {
                    LoadingView(message: "Waiting for authentication callback...")
                        .frame(maxWidth: .infinity)
                        .panelStyle()
                }

                if let error = oauthService.authError {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Colors.error)

                        Text(error)
                            .font(Theme.Typography.footnote)
                            .foregroundStyle(Theme.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.Colors.error.opacity(0.1))
                    )
                    .accessibilityLabel("Authentication error: \(error)")
                }

                Spacer()

                VStack(spacing: Theme.Spacing.xs) {
                    Button(action: startAuthentication) {
                        Label(
                            oauthService.isAuthenticating ? "Opening Browser" : "Open Browser & Sign In",
                            systemImage: "safari"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(oauthService.isAuthenticating)

                    Text("Credentials are saved securely in Keychain.")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.background)
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
        .frame(minWidth: 500, minHeight: 500)
    }

    private func startAuthentication() {
        Task {
            do {
                let account = try await oauthService.authenticate()
                await MainActor.run {
                    onAccountAdded(account)
                    toastManager.success("Welcome, \(account.email)")
                }
            } catch {
                await MainActor.run {
                    oauthService.authError = error.localizedDescription
                    toastManager.error("Authentication failed")
                }
            }
        }
    }
}

#Preview {
    AddAccountSheet { _ in }
}
