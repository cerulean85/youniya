import SwiftUI

/// Figma `Star Row`: Floated stars show a starlight badge, kept stars a label.
struct StarRow: View {
    var star: StarItem

    var body: some View {
        HStack(spacing: Space.md) {
            Image(star.isFloated ? .starShapeFloated : .starShapeKept)
                .resizable()
                .frame(width: 18.14, height: 18.14)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text(star.title)
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textPrimary)
                Text(star.dateText)
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            switch star.state {
            case .floated(let starlight):
                StarlightBadge(value: starlight)
            case .kept:
                Text("간직한 별")
                    .textStyle(.labelS)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(Space.lg)
        .cosmos(star.id.uuidString, in: RoundedRectangle(cornerRadius: Radius.lg))
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Figma `Starlight Badge` (Standard tier). Shows "—" before analysis.
struct StarlightBadge: View {
    var value: Int?

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(.starShapeBadge)
                .resizable()
                .frame(width: 14.22, height: 14.22)
                .frame(width: 14, height: 14)
            Text(value.map(String.init) ?? "—")
                .textStyle(.labelM)
                .foregroundStyle(Color.textPrimary)
            Text("별빛")
                .textStyle(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .background(Color.tintPrimary, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.brandPrimary, lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(StarItem.samples) { StarRow(star: $0) }
    }
    .padding(24)
    .background(Color.bgCanvas)
}
