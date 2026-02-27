//
//  CodexAuthWriter.swift
//  Codex-Account-Manager
//
//  Writes account data to Codex CLI's auth.json file
//

import Foundation

enum CodexAuthWriter {
    
    /// Path to Codex auth.json - uses REAL home directory, not sandbox
    static var codexAuthPath: URL {
        let realHome = ProcessInfo.processInfo.environment["HOME"] ?? "/Users/\(NSUserName())"
        return URL(fileURLWithPath: realHome)
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("auth.json")
    }
    
    /// Structure matching Codex auth.json format
    struct CodexAuthFile: Codable {
        var authMode: String = "chatgpt"
        var openaiApiKey: String? = nil
        var tokens: Tokens
        var lastRefresh: String
        
        enum CodingKeys: String, CodingKey {
            case authMode = "auth_mode"
            case openaiApiKey = "OPENAI_API_KEY"
            case tokens
            case lastRefresh = "last_refresh"
        }
    }
    
    struct Tokens: Codable {
        var idToken: String
        var accessToken: String
        var refreshToken: String
        var accountId: String
        
        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case accountId = "account_id"
        }
    }
    
    /// Write account to Codex auth.json
    static func writeAccount(_ account: Account) throws {
        let authFile = CodexAuthFile(
            tokens: Tokens(
                idToken: account.idToken,
                accessToken: account.accessToken,
                refreshToken: account.refreshToken,
                accountId: account.accountId
            ),
            lastRefresh: ISO8601DateFormatter().string(from: Date())
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(authFile)
        
        // Ensure .codex directory exists
        let codexDir = codexAuthPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
        
        // Write with secure permissions (user read/write only)
        try data.write(to: codexAuthPath, options: .atomic)
        
        // Set file permissions to 0600 (user read/write only)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: codexAuthPath.path
        )
    }
    
    /// Read current Codex auth (for verification)
    static func readCurrentAuth() throws -> CodexAuthFile? {
        guard FileManager.default.fileExists(atPath: codexAuthPath.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: codexAuthPath)
        return try JSONDecoder().decode(CodexAuthFile.self, from: data)
    }
    
    /// Clear Codex auth (logout)
    static func clearAuth() throws {
        guard FileManager.default.fileExists(atPath: codexAuthPath.path) else { return }
        try FileManager.default.removeItem(at: codexAuthPath)
    }
    
    /// Check if Codex auth file exists
    static var hasAuth: Bool {
        FileManager.default.fileExists(atPath: codexAuthPath.path)
    }
    
    /// Get the account ID currently active in Codex
    static var currentAccountId: String? {
        guard let auth = try? readCurrentAuth() else { return nil }
        return auth.tokens.accountId
    }
}
