import SwiftUI

/// 10 Mind Telescope Report: three lenses, emotion mix, a quoted sentence,
/// and a question to ask oneself.
struct TelescopeReportView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onClose: () -> Void
    /// "이 주제로 다시 쓰기" → 14 Rewrite
    var onRewrite: () -> Void

    var body: some View {
        if model.report(for: starID) == nil {
            // 122, with the report's title
            NotFoundView(title: "리포트를 찾을 수 없어요", onBack: onClose)
        } else {
            reportBody
        }
    }

    private var reportBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                FlowTopBar(title: "마음 망원경 리포트", onClose: onClose)

                if let report = model.report(for: starID) {
                    header(report)
                    lenses(report)
                    emotionChart(report)
                    evidence(report)
                    question(report)

                    Button("이 주제로 다시 쓰기") { onRewrite() }
                        .buttonStyle(.primary)
                    Button(report.isSaved ? "보관된 리포트예요" : "리포트 보관하기") {
                        model.saveReport(for: starID)
                    }
                    .buttonStyle(.ghost)
                    .disabled(report.isSaved)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxxl)
        }
        .scrollIndicators(.hidden)
        .background { StarField() }
    }

    private func header(_ r: TelescopeReport) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("오늘의 별에 붙은 이름")
                .textStyle(.caption)
                .foregroundStyle(Color.textTertiary)
            Text(r.starName)
                .textStyle(.h1)
                .foregroundStyle(Color.starBright)
            Text("세 가지 렌즈로 마음의 결을 비춰봤어요. 평가나 처방이 아니라, 곁에서 함께 바라본 기록이에요.")
                .textStyle(.bodyM)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func lenses(_ r: TelescopeReport) -> some View {
        card(title: "세 가지 렌즈", spacing: Space.lg) {
            ForEach(r.lenses, id: \.label) { lens in
                VStack(alignment: .leading, spacing: Space.xs) {
                    AxisMeter(label: lens.label, value: lens.value)
                    Text(lens.note)
                        .textStyle(.bodyS)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func emotionChart(_ r: TelescopeReport) -> some View {
        card(title: "감정의 결") {
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(r.emotions, id: \.mood) { share in
                        share.mood.color
                            .frame(width: geo.size.width * Double(share.percent) / 100)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(.capsule)
            .accessibilityHidden(true)

            HStack(spacing: Space.lg) {
                ForEach(r.emotions, id: \.mood) { share in
                    HStack(spacing: Space.xs) {
                        Circle().fill(share.mood.color).frame(width: 8, height: 8)
                        Text("\(share.mood.label) \(share.percent)%")
                            .textStyle(.labelS)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func evidence(_ r: TelescopeReport) -> some View {
        card(title: "근거가 된 문장") {
            HStack(alignment: .top, spacing: Space.md) {
                Color.brandPrimary.frame(width: 2)
                Text(r.evidence)
                    .textStyle(.observation)
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func question(_ r: TelescopeReport) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("스스로 물어볼 질문")
                .textStyle(.labelS)
                .foregroundStyle(Color.brandPrimaryText)
            Text(r.question)
                .textStyle(.h3)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .cosmos("report-question", in: RoundedRectangle(cornerRadius: Radius.lg))
        .background(Color.bgSurfaceRaised, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    /// Surface card with a section title.
    private func card<Content: View>(title: String, spacing: CGFloat = Space.md, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title)
                .textStyle(.labelM)
                .foregroundStyle(Color.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .cosmos("report-" + title, in: RoundedRectangle(cornerRadius: Radius.lg))
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
    }
}
