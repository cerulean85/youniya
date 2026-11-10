import SwiftUI

/// 02 Login. Live: Sign in with Apple or Google; mock: signs in locally.
struct LoginView: View {
    @Environment(AppModel.self) private var model
    /// 02-1 초대 계정으로 로그인
    @State private var invite = DebugScreen.is("2-1")
    @State private var inviteHeight: CGFloat = 440

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
                SocialButton(provider: .apple) { model.signIn(with: .apple) }
                SocialButton(provider: .google) { model.signIn(with: .google) }
                Text("처음이라면 다음 화면에서\n이용약관과 개인정보 처리 동의를 받아요.")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                // 02-1: shown, not hidden (App Review 2.3.1).
                Button { invite = true } label: {
                    Text("초대 계정으로 로그인")
                        .textStyle(.caption)
                        .underline()
                        .foregroundStyle(Color.borderFocus)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { StarField() }
        .sheet(isPresented: $invite) {
            InviteLoginSheet(onClose: { invite = false })
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { inviteHeight = $0 }
                .presentationDetents([.height(inviteHeight)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.xl)
                .presentationBackground { SheetBackground(seed: "invite-sheet") }
        }
    }
}

#Preview {
    LoginView()
        .environment(AppModel())
}
