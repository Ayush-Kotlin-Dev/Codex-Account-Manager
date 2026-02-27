//
//  PKCEGenerator.swift
//  Codex-Account-Manager
//
//  PKCE code verifier and challenge generation
//

import Foundation
import CryptoKit

struct PKCEPair {
    let verifier: String
    let challenge: String
}

enum PKCEGenerator {
    
    /// Generate PKCE code verifier and challenge
    static func generate() -> PKCEPair {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(verifier: verifier)
        return PKCEPair(verifier: verifier, challenge: challenge)
    }
    
    /// Generate code verifier (43-128 chars, base64url encoded random bytes)
    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(bytes: bytes)
    }
    
    /// Generate code challenge (SHA256 hash of verifier, base64url encoded)
    private static func generateCodeChallenge(verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return base64URLEncode(bytes: Array(hash))
    }
    
    /// Generate random state for CSRF protection
    static func generateState() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Base64URL encoding (no padding, no = chars)
    private static func base64URLEncode(bytes: [UInt8]) -> String {
        let data = Data(bytes)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
