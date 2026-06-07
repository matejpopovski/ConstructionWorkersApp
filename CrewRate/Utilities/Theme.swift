import SwiftUI

extension Color {
    static let crewNavy = Color.black
    static let crewOrange = Color(red: 1.0, green: 106.0 / 255.0, blue: 0.0)
    static let crewGray = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let crewInk = Color(red: 0.13, green: 0.15, blue: 0.18)
    static let crewMuted = Color(red: 0.43, green: 0.46, blue: 0.50)
    static let crewDivider = Color.primary.opacity(0.09)
    static let crewSurface = Color(.systemBackground)
    static let crewCanvas = Color(.systemGroupedBackground)
}

enum CrewRateConstants {
    static let warningCopy = "Share your personal experience honestly. Do not post threats, private personal information, hate speech, or claims you cannot support."
}

enum CrewDesign {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Size {
        static let controlHeight: CGFloat = 48
        static let compactControlHeight: CGFloat = 38
        static let avatar: CGFloat = 44
        static let profileAvatar: CGFloat = 88
        static let iconButton: CGFloat = 40
    }

    static let standardAnimation = Animation.spring(response: 0.28, dampingFraction: 0.82)
}

struct CrewCardModifier: ViewModifier {
    var horizontalPadding: CGFloat = CrewDesign.Spacing.md
    var verticalPadding: CGFloat = CrewDesign.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color.crewSurface)
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous)
                    .stroke(Color.crewDivider, lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.035), radius: 8, y: 2)
    }
}

struct CrewPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(CrewDesign.standardAnimation, value: configuration.isPressed)
    }
}

struct CrewPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: CrewDesign.Size.controlHeight)
            .padding(.horizontal, CrewDesign.Spacing.md)
            .foregroundStyle(.white)
            .background(Color.crewNavy.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(CrewDesign.standardAnimation, value: configuration.isPressed)
    }
}

struct CrewSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: CrewDesign.Size.compactControlHeight)
            .padding(.horizontal, CrewDesign.Spacing.sm)
            .foregroundStyle(.primary)
            .background(Color.crewGray.opacity(configuration.isPressed ? 0.65 : 1))
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.small, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(CrewDesign.standardAnimation, value: configuration.isPressed)
    }
}

struct CrewIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(width: CrewDesign.Size.iconButton, height: CrewDesign.Size.iconButton)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .opacity(configuration.isPressed ? 0.65 : 1)
            .animation(CrewDesign.standardAnimation, value: configuration.isPressed)
    }
}

extension View {
    func crewCard(
        horizontalPadding: CGFloat = CrewDesign.Spacing.md,
        verticalPadding: CGFloat = CrewDesign.Spacing.md
    ) -> some View {
        modifier(CrewCardModifier(horizontalPadding: horizontalPadding, verticalPadding: verticalPadding))
    }

    func crewScreenBackground() -> some View {
        background(Color.crewCanvas.ignoresSafeArea())
    }
}
