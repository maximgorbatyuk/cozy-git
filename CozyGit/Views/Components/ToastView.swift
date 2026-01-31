//
//  ToastView.swift
//  CozyGit
//

import SwiftUI

/// Toast notification style
enum ToastStyle {
    case success
    case error
    case warning
    case info

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

/// Toast message data
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
    let duration: TimeInterval

    init(message: String, style: ToastStyle, duration: TimeInterval = 3.0) {
        self.message = message
        self.style = style
        self.duration = duration
    }

    static func success(_ message: String) -> ToastMessage {
        ToastMessage(message: message, style: .success)
    }

    static func error(_ message: String) -> ToastMessage {
        ToastMessage(message: message, style: .error, duration: 5.0)
    }

    static func warning(_ message: String) -> ToastMessage {
        ToastMessage(message: message, style: .warning)
    }

    static func info(_ message: String) -> ToastMessage {
        ToastMessage(message: message, style: .info)
    }
}

/// Toast view component
struct ToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.style.iconName)
                .font(.title3)
                .foregroundStyle(message.style.color)

            Text(message.message)
                .font(.callout)
                .lineLimit(2)

            Spacer()

            Button {
                dismissToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isVisible = true
            }

            // Auto dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + message.duration) {
                dismissToast()
            }
        }
    }

    private func dismissToast() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

/// Toast container for managing multiple toasts
struct ToastContainer: View {
    @Binding var toasts: [ToastMessage]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(toasts) { toast in
                ToastView(message: toast) {
                    withAnimation {
                        toasts.removeAll { $0.id == toast.id }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .frame(maxWidth: 400)
    }
}

/// View modifier to add toast support
struct ToastModifier: ViewModifier {
    @Binding var toasts: [ToastMessage]

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                ToastContainer(toasts: $toasts)
            }
    }
}

extension View {
    func toastContainer(_ toasts: Binding<[ToastMessage]>) -> some View {
        modifier(ToastModifier(toasts: toasts))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
    }
    .frame(width: 500, height: 400)
    .overlay(alignment: .top) {
        VStack(spacing: 8) {
            ToastView(message: .success("Operation completed successfully")) {}
            ToastView(message: .error("Failed to push changes")) {}
            ToastView(message: .warning("Uncommitted changes detected")) {}
            ToastView(message: .info("Fetching from remote...")) {}
        }
        .padding()
    }
}
