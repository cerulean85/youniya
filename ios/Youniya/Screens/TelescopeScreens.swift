import SwiftUI

// MARK: - 23 Starlight Line

/// 23 Starlight Line (별빛 한 줄): the one line a star in someone's nebula
/// left behind, opened from a card on 22. It can be saved.
struct StarlightLineView: View {
    @Environment(AppModel.self) private var model
    var line: String
    var onClose: () -> Void

    var body: some View {
        let saved = model.savedLines.contains(line)
        VStack(spacing: 0) {
            TopAppBar(title: "별빛 한 줄", onBack: onClose)

            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("오늘의 한 줄")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                    Text("별이 남긴 짧은 말이에요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                RecordsHero()

                NoticeBanner(message: line)

                Spacer(minLength: Space.xl)

                VStack(spacing: Space.md) {
                    Button(saved ? "저장했어요" : "저장하기") {
                        withAnimation(.snappy) { model.saveLine(line) }
                    }
                    .buttonStyle(.primary)
                    .disabled(saved)
                    Button("닫기", action: onClose)
                        .buttonStyle(.ghost)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }
}

// MARK: - 24 Telescope Confirm

/// 24 Turn On Mind Telescope (마음 망원경 켜기): the page behind a bottom sheet
/// that asks to spend coins before a report is made.
struct TelescopeConfirmView: View {
    @Environment(AppModel.self) private var model
    var onStart: () -> Void
    var onCharge: () -> Void
    var onLater: () -> Void

    @State private var showSheet = false
    /// 29 Coin Shortage replaces the 24 content inside the same sheet.
    @State private var short = false
    @State private var sheetHeight: CGFloat = 314
    /// What closed the sheet, run once it is gone.
    @State private var next: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "마음 망원경", onBack: onLater)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("더 멀리 들여다볼까요?")
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)
                Text("모아둔 별을 함께 읽어 흐름을 보여줘요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer()
        }
        .background { StarField() }
        .onAppear { showSheet = true }
        .sheet(isPresented: $showSheet, onDismiss: {
            // A swipe-down counts as "나중에".
            (next ?? onLater)()
            next = nil
        }) {
            Group {
                if short {
                    // 29 Coin Shortage
                    ActionSheetContent(
                        title: "코인이 조금 부족해요",
                        message: "지금 코인 \(model.coins)개예요. 충전하거나 나중에 켤 수 있어요.",
                        primary: ("코인 충전", { close(then: onCharge) }),
                        secondary: ("나중에", { close(then: onLater) }),
                        // Back to the 24 choice.
                        ghost: ("닫기", { withAnimation(.snappy) { short = false } })
                    )
                } else {
                    ActionSheetContent(
                        title: "마음 망원경 켜기",
                        message: "코인 \(AppModel.telescopeCost)개가 사용돼요. 결과는 진단이 아니에요.",
                        primary: ("코인 \(AppModel.telescopeCost)개로 켜기", start),
                        secondary: ("코인 충전", { close(then: onCharge) }),
                        ghost: ("나중에", { close(then: onLater) })
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
            .presentationDetents([.height(sheetHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "telescope-sheet") }
        }
    }

    private func close(then action: @escaping () -> Void) {
        next = action
        showSheet = false
    }

    private func start() {
        if model.spendCoins(AppModel.telescopeCost) {
            close(then: onStart)
        } else {
            withAnimation(.snappy) { short = true }
        }
    }
}

/// Figma `Bottom Sheet` (Actions=3) content: title, message, three buttons.
struct ActionSheetContent: View {
    var title: String
    var message: String
    var primary: (String, () -> Void)
    var secondary: (String, () -> Void)
    var ghost: (String, () -> Void)

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
                Button(primary.0, action: primary.1)
                    .buttonStyle(.primary)
                Button(secondary.0, action: secondary.1)
                    .buttonStyle(.secondary)
                Button(ghost.0, action: ghost.1)
                    .buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xl)
    }
}

// MARK: - 25 Scanning

/// 25 Scanning (스캔 중): shown while the report is made. Leaving is fine;
/// the report keeps being prepared.
struct TelescopeScanView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onDone: () -> Void
    var onBackground: () -> Void

    /// TODO: Replace with the real analysis request.
    private let mockDuration: Duration = .seconds(3)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            KeptHero()
                .padding(.top, Space.sm)

            VStack(spacing: Space.lg) {
                Text("별들을 바라보는 중이에요")
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)
                Text("조금만 기다려 주세요.\n잠시 나가도 괜찮아요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Space.xl)

            Button("백그라운드로 두기") {
                _ = model.prepareReport(for: starID)
                onBackground()
            }
            .buttonStyle(.ghost)
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { StarField() }
        .task {
            try? await Task.sleep(for: mockDuration)
            guard !Task.isCancelled else { return }
            _ = model.prepareReport(for: starID)
            onDone()
        }
    }
}

#Preview("23") {
    StarlightLineView(line: "그런 마음이 어둠 속에서도 조용히 빛나고 있어요.", onClose: {})
        .environment(AppModel())
}

#Preview("24") {
    TelescopeConfirmView(onStart: {}, onCharge: {}, onLater: {})
        .environment(AppModel())
}

#Preview("25") {
    let model = AppModel()
    model.fillSampleStars()
    return TelescopeScanView(starID: model.stars[0].id, onDone: {}, onBackground: {})
        .environment(model)
}
