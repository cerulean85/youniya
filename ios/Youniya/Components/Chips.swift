import SwiftUI

// Shared chips and layout: DotChip (filters), Tag (labels), FlowRow (wrapping rows).

/// Figma `Chip` with a leading dot (09 sort, 72 filter).
struct DotChip: View {
    @Environment(\.skyTheme) private var theme
    var title: String
    var isSelected: Bool
    var dot: Color = .brandPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(title)
                    .textStyle(.labelS)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .background(isSelected ? theme.accent.tint.opacity(0.16) : Color.bgSurface, in: .capsule)
            .overlay(Capsule().strokeBorder(isSelected ? theme.accent.strong : Color.borderDefault, lineWidth: 1))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Figma `Tag`: small capsule label.
struct Tag: View {
    enum Tone { case gold, violet, neutral }
    var text: String
    var tone: Tone

    var body: some View {
        Text(text)
            .textStyle(.labelS)
            .foregroundStyle(tone == .gold ? Color.starBright : tone == .violet ? Color.brandPrimaryText : Color.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(tone == .gold ? Color.tintGold : tone == .violet ? Color.tintPrimary : Color.bgSurfaceRaised, in: .capsule)
    }
}

/// Wraps chips onto new lines.
struct FlowRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in rows(bounds.width, subviews).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxW: CGFloat = 0
        var pts: [CGPoint] = []
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            maxW = max(maxW, x - spacing)
        }
        return (pts, CGSize(width: maxW, height: y + rowH))
    }
}

// MARK: - 73 / 78 Someone's nebula

// MARK: - 74 Starlight line (nebula)

extension View {
    /// Figma plaza cards (73, 74): surface, Cosmos BG, flat slate border.
    func flatCard(seed: String) -> some View {
        cosmos(seed, in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
    }
}

/// A small on-device first pass. TODO: Replace with the reviewed server filter.
