import SwiftUI

/// 01 Splash
struct SplashView: View {
    var body: some View {
        VStack(spacing: Space.lg) {
            LogoMark(size: .large)
            Text("YOUNIYA")
                .textStyle(.display)
                .foregroundStyle(Color.textPrimary)
            Text("텍스트로 시각화한 우리 모두의 우주")
                .textStyle(.bodyM)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StarField() }
    }
}

#Preview {
    SplashView()
}
