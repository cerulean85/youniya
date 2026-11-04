import SwiftUI

/// Figma `Axis Meter`: one of the three measuring axes as a thin gauge.
struct AxisMeter: View {
    var label: String
    var value: Double
    var color: Color = .brandPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(label)
                .textStyle(.labelS)
                .foregroundStyle(Color.textSecondary)
            Capsule()
                .fill(Color.borderDefault)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * min(1, max(0, value)))
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((value * 100).rounded()))%")
    }
}

/// Figma `Today Star Card` (07): starlight, three axes, a gentle observation, tones.
struct TodayStarCard: View {
    var analysis: StarAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Text("오늘의 별 카드")
                    .textStyle(.labelS)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                StarlightBadge(value: analysis.starlight)
            }

            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("\(analysis.starlight)")
                    .textStyle(.metric)
                    .foregroundStyle(Color.textPrimary)
                Text("별빛")
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textSecondary)
            }
            .accessibilityElement(children: .combine)

            Text(analysis.observation)
                .textStyle(.observation)
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Space.md) {
                AxisMeter(label: "별의 깊이", value: analysis.depth, color: .brandPrimary)
                AxisMeter(label: "빛의 선명함", value: analysis.clarity, color: .starClear)
                AxisMeter(label: "마음의 무게", value: analysis.weight, color: .brandWarm)
            }

            HStack(spacing: Space.sm) {
                ForEach(analysis.tones) { MoodTag(mood: $0) }
            }
        }
        .padding(Space.xl)
        .cosmos("card-\(analysis.starlight)-\(analysis.observation.count)", in: RoundedRectangle(cornerRadius: Radius.xl))
        .background(
            LinearGradient(
                stops: [.init(color: .bgSurfaceRaised, location: 0), .init(color: .bgSurface, location: 0.714)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: Radius.xl)
        )
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(Color.borderFocus, lineWidth: 1))
        // Elevation/Card: #000 @ 40%, y 8, blur 24
        .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
    }
}

#Preview {
    TodayStarCard(analysis: StarItem.samples[0].analysis!)
        .padding(24)
        .background(Color.bgCanvas)
}
