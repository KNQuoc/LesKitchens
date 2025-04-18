import SwiftUI

struct AppTheme {
    // MARK: - Colors
    static let backgroundColor = Color("BackgroundColor")
    static let cardColor = Color("CardColor")
    static let actionColor = Color("ActionColor")
    static let tabBarColor = Color("TabBarColor")

    // MARK: - Text Styles
    struct TextStyles {
        static let title = Font.title.weight(.semibold)
        static let itemTitle = Font.body.weight(.semibold)
        static let itemDetails = Font.caption
        static let actionText = Font.body.weight(.medium)
    }

    // MARK: - Button Styles
    struct ButtonStyles {
        struct ActionButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .background(AppTheme.actionColor)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1)
            }
        }

        struct IconButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .foregroundColor(.primary)
                    .scaleEffect(configuration.isPressed ? 0.9 : 1)
            }
        }
    }

    // MARK: - View Modifiers
    struct ViewModifiers {
        struct CardStyle: ViewModifier {
            func body(content: Content) -> some View {
                content
                    .padding()
                    .background(AppTheme.cardColor)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self.modifier(AppTheme.ViewModifiers.CardStyle())
    }

    func actionButton() -> some View {
        self.buttonStyle(AppTheme.ButtonStyles.ActionButtonStyle())
    }

    func iconButton() -> some View {
        self.buttonStyle(AppTheme.ButtonStyles.IconButtonStyle())
    }
}
