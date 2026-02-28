//
//  AvatarView.swift
//  Codex-Account-Manager
//
//  Account avatar with initials and gradient background
//

import SwiftUI

struct AvatarView: View {
    let email: String
    let size: CGFloat
    var isActive: Bool = false
    
    private var initials: String {
        let components = email
            .split(separator: "@")
            .first?
            .split(separator: ".")
            .compactMap { $0.first?.uppercased() }
            ?? []
        
        if components.count >= 2 {
            return components.prefix(2).joined()
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "??"
    }
    
    private var gradientColors: [Color] {
        let colors: [[Color]] = [
            [.blue, .purple],
            [.green, .teal],
            [.orange, .red],
            [.pink, .purple],
            [.indigo, .blue],
            [.red, .pink]
        ]
        
        // Deterministic color based on email
        let hash = abs(email.hashValue)
        return colors[hash % colors.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.8) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if isActive {
                Circle()
                    .stroke(Theme.Colors.success, lineWidth: 3)
                    .frame(width: size + 6, height: size + 6)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.spring, value: isActive)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: Status
    let size: CGFloat
    
    enum Status {
        case active
        case expired
        case rateLimited
        case inactive
        
        var color: Color {
            switch self {
            case .active: return .green
            case .expired: return .red
            case .rateLimited: return .orange
            case .inactive: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "checkmark"
            case .expired: return "xmark"
            case .rateLimited: return "exclamationmark"
            case .inactive: return "circle"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(status.color.opacity(0.15))
                .frame(width: size, height: size)
            
            Image(systemName: status.icon)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(status.color)
        }
    }
}

// MARK: - Animated Loading View

struct LoadingView: View {
    let message: String
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.textSecondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Theme.Colors.brand, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.Colors.elevatedSurface)
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            
            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                
                Text(message)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, Theme.Spacing.sm)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
