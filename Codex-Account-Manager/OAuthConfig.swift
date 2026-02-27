//
//  OAuthConfig.swift
//  Codex-Account-Manager
//
//  OpenAI OAuth Configuration
//

import Foundation

enum OAuthConfig {
    static let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let authUrl = "https://auth.openai.com/oauth/authorize"
    static let tokenUrl = "https://auth.openai.com/oauth/token"
    static let logoutUrl = "https://auth.openai.com/logout"
    static let userInfoUrl = "https://api.openai.com/v1/me"
    static let scopes = ["openid", "profile", "email", "offline_access"]
    static let callbackPort: UInt16 = 1455
    static let callbackFallbackPorts: [UInt16] = [1456, 1457, 1458, 1459, 1460]
    static let callbackPath = "/auth/callback"
    static let timeoutSeconds: TimeInterval = 120
}
