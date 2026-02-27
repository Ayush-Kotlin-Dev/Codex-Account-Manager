//
//  ToastManager.swift
//  Codex-Account-Manager
//
//  Toast notification system for user feedback
//

import SwiftUI
import Combine

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success: return Theme.Colors.success
        case .error: return Theme.Colors.error
        case .warning: return Theme.Colors.warning
        case .info: return Theme.Colors.info
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval
}

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var toasts: [Toast] = []
    private var cancellables: Set<AnyCancellable> = []
    
    private init() {}
    
    func show(_ message: String, type: ToastType = .info, duration: TimeInterval = 3.0) {
        let toast = Toast(message: message, type: type, duration: duration)
        toasts.append(toast)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismiss(toast)
        }
    }
    
    func dismiss(_ toast: Toast) {
        withAnimation(Theme.Animation.spring) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
    
    func success(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .success, duration: duration)
    }
    
    func error(_ message: String, duration: TimeInterval = 4.0) {
        show(message, type: .error, duration: duration)
    }
    
    func warning(_ message: String, duration: TimeInterval = 3.5) {
        show(message, type: .warning, duration: duration)
    }
    
    func info(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .info, duration: duration)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(toast.type.color)
            
            Text(toast.message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.text)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(Theme.Animation.spring) {
                isVisible = true
            }
        }
    }
}

// MARK: - Toast Container

struct ToastContainer: ViewModifier {
    @StateObject private var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(toastManager.toasts) { toast in
                        ToastView(toast: toast) {
                            toastManager.dismiss(toast)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, Theme.Spacing.lg)
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(maxWidth: 400)
                , alignment: .top
            )
    }
}

extension View {
    func toastContainer() -> some View {
        modifier(ToastContainer())
    }
}
