//
//  Theme.swift
//  Codex-Account-Manager
//
//  Centralized styling and design tokens
//

import SwiftUI

enum Theme {
    // MARK: - Colors
    enum Colors {
        static let primary = Color.accentColor
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        static let background = Color(NSColor.windowBackgroundColor)
        static let secondaryBackground = Color(NSColor.controlBackgroundColor)
        static let tertiaryBackground = Color(NSColor.underPageBackgroundColor)
        
        static let text = Color(NSColor.labelColor)
        static let secondaryText = Color(NSColor.secondaryLabelColor)
        static let tertiaryText = Color(NSColor.tertiaryLabelColor)
        
        static let divider = Color(NSColor.separatorColor)
        static let cardBorder = Color(NSColor.gridColor)
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }
    
    // MARK: - Shadows
    enum Shadows {
        static let sm = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        static let md = ShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        static let lg = ShadowStyle(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        
        struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    // MARK: - Animation
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
    
    // MARK: - Typography
    enum Typography {
        static let title = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .medium)
        static let small = Font.system(size: 10, weight: .medium)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(isActive: Bool = false, isHovered: Bool = false) -> some View {
        self
            .padding(Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.Colors.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .stroke(isActive ? Theme.Colors.success.opacity(0.5) : Theme.Colors.cardBorder,
                                    lineWidth: isActive ? 2 : 1)
                    )
            )
            .shadow(
                color: isHovered ? Theme.Shadows.lg.color : Theme.Shadows.sm.color,
                radius: isHovered ? Theme.Shadows.lg.radius : Theme.Shadows.sm.radius,
                x: isHovered ? Theme.Shadows.lg.x : Theme.Shadows.sm.x,
                y: isHovered ? Theme.Shadows.lg.y : Theme.Shadows.sm.y
            )
            .animation(Theme.Animation.fast, value: isHovered)
            .animation(Theme.Animation.normal, value: isActive)
    }
    
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Colors.cardBorder.opacity(0.5), lineWidth: 0.5)
            )
    }
}

// MARK: - Status Colors

extension Account {
    var statusColor: Color {
        if isExpired {
            return Theme.Colors.error
        } else if isRateLimited {
            return Theme.Colors.warning
        }
        return Theme.Colors.success
    }
    
    var statusIcon: String {
        if isExpired {
            return "xmark.circle.fill"
        } else if isRateLimited {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle.fill"
    }
    
    var statusText: String {
        if isExpired {
            return "Expired"
        } else if isRateLimited {
            return "Rate Limited"
        }
        return "Active"
    }
}

// MARK: - Gradient Backgrounds

enum Gradients {
    static let primary = LinearGradient(
        colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let success = LinearGradient(
        colors: [.green.opacity(0.8), .mint.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let card = LinearGradient(
        colors: [
            Color(NSColor.controlBackgroundColor),
            Color(NSColor.controlBackgroundColor).opacity(0.95)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
