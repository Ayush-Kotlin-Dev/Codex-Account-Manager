# CLAUDE.md - AI Context for Codex Account Manager

## Project Overview

This is a native **Swift macOS app** that manages multiple OpenAI accounts for the Codex CLI tool. It solves the problem of switching between accounts when hitting rate limits.

## Architecture

### Core Flow

```
User clicks "Add Account"
    ↓
OAuthService.authenticate()
    ↓
Start local HTTP server (port 1455-1460)
    ↓
Open browser to OpenAI OAuth
    ↓
User authenticates
    ↓
Callback to localhost with auth code
    ↓
Exchange code for tokens
    ↓
Save account to local storage
```

### Account Activation Flow

```
User selects account + clicks "Activate"
    ↓
AccountStore.activateAccount(id)
    ↓
Check if token expired → refresh if needed
    ↓
CodexAuthWriter.writeAccount(account)
    ↓
Write to ~/.codex/auth.json
    ↓
Codex CLI now uses this account
```

## Key Files

| File | Purpose |
|------|---------|
| `OAuthService.swift` | OAuth 2.0 + PKCE, HTTP callback server using Network.framework |
| `CodexAuthWriter.swift` | Writes auth data to `~/.codex/auth.json` (real home dir, not sandbox) |
| `AccountStore.swift` | SwiftUI ObservableObject, persists accounts to Application Support |
| `JWTDecoder.swift` | Decodes JWT access tokens to extract account info |
| `PKCEGenerator.swift` | Generates PKCE code verifiers/challenges using CryptoKit |
| `QuotaService.swift` | Fetches usage quota from `chatgpt.com/backend-api/wham/usage` |

## OAuth Configuration

```swift
clientId: "app_EMoamEEZ73f0CkXaXp7hrann"
authUrl: "https://auth.openai.com/oauth/authorize"
tokenUrl: "https://auth.openai.com/oauth/token"
scopes: ["openid", "profile", "email", "offline_access"]
callbackPort: 1455 (with fallbacks 1456-1460)
```

## Important Implementation Details

### Sandbox Issue (CRITICAL)

The app **must not** use App Sandbox because it needs to write to `~/.codex/auth.json`. The sandbox redirects `FileManager.default.homeDirectoryForCurrentUser` to the container.

**Solution:**
- `ENABLE_APP_SANDBOX = NO` in project.pbxproj
- Use `ProcessInfo.processInfo.environment["HOME"]` to get real home directory

### HTTP Server Implementation

Uses `NWListener` from Network.framework:
- Waits for `.ready` state before returning port
- Falls back through ports 1455-1460 if busy
- 2-second timeout for listener state changes
- Handles connections on dedicated dispatch queue

### JWT Claims Structure

```swift
struct JWTClaims {
    let sub: String?           // User ID
    let email: String?
    let exp: Double?           // Expiration (epoch seconds)
    
    // OpenAI-specific claims (namespaced URLs)
    let openAIAuth: OpenAIAuthClaims?        // https://api.openai.com/auth
    let openAIProfile: OpenAIProfileClaims?  // https://api.openai.com/profile
}
```

Note: `aud` field is intentionally NOT decoded because it can be String OR [String].

## Codex Auth File Format

The app writes to `~/.codex/auth.json`:

```json
{
  "auth_mode": "chatgpt",
  "OPENAI_API_KEY": null,
  "tokens": {
    "id_token": "eyJ...",
    "access_token": "eyJ...",
    "refresh_token": "rt_...",
    "account_id": "uuid-here"
  },
  "last_refresh": "2026-02-27T11:10:14Z"
}
```

## Common Issues & Solutions

### "Port already in use"
- App tries ports 1455-1460 automatically
- If all fail, shows error to user

### "Operation not permitted" (Network)
- Missing `com.apple.security.network.server` entitlement
- Or sandbox is enabled (must be disabled)

### JWT decoding fails
- Usually due to `aud` being array instead of string
- Fixed by removing `aud` from JWTClaims struct

### Writes to wrong path (container)
- Sandbox is enabled
- Must set `ENABLE_APP_SANDBOX = NO` in project

## Swift Concurrency Notes

- `@MainActor` on OAuthService and AccountStore
- HTTP server runs on background dispatch queue
- Callbacks bridged to MainActor with `Task { @MainActor in }`
- `NWListener` closures are nonisolated - careful with state access

## Testing Checklist

- [ ] Add new account via OAuth
- [ ] Account appears in list with correct email
- [ ] Click Activate writes to ~/.codex/auth.json
- [ ] Verify Codex CLI uses the activated account
- [ ] Switch between multiple accounts
- [ ] Delete account removes from storage
- [ ] Port fallback works (test with port 1455 occupied)
- [ ] Token refresh works (wait for expiry or simulate)

## Build Configuration

Required entitlements (Codex_Account_Manager.entitlements):
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

**NO App Sandbox** - must be disabled for file system access outside container.

## Related Code

This project shares OAuth logic with the Node.js codex-claude-proxy:
- Same client_id
- Same PKCE implementation
- Same token exchange flow
- Both write compatible auth.json format
- `QuotaService.swift` mirrors `model-api.js` `fetchUsage()` — both call `wham/usage`

## Changelog

### v1.1 (build 2)
- **feat: Usage Quota Display** — Added `QuotaService.swift` to fetch live usage data from `chatgpt.com/backend-api/wham/usage`. Each account now shows:
  - A mini 4px quota bar in the account list rows
  - A full labeled progress bar with `used %` in the detail panel
  - Remaining quota %, color-coded status badge (green/orange/red), and reset timer
  - A "Refresh Quota" button with spinner in the action bar
  - Auto-fetch on launch and on account selection (stale if >5 min old)
- Added `quotaInfo: QuotaInfo?` to `Account` model; `isRateLimited` now prefers live API data
- Added `fetchQuota(for:)` and `fetchAllQuotas()` to `AccountStore`
