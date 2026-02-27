//
//  AddAccountSheet.swift
//  Codex-Account-Manager
//
//  Modern OAuth authentication sheet with improved UX
//

import SwiftUI

struct AddAccountSheet: View {
    let onAccountAdded: (Account) -> Void
    
    @StateObject private var oauthService = OAuthService.shared
    @StateObject private var toastManager = ToastManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Content
                VStack(spacing: Theme.Spacing.xl) {
                    Spacer()
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.2), .purple.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: oauthService.isAuthenticating ? "lock.open" : "lock.shield")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(oauthService.isAuthenticating ? Angle(degrees: 360) : Angle(degrees: 0))
                            .animation(.easeInOut(duration: 0.6), value: oauthService.isAuthenticating)
                    }
                    
                    // Title & Description
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(oauthService.isAuthenticating ? "Authenticating..." : "Add OpenAI Account")
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.text)
                        
                        if oauthService.isAuthenticating {
                            VStack(spacing: Theme.Spacing.md) {
                                LoadingView(message: "Waiting for browser authentication...")
                                    .scaleEffect(0.8)
                                
                                Text("Complete the login in your browser")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                        } else {
                            Text("Sign in with your OpenAI account to add it to Codex Account Manager")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                    }
                    
                    // Error
                    if let error = oauthService.authError {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .fill(Color.red.opacity(0.08))
                        )
                    }
                    
                    Spacer()
                    
                    // Action Button
                    if !oauthService.isAuthenticating {
                        VStack(spacing: Theme.Spacing.md) {
                            Button(action: startAuthentication) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "safari")
                                    Text("Open Browser & Sign In")
                                }
                                .font(Theme.Typography.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .frame(maxWidth: 280)
                                .padding(.vertical, Theme.Spacing.md)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            Text("Your credentials are securely stored in Keychain")
                                .font(Theme.Typography.small)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }
                }
                .padding(Theme.Spacing.xl)
            }
        .frame(width: 420, height: 400)
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
