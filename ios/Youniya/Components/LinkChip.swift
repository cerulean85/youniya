import SwiftUI

/// Figma `Link Chip`: small pill link with a Cosmos BG (08, 17).
struct LinkChip: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.labelS)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs)
                .frame(minHeight: 32)
                .cosmos("chip-\(title)", in: Capsule(), intensity: 0.6)
                .background(Color.bgSurfaceRaised, in: .capsule)
                .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}
