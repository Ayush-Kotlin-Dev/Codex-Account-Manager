//
//  JWTDecoder.swift
//  Codex-Account-Manager
//
//  JWT token decoding without verification
//

import Foundation

struct JWTClaims: Codable {
    let sub: String?
    let email: String?
    let exp: Double?
    let iat: Double?
    let iss: String?
    // Note: aud can be String or [String], we ignore it since we don't need it
    
    // OpenAI specific claims
    let openAIAuth: OpenAIAuthClaims?
    let openAIProfile: OpenAIProfileClaims?
    
    enum CodingKeys: String, CodingKey {
        case sub, email, exp, iat, iss
        case openAIAuth = "https://api.openai.com/auth"
        case openAIProfile = "https://api.openai.com/profile"
    }
}

struct OpenAIAuthClaims: Codable {
    let chatgptAccountId: String?
    let chatgptPlanType: String?
    let chatgptUserId: String?
    let organizations: [OpenAIOrganization]?
    
    enum CodingKeys: String, CodingKey {
        case chatgptAccountId = "chatgpt_account_id"
        case chatgptPlanType = "chatgpt_plan_type"
        case chatgptUserId = "chatgpt_user_id"
        case organizations
    }
}

struct OpenAIProfileClaims: Codable {
    let email: String?
    let name: String?
    let picture: String?
}

struct OpenAIOrganization: Codable {
    let id: String?
    let name: String?
    let role: String?
}

struct AccountInfo {
    let accountId: String?
    let planType: String
    let userId: String?
    let email: String?
    let expiresAt: Date?
    
    var isValid: Bool {
        accountId != nil && email != nil
    }
}

enum JWTDecoder {
    
    /// Decode JWT token without verification
    static func decode(token: String) -> JWTClaims? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        let payloadBase64 = String(parts[1])
        guard let payloadData = base64URLDecode(payloadBase64) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(JWTClaims.self, from: payloadData)
        } catch {
            print("[JWTDecoder] Failed to decode: \(error)")
            return nil
        }
    }
    
    /// Extract account info from access token
    static func extractAccountInfo(from token: String) -> AccountInfo? {
        guard let claims = decode(token: token) else { return nil }
        
        let auth = claims.openAIAuth
        let profile = claims.openAIProfile
        
        let expiresAt: Date? = claims.exp.map { Date(timeIntervalSince1970: $0) }
        
        return AccountInfo(
            accountId: auth?.chatgptAccountId,
            planType: auth?.chatgptPlanType ?? "free",
            userId: auth?.chatgptUserId ?? claims.sub,
            email: profile?.email ?? claims.email,
            expiresAt: expiresAt
        )
    }
    
    /// Base64URL decoding (handles padding)
    private static func base64URLDecode(_ base64: String) -> Data? {
        var base64 = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let padding = 4 - (base64.count % 4)
        if padding != 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        
        return Data(base64Encoded: base64)
    }
}
