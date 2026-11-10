import SwiftUI

/// Figma `Bottom Sheet` (Actions=3) content: title, message, three buttons.
struct ActionSheetContent: View {
    var title: String
    var message: String
    var primary: (String, () -> Void)
    var secondary: (String, () -> Void)
    /// 92 has no third action.
    var ghost: (String, () -> Void)?
    /// 91 uses the Danger button for an irreversible primary action.
    var destructive = false
    /// 05-3 / 05-4: the second action is a plain text button.
    var secondaryIsGhost = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule()
                .fill(Color.borderDefault)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title)
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                Text(message)
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Space.md) {
                if destructive {
                    Button(primary.0, action: primary.1)
                        .buttonStyle(.danger)
                } else {
                    Button(primary.0, action: primary.1)
                        .buttonStyle(.primary)
                }
                if secondaryIsGhost {
                    Button(secondary.0, action: secondary.1).buttonStyle(.ghost)
                } else {
                    Button(secondary.0, action: secondary.1).buttonStyle(.secondary)
                }
                if let ghost {
                    Button(ghost.0, action: ghost.1)
                        .buttonStyle(.ghost)
                }
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }
}
