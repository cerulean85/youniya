import SwiftUI

/// 12-2 마음 망원경 (398:16202), inside the star page since 2026-11-08: what
/// clouded the writing, how the mood moved, and a question to ask oneself.
/// It folds like the 별빛 풀이. Parts the server hasn't sent are left out.
struct TelescopeSection: View {
    var report: TelescopeReport
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("마음 망원경 · \(report.starName)")
                    .textStyle(.h3)
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(isOpen ? "접기 ▴" : "펼치기 ▾") {
                    withAnimation(.easeInOut(duration: 0.3)) { isOpen.toggle() }
                }
                .textStyle(.labelS)
                .foregroundStyle(Color.textSecondary)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }

            if isOpen {
                if let fog = report.fogItems, !fog.isEmpty { fogCard(fog) }
                flowCard
                questionCard
            }
        }
    }

    private func fogCard(_ items: [TelescopeReport.Fog]) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("마음을 가린 안개").textStyle(.labelM).foregroundStyle(Color.textPrimary)
            Text("글 속에서 마음을 조금 흐리게 만든 말버릇이에요. 고칠 점이 아니라, 알아차릴 자리예요.")
                .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(items, id: \.self) { f in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(f.kind).textStyle(.labelS).foregroundStyle(Color.starBright)
                    Text("“\(f.sentence)”").textStyle(.observation).foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(f.note).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .itemCard(seed: "fog", minHeight: 0)
    }

    private var flowCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("감정의 결과 흐름").textStyle(.labelM).foregroundStyle(Color.textPrimary)
            // The shares as one bar, with a legend.
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(report.emotions, id: \.self) { e in
                        Capsule().fill(e.mood.color)
                            .frame(width: max(4, g.size.width * CGFloat(e.percent) / 100 - 2))
                    }
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
            FlowRow(spacing: Space.md) {
                ForEach(report.emotions, id: \.self) { e in
                    HStack(spacing: 4) {
                        Circle().fill(e.mood.color).frame(width: 6, height: 6)
                        Text("\(e.mood.label) \(e.percent)%").textStyle(.caption).foregroundStyle(Color.textSecondary)
                    }
                }
            }
            if let flow = report.moodFlow, !flow.isEmpty {
                ForEach(flow, id: \.self) { f in
                    HStack(alignment: .top, spacing: Space.md) {
                        Text(f.part).textStyle(.caption).foregroundStyle(Color.textTertiary)
                            .frame(width: 52, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.moods).textStyle(.labelS).foregroundStyle(Color.textPrimary)
                            Text(f.note).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if let text = report.moodInterpretation {
                Text(text).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Older reports: the sentence it rested on.
                Text("“\(report.evidence)”").textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .itemCard(seed: "flow", minHeight: 0)
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("스스로 물어볼 질문").textStyle(.labelS).foregroundStyle(Color.brandPrimaryText)
            Text(report.question).textStyle(.h3).foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .background(Color.tintPrimary, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.brandPrimary.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
