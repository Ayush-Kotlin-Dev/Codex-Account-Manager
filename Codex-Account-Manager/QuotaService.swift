//
//  QuotaService.swift
//  Codex-Account-Manager
//
//  Fetches usage quota from the ChatGPT wham/usage API.
//

import Foundation

// MARK: - API Response Models

struct QuotaUsageResponse: Decodable {
    let rateLimit: RateLimitData?
    let planType: String?

    enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
        case planType = "plan_type"
    }
}

struct RateLimitData: Decodable {
    let primaryWindow: PrimaryWindowData?
    let limitReached: Bool?
    let allowed: Bool?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case limitReached = "limit_reached"
        case allowed
    }
}

struct PrimaryWindowData: Decodable {
    let usedPercent: Double?
    let limitWindowSeconds: Double?
    let resetAfterSeconds: Double?
    let resetAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }
}

// MARK: - Quota Info Model

struct QuotaInfo: Codable, Equatable {
    /// Usage percentage (0–100)
    let usedPercent: Double
    /// Remaining quota percentage (0–100)
    let remaining: Double
    /// Whether the rate limit has been reached
    let limitReached: Bool
    /// Whether API calls are still allowed
    let allowed: Bool
    /// When the quota resets (nil if unknown)
    let resetAt: Date?
    /// Seconds until next reset (nil if unknown)
    let resetAfterSeconds: Double?
    /// Plan type reported by the API
    let planType: String?
    /// When this quota info was last fetched
    let lastFetched: Date

    var resetInMinutes: Int? {
        guard let secs = resetAfterSeconds else { return nil }
        return Int(secs / 60)
    }

    /// A user-facing summary of remaining quota, e.g. "72% remaining"
    var remainingText: String {
        return String(format: "%.0f%% remaining", remaining)
    }

    /// A user-facing description of when the quota resets
    var resetText: String? {
        guard let minutes = resetInMinutes else { return nil }
        if minutes < 60 {
            return "Resets in \(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "Resets in \(hours)h \(mins)m" : "Resets in \(hours)h"
        }
    }
}

// MARK: - Quota Service

/// Fetches usage quota from the ChatGPT /wham/usage API.
actor QuotaService {
    static let shared = QuotaService()

    private let chatGPTAPIBase = "https://chatgpt.com/backend-api"

    private init() {}

    /// Fetch quota for a specific account using its access token and account ID.
    /// - Parameters:
    ///   - accessToken: The account's current OAuth access token.
    ///   - accountId: The ChatGPT account ID.
    /// - Returns: A `QuotaInfo` object with usage details.
    func fetchQuota(accessToken: String, accountId: String) async throws -> QuotaInfo {
        guard let url = URL(string: "\(chatGPTAPIBase)/wham/usage") else {
            throw QuotaError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw QuotaError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(QuotaUsageResponse.self, from: data)
        return makeQuotaInfo(from: decoded)
    }

    // MARK: - Private Helpers

    private func makeQuotaInfo(from response: QuotaUsageResponse) -> QuotaInfo {
        let primaryWindow = response.rateLimit?.primaryWindow
        let usedPercent = primaryWindow?.usedPercent ?? 0
        let remaining = max(0, 100 - usedPercent)
        let limitReached = response.rateLimit?.limitReached ?? false
        let allowed = response.rateLimit?.allowed ?? true

        var resetAt: Date?
        if let resetEpoch = primaryWindow?.resetAt, resetEpoch > 0 {
            resetAt = Date(timeIntervalSince1970: resetEpoch)
        }

        return QuotaInfo(
            usedPercent: usedPercent,
            remaining: remaining,
            limitReached: limitReached,
            allowed: allowed,
            resetAt: resetAt,
            resetAfterSeconds: primaryWindow?.resetAfterSeconds,
            planType: response.planType,
            lastFetched: Date()
        )
    }
}

// MARK: - Quota Errors

enum QuotaError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid quota API URL"
        case .invalidResponse:
            return "Invalid response from quota API"
        case .httpError(let code, _):
            return "Quota API returned HTTP \(code)"
        case .decodingFailed:
            return "Failed to decode quota response"
        }
    }
}
