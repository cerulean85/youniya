import SwiftUI

/// 02 Login. Sign-in is mocked: both buttons sign in locally.
struct LoginView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.lg) {
                LogoMark(size: .small)
                Text("오늘의 마음을\n별로 빚어볼까요")
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)
                Text("당신만 볼 수 있는 고요한 밤하늘이에요.\n쓴 글은 암호화되어 안전하게 보관돼요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(spacing: Space.md) {
                // TODO: Replace with Sign in with Apple / Google SDK.
                SocialButton(provider: .apple) { model.signIn() }
                SocialButton(provider: .google) { model.signIn() }
                Text("계속하면 이용약관과 개인정보처리방침,\n민감정보 처리에 동의하게 돼요.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { StarField() }
    }
}

#Preview {
    LoginView()
        .environment(AppModel())
}
