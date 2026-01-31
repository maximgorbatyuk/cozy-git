//
//  StyleHelpers.swift
//  CozyGit
//

import SwiftUI

// MARK: - Design Constants

enum DesignConstants {
    // Corner Radius
    static let cornerRadiusSmall: CGFloat = 4
    static let cornerRadiusMedium: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 12
    static let cornerRadiusXLarge: CGFloat = 16

    // Spacing
    static let spacingXSmall: CGFloat = 4
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 12
    static let spacingLarge: CGFloat = 16
    static let spacingXLarge: CGFloat = 24

    // Shadow
    static let shadowRadius: CGFloat = 4
    static let shadowOpacity: CGFloat = 0.1

    // Animation
    static let animationDuration: Double = 0.2
    static let animationSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
}

// MARK: - Color Extensions

extension Color {
    // Warm palette for cozy feel
    static let cozyBackground = Color(nsColor: .windowBackgroundColor)
    static let cozySecondaryBackground = Color(nsColor: .controlBackgroundColor)
    static let cozyAccent = Color.orange
    static let cozySuccess = Color.green
    static let cozyWarning = Color.orange
    static let cozyError = Color.red
    static let cozyInfo = Color.blue

    // Status colors
    static let statusAdded = Color.green
    static let statusModified = Color.orange
    static let statusDeleted = Color.red
    static let statusRenamed = Color.blue
    static let statusUntracked = Color.gray
    static let statusConflict = Color.purple
}

// MARK: - View Modifiers

/// Card-style container with rounded corners and shadow
struct CardStyle: ViewModifier {
    var padding: CGFloat = DesignConstants.spacingMedium

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
            .shadow(color: .black.opacity(DesignConstants.shadowOpacity), radius: DesignConstants.shadowRadius, x: 0, y: 2)
    }
}

/// Subtle hover effect for interactive elements
struct HoverEffect: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(DesignConstants.animationSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Press effect for buttons
struct PressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Loading overlay modifier
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    var message: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: DesignConstants.spacingMedium) {
                            ProgressView()
                                .scaleEffect(1.5)

                            if let message = message {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(DesignConstants.spacingLarge)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusMedium))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut(duration: DesignConstants.animationDuration), value: isLoading)
    }
}

/// Success/failure feedback animation
struct FeedbackModifier: ViewModifier {
    enum FeedbackType {
        case success, failure, warning, info
    }

    let type: FeedbackType?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if let type = type {
                    feedbackBadge(for: type)
                        .transition(.scale.combined(with: .opacity))
                        .padding(8)
                }
            }
            .animation(DesignConstants.animationSpring, value: type != nil)
    }

    @ViewBuilder
    private func feedbackBadge(for type: FeedbackType) -> some View {
        let (icon, color): (String, Color) = {
            switch type {
            case .success: return ("checkmark.circle.fill", .green)
            case .failure: return ("xmark.circle.fill", .red)
            case .warning: return ("exclamationmark.triangle.fill", .orange)
            case .info: return ("info.circle.fill", .blue)
            }
        }()

        Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(color)
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
    }
}

/// Tooltip modifier with custom content
struct TooltipModifier: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        content
            .help(text)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card styling
    func cardStyle(padding: CGFloat = DesignConstants.spacingMedium) -> some View {
        modifier(CardStyle(padding: padding))
    }

    /// Add subtle hover effect
    func hoverEffect() -> some View {
        modifier(HoverEffect())
    }

    /// Add press effect
    func pressEffect() -> some View {
        modifier(PressEffect())
    }

    /// Show loading overlay
    func loadingOverlay(_ isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }

    /// Show feedback badge
    func feedback(_ type: FeedbackModifier.FeedbackType?) -> some View {
        modifier(FeedbackModifier(type: type))
    }

    /// Add tooltip
    func tooltip(_ text: String) -> some View {
        modifier(TooltipModifier(text: text))
    }

    /// Standard corner radius
    func standardCornerRadius(_ size: CornerRadiusSize = .medium) -> some View {
        let radius: CGFloat = {
            switch size {
            case .small: return DesignConstants.cornerRadiusSmall
            case .medium: return DesignConstants.cornerRadiusMedium
            case .large: return DesignConstants.cornerRadiusLarge
            case .xLarge: return DesignConstants.cornerRadiusXLarge
            }
        }()
        return clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

enum CornerRadiusSize {
    case small, medium, large, xLarge
}

// MARK: - Loading Skeleton

/// Skeleton loading view for placeholder content
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat

    @State private var isAnimating = false

    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: DesignConstants.cornerRadiusSmall)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

/// Skeleton row for list loading
struct SkeletonListRow: View {
    var body: some View {
        HStack(spacing: DesignConstants.spacingMedium) {
            SkeletonView(width: 24, height: 24)

            VStack(alignment: .leading, spacing: DesignConstants.spacingXSmall) {
                SkeletonView(width: 150, height: 14)
                SkeletonView(width: 100, height: 12)
            }

            Spacer()

            SkeletonView(width: 60, height: 14)
        }
        .padding(.vertical, DesignConstants.spacingSmall)
    }
}

// MARK: - Animated Transition Helpers

extension AnyTransition {
    /// Slide and fade transition
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }

    /// Blur transition
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 10, opacity: 0),
            identity: BlurModifier(radius: 0, opacity: 1)
        )
    }
}

private struct BlurModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
    }
}

// MARK: - Preview

#Preview("Skeleton Loading") {
    VStack(spacing: 16) {
        ForEach(0..<5, id: \.self) { _ in
            SkeletonListRow()
        }
    }
    .padding()
    .frame(width: 400)
}

#Preview("Card Style") {
    VStack(spacing: 16) {
        Text("Card Content")
            .frame(maxWidth: .infinity)
            .cardStyle()

        Text("Hover me")
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .standardCornerRadius()
            .hoverEffect()
    }
    .padding()
    .frame(width: 300)
}
