//
//  Theme.swift
//  Codex-Account-Manager
//
//  Centralized design tokens and reusable visual primitives.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum Theme {
    enum Colors {
        static let brand = Color(red: 0.08, green: 0.45, blue: 0.95)
        static let brandAccent = Color(red: 0.00, green: 0.72, blue: 0.71)
        static let success = platformColor(
            light: Color(red: 0.10, green: 0.68, blue: 0.40),
            dark:  Color(red: 0.18, green: 0.82, blue: 0.50)
        )
        static let warning = platformColor(
            light: Color(red: 0.93, green: 0.58, blue: 0.10),
            dark:  Color(red: 1.00, green: 0.72, blue: 0.28)
        )
        static let error = platformColor(
            light: Color(red: 0.88, green: 0.22, blue: 0.22),
            dark:  Color(red: 1.00, green: 0.40, blue: 0.40)
        )
        static let info = platformColor(
            light: Color(red: 0.18, green: 0.52, blue: 0.96),
            dark:  Color(red: 0.40, green: 0.68, blue: 1.00)
        )
        static let selectionBackground = platformColor(
            light: Color(red: 0.08, green: 0.45, blue: 0.95).opacity(0.12),
            dark:  Color(red: 0.08, green: 0.45, blue: 0.95).opacity(0.18)
        )
        static let selectionBorder = platformColor(
            light: Color(red: 0.08, green: 0.45, blue: 0.95).opacity(0.42),
            dark:  Color(red: 0.08, green: 0.45, blue: 0.95).opacity(0.55)
        )

        static let background = platformColor(light: Color(red: 0.96, green: 0.97, blue: 0.99), dark: Color(red: 0.08, green: 0.10, blue: 0.14))
        static let surface = platformColor(light: .white, dark: Color(red: 0.12, green: 0.14, blue: 0.19))
        static let elevatedSurface = platformColor(light: Color(red: 0.98, green: 0.99, blue: 1.0), dark: Color(red: 0.15, green: 0.17, blue: 0.23))

        static let textPrimary = platformColor(light: Color(red: 0.10, green: 0.12, blue: 0.18), dark: .white)
        static let textSecondary = platformColor(light: Color(red: 0.31, green: 0.35, blue: 0.43), dark: Color.white.opacity(0.82))
        static let textTertiary = platformColor(light: Color(red: 0.48, green: 0.52, blue: 0.61), dark: Color.white.opacity(0.62))

        static let divider = platformColor(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.12))
        static let cardBorder = platformColor(light: Color.black.opacity(0.06), dark: Color.white.opacity(0.15))

        static func status(for account: Account) -> Color {
            if account.isExpired {
                return error
            }
            if account.isRateLimited {
                return warning
            }
            return success
        }

        static private func platformColor(light: Color, dark: Color) -> Color {
            #if canImport(AppKit)
            return Color(NSColor(name: nil, dynamicProvider: { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
            }))
            #elseif canImport(UIKit)
            return Color(UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
            #else
            return light
            #endif
        }
    }

    enum Gradient {
        static let hero = LinearGradient(
            colors: [Colors.brand, Colors.brandAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let panel = LinearGradient(
            colors: [Colors.surface, Colors.elevatedSurface],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
    }

    enum Shadow {
        static let card = ShadowStyle(color: .black.opacity(0.08), radius: 14, y: 6)
        static let floating = ShadowStyle(color: .black.opacity(0.16), radius: 18, y: 10)

        struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let y: CGFloat
        }
    }

    enum Motion {
        static let quick = Animation.easeInOut(duration: 0.16)
        static let smooth = Animation.easeInOut(duration: 0.24)
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    }

    enum Typography {
        static let hero = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        static let section = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body    = Font.system(.body, design: .default)
        static let caption  = Font.system(.caption, design: .rounded)
        static let footnote = Font.system(.footnote, design: .rounded)
    }
}

extension View {
    func panelStyle() -> some View {
        self
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.Gradient.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .stroke(Theme.Colors.cardBorder, lineWidth: 1)
                    )
            )
            .shadow(color: Theme.Shadow.card.color, radius: Theme.Shadow.card.radius, x: 0, y: Theme.Shadow.card.y)
    }

    func interactiveRowStyle(isHighlighted: Bool) -> some View {
        self
            .padding(Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(isHighlighted ? Theme.Colors.selectionBackground : Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(isHighlighted ? Theme.Colors.selectionBorder : Theme.Colors.cardBorder, lineWidth: isHighlighted ? 1.5 : 1)
            )
            .animation(Theme.Motion.smooth, value: isHighlighted)
    }
}

struct CapsuleBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
            }

            Text(text)
                .font(Theme.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

extension Account {
    var statusColor: Color {
        Theme.Colors.status(for: self)
    }

    var statusIcon: String {
        if isExpired {
            return "xmark.circle.fill"
        }
        if isRateLimited {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.circle.fill"
    }

    var statusText: String {
        if isExpired {
            return "Expired"
        }
        if isRateLimited {
            return "Rate Limited"
        }
        return "Active"
    }
}
