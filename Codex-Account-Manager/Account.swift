//
//  Account.swift
//  Codex-Account-Manager
//
//  Account model for storing OpenAI account data
//

import Foundation

struct Account: Identifiable, Codable, Equatable {
    let id: UUID
    var email: String
    var nickname: String?
    var accountId: String
    var planType: String
    var accessToken: String
    var refreshToken: String
    var idToken: String
    var expiresAt: Date
    var addedAt: Date
    var lastUsedAt: Date?
    var rateLimitInfo: RateLimitInfo?
    
    init(
        id: UUID = UUID(),
        email: String,
        nickname: String? = nil,
        accountId: String,
        planType: String,
        accessToken: String,
        refreshToken: String,
        idToken: String,
        expiresAt: Date,
        addedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        rateLimitInfo: RateLimitInfo? = nil
    ) {
        self.id = id
        self.email = email
        self.nickname = nickname
        self.accountId = accountId
        self.planType = planType
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
        self.addedAt = addedAt
        self.lastUsedAt = lastUsedAt
        self.rateLimitInfo = rateLimitInfo
    }
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
    
    var expiresIn: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }
    
    var displayName: String {
        if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nickname
        }
        return email
    }
    
    var planDisplay: String {
        planType.capitalized
    }
    
    var isRateLimited: Bool {
        guard let rateLimit = rateLimitInfo else { return false }
        return rateLimit.remaining <= 0 && rateLimit.resetAt > Date()
    }
}

struct RateLimitInfo: Codable, Equatable {
    let limit: Int
    let remaining: Int
    let resetAt: Date
    let used: Int
    
    var resetIn: TimeInterval {
        resetAt.timeIntervalSinceNow
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let expiresIn: Int
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}
