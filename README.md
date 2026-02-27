# Codex Account Manager

A native macOS app for managing multiple OpenAI Codex CLI accounts. Easily switch between accounts when you hit rate limits, without re-authenticating each time.

## Features

- **Multi-Account Support**: Add and manage multiple OpenAI accounts
- **One-Click Switching**: Instantly switch accounts in the Codex CLI
- **OAuth Authentication**: Secure PKCE-based OAuth flow
- **Persistent Storage**: Accounts saved locally with secure permissions
- **Auto-Refresh**: Tokens refreshed automatically before expiry

## Requirements

- macOS 13.0+
- Xcode 15.0+ (for building)
- OpenAI Codex CLI installed

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/codex-account-manager.git
cd codex-account-manager/Codex-Account-Manager
```

2. Open in Xcode:
```bash
open Codex-Account-Manager.xcodeproj
```

3. Build and run (Cmd+R)

### Pre-built

Download the latest release from the [Releases](https://github.com/yourusername/codex-account-manager/releases) page.

## Usage

### Adding Accounts

1. Click the **+** button
2. Your browser will open to OpenAI's login page
3. Complete the authentication
4. The account will be saved automatically

### Switching Accounts

1. Select an account from the list
2. Click **Activate**
3. The account is now active in Codex CLI

### Quick Switch

With multiple accounts added, use **Switch to Next Account** to rotate between accounts when you hit rate limits.

## How It Works

The app writes authentication data to `~/.codex/auth.json`, the same file used by the official Codex CLI. When you activate an account, it overwrites this file with the selected account's tokens.

## Security

- Tokens are stored with `0600` permissions (user read/write only)
- App uses PKCE for secure OAuth authentication
- No tokens are transmitted to any server except OpenAI's

## Project Structure

```
Codex-Account-Manager/
├── Codex-Account-Manager/
│   ├── Codex_Account_ManagerApp.swift    # App entry point
│   ├── ContentView.swift                 # Main UI
│   ├── Account.swift                     # Account model
│   ├── AccountStore.swift                # Account persistence
│   ├── OAuthService.swift                # OAuth + HTTP server
│   ├── OAuthConfig.swift                 # OAuth constants
│   ├── PKCEGenerator.swift               # PKCE code generation
│   ├── JWTDecoder.swift                  # JWT token parsing
│   └── CodexAuthWriter.swift             # Writes to ~/.codex/auth.json
└── README.md
```

## Related Projects

- [codex-claude-proxy](https://github.com/yourusername/codex-claude-proxy) - Node.js proxy for Codex CLI with Claude integration

## License

MIT License - see LICENSE file for details

## Contributing

Pull requests welcome! Please open an issue first to discuss changes.

## Acknowledgments

- OpenAI for the Codex CLI
- OAuth 2.0 with PKCE for secure authentication
