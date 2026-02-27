//
//  OAuthService.swift
//  Codex-Account-Manager
//
//  OAuth 2.0 with PKCE implementation including local HTTP callback server
//

import Foundation
import Network
import Combine
import SwiftUI

@MainActor
class OAuthService: NSObject, ObservableObject {
    static let shared = OAuthService()
    
    @Published var isAuthenticating = false
    @Published var authError: String?
    
    private var listener: NWListener?
    private var pkceStore: [String: PKCEStoreEntry] = [:]
    private var authContinuation: CheckedContinuation<Account, Error>?
    private var timeoutTimer: Timer?
    private let listenerQueue = DispatchQueue(label: "com.codexaccountmanager.oauth")
    
    private struct PKCEStoreEntry {
        let verifier: String
        let port: UInt16
        let createdAt: Date
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    func authenticate() async throws -> Account {
        guard !isAuthenticating else {
            throw OAuthError.serverError("Authentication already in progress")
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        // Generate PKCE pair
        let pkce = PKCEGenerator.generate()
        let state = PKCEGenerator.generateState()
        
        // Start callback server and wait for it to be ready
        let port = try await startCallbackServer(state: state, pkce: pkce)
        
        // Small delay to ensure server is fully ready
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Build authorization URL
        let authURL = buildAuthorizationURL(pkce: pkce, state: state, port: port)
        
        // Open browser
        NSWorkspace.shared.open(authURL)
        
        // Wait for callback
        return try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation
            
            // Set timeout
            self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: OAuthConfig.timeoutSeconds, repeats: false) { _ in
                Task { @MainActor in
                    self.cleanup()
                    self.authContinuation?.resume(throwing: OAuthError.timeout)
                    self.authContinuation = nil
                }
            }
        }
    }
    
    func refreshAccessToken(refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: OAuthConfig.tokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": OAuthConfig.clientId
        ]
        
        request.httpBody = params.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.serverError("Token refresh failed: \(body)")
        }
        
        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw OAuthError.invalidResponse
        }
    }
    
    // MARK: - Private Methods
    
    private func startCallbackServer(state: String, pkce: PKCEPair) async throws -> UInt16 {
        // Store PKCE data
        pkceStore[state] = PKCEStoreEntry(
            verifier: pkce.verifier,
            port: OAuthConfig.callbackPort,
            createdAt: Date()
        )
        
        // Clean old entries
        cleanupOldEntries()
        
        // Try ports sequentially
        let portsToTry = [OAuthConfig.callbackPort] + OAuthConfig.callbackFallbackPorts
        
        for port in portsToTry {
            do {
                let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: port))
                
                // Use actor-isolated state to track result
                let result = try await waitForListenerReady(listener: listener, port: port, state: state)
                
                switch result {
                case .success(let readyPort):
                    self.listener = listener
                    return readyPort
                    
                case .failure:
                    continue
                }
                
            } catch {
                continue
            }
        }
        
        throw OAuthError.portInUse
    }
    
    private func waitForListenerReady(listener: NWListener, port: UInt16, state: String) async throws -> Result<UInt16, Error> {
        return try await withCheckedThrowingContinuation { continuation in
            var hasCompleted = false
            
            listener.stateUpdateHandler = { [weak self] newState in
                guard !hasCompleted else { return }
                
                switch newState {
                case .ready:
                    hasCompleted = true
                    continuation.resume(returning: .success(port))
                    
                case .failed(let error):
                    hasCompleted = true
                    continuation.resume(returning: .failure(error))
                    
                case .cancelled:
                    hasCompleted = true
                    continuation.resume(returning: .failure(OAuthError.serverError("Listener cancelled")))
                    
                default:
                    break
                }
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.handleConnection(connection, expectedState: state)
                }
            }
            
            listener.start(queue: self.listenerQueue)
            
            // Safety timeout - if no state change within 2 seconds, fail
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard !hasCompleted else { return }
                hasCompleted = true
                continuation.resume(returning: .failure(OAuthError.timeout))
            }
        }
    }
    
    private func handleConnection(_ connection: NWConnection, expectedState: String) {
        connection.start(queue: listenerQueue)
        
        receiveHTTPRequest(connection) { [weak self] request in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard let request = request else {
                    self.sendResponse(connection, status: 400, body: "Bad Request")
                    return
                }
                
                // Parse URL components
                let components = request.components
                let queryItems = components?.queryItems ?? []
                
                let code = queryItems.first(where: { $0.name == "code" })?.value
                let state = queryItems.first(where: { $0.name == "state" })?.value
                let error = queryItems.first(where: { $0.name == "error" })?.value
                
                // Check for OAuth error
                if let error = error {
                    self.sendResponse(connection, status: 400, body: self.errorHTML(error))
                    self.cleanup()
                    self.authContinuation?.resume(throwing: OAuthError.serverError(error))
                    self.authContinuation = nil
                    return
                }
                
                // Validate state
                guard let state = state, let pkceEntry = self.pkceStore[state] else {
                    self.sendResponse(connection, status: 400, body: self.errorHTML("Invalid state"))
                    self.cleanup()
                    self.authContinuation?.resume(throwing: OAuthError.invalidResponse)
                    self.authContinuation = nil
                    return
                }
                
                // Check for code
                guard let code = code else {
                    self.sendResponse(connection, status: 400, body: "Waiting for authorization code...")
                    return
                }
                
                // Success - send response first
                self.sendResponse(connection, status: 200, body: self.successHTML())
                
                // Exchange code for tokens
                do {
                    let account = try await self.exchangeCodeForTokens(
                        code: code,
                        verifier: pkceEntry.verifier,
                        port: pkceEntry.port
                    )
                    self.cleanup()
                    self.authContinuation?.resume(returning: account)
                    self.authContinuation = nil
                } catch {
                    self.cleanup()
                    self.authContinuation?.resume(throwing: error)
                    self.authContinuation = nil
                }
            }
        }
    }
    
    private func receiveHTTPRequest(_ connection: NWConnection, completion: @escaping @Sendable (HTTPRequest?) -> Void) {
        var data = Data()
        
        let receiveBlock: (@Sendable () -> Void) = { [weak connection] in
            guard let connection = connection else {
                completion(nil)
                return
            }
            
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { chunk, _, isComplete, error in
                if let chunk = chunk {
                    data.append(chunk)
                }
                
                if let error = error {
                    completion(nil)
                    return
                }
                
                // Check if we have complete HTTP headers
                if let string = String(data: data, encoding: .utf8) {
                    if string.contains("\r\n\r\n") {
                        completion(HTTPRequest(data: data))
                        return
                    }
                }
                
                if isComplete {
                    completion(HTTPRequest(data: data))
                } else {
                    // Continue receiving
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { chunk, _, isComplete, error in
                        if let chunk = chunk {
                            data.append(chunk)
                        }
                        
                        if let error = error {
                            completion(nil)
                            return
                        }
                        
                        if let string = String(data: data, encoding: .utf8) {
                            if string.contains("\r\n\r\n") {
                                completion(HTTPRequest(data: data))
                                return
                            }
                        }
                        
                        if isComplete {
                            completion(HTTPRequest(data: data))
                        } else {
                            completion(HTTPRequest(data: data))
                        }
                    }
                }
            }
        }
        
        receiveBlock()
    }
    
    private func sendResponse(_ connection: NWConnection, status: Int, body: String) {
        let statusText = status == 200 ? "OK" : "Bad Request"
        let response = """
        HTTP/1.1 \(status) \(statusText)\r\n        Content-Type: text/html; charset=utf-8\r\n        Content-Length: \(body.utf8.count)\r\n        Connection: close\r\n        \r\n        \(body)
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func exchangeCodeForTokens(code: String, verifier: String, port: UInt16) async throws -> Account {
        let redirectUri = "http://localhost:\(port)\(OAuthConfig.callbackPath)"
        
        var request = URLRequest(url: URL(string: OAuthConfig.tokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": OAuthConfig.clientId,
            "code_verifier": verifier
        ]
        
        request.httpBody = params.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.serverError("Token exchange failed: \(body)")
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        guard let accountInfo = JWTDecoder.extractAccountInfo(from: tokenResponse.accessToken) else {
            throw OAuthError.invalidToken
        }
        
        return Account(
            email: accountInfo.email ?? "unknown",
            accountId: accountInfo.accountId ?? UUID().uuidString,
            planType: accountInfo.planType,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? "",
            idToken: tokenResponse.idToken ?? "",
            expiresAt: accountInfo.expiresAt ?? Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
    }
    
    private func buildAuthorizationURL(pkce: PKCEPair, state: String, port: UInt16) -> URL {
        var components = URLComponents(string: OAuthConfig.authUrl)!
        
        let redirectUri = "http://localhost:\(port)\(OAuthConfig.callbackPath)"
        
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: OAuthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: OAuthConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "originator", value: "codex_cli_rs"),
            URLQueryItem(name: "prompt", value: "login"),
            URLQueryItem(name: "max_age", value: "0")
        ]
        
        return components.url!
    }
    
    private func successHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Authentication Successful</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                .card { background: #1e293b; padding: 3rem; border-radius: 1rem; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5); text-align: center; max-width: 400px; border: 1px solid #334155; }
                .icon { font-size: 4rem; margin-bottom: 1.5rem; }
                h1 { margin: 0 0 1rem; color: #10b981; font-weight: 700; }
                p { color: #94a3b8; line-height: 1.6; font-size: 1.1rem; }
                .footer { margin-top: 2rem; font-size: 0.9rem; color: #64748b; }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="icon">✅</div>
                <h1>Success!</h1>
                <p>Authentication successful! You can close this window and return to the Codex Account Manager app.</p>
                <div class="footer">This window will close automatically.</div>
            </div>
            <script>setTimeout(() => window.close(), 3000);</script>
        </body>
        </html>
        """
    }
    
    private func errorHTML(_ error: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Authentication Failed</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                .card { background: #1e293b; padding: 3rem; border-radius: 1rem; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5); text-align: center; max-width: 400px; border: 1px solid #334155; }
                .icon { font-size: 4rem; margin-bottom: 1.5rem; }
                h1 { margin: 0 0 1rem; color: #ef4444; font-weight: 700; }
                p { color: #94a3b8; line-height: 1.6; }
                .error { background: rgba(239, 68, 68, 0.1); padding: 1rem; border-radius: 0.5rem; color: #fca5a5; margin-top: 1rem; font-family: monospace; font-size: 0.9rem; }
            </style>
        </head>
        <body>
            <div class="card">
                <div class="icon">❌</div>
                <h1>Failed</h1>
                <p>Authentication could not be completed.</p>
                <div class="error">\(error)</div>
                <p style="margin-top: 1.5rem; font-size: 0.9rem;">Please close this window and try again.</p>
            </div>
        </body>
        </html>
        """
    }
    
    private func cleanup() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        listener?.cancel()
        listener = nil
        pkceStore.removeAll()
    }
    
    private func cleanupOldEntries() {
        let now = Date()
        pkceStore = pkceStore.filter { _, entry in
            now.timeIntervalSince(entry.createdAt) < 300 // 5 minutes
        }
    }
}

// MARK: - HTTP Request Parser

private struct HTTPRequest: Sendable {
    let method: String
    let path: String
    let components: URLComponents?
    
    init?(data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        
        let lines = string.split(separator: "\r\n")
        guard let firstLine = lines.first else { return nil }
        
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        
        self.method = String(parts[0])
        self.path = String(parts[1])
        self.components = URLComponents(string: "http://localhost\(path)")
    }
}

// MARK: - URL Encoding Extension

private extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        return self.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&").data(using: .utf8)
    }
}
