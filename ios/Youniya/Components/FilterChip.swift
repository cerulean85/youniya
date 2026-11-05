import SwiftUI

/// Figma `Chip` (Tone Default, Selected True/False): a 34pt capsule with a
/// faint Cosmos BG. Selected: violet tint and violet border.
struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyleBox(.labelS)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
                .cosmos("chip-\(title)", in: Capsule(), intensity: 0.6)
                .background(isSelected ? Color.tintPrimary : Color.bgSurface, in: .capsule)
                .overlay(Capsule().strokeBorder(isSelected ? Color.hex(0x8555EF) : Color.borderDefault, lineWidth: 1))
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Figma `Tag` used as a small segmented choice (82 range): solid violet when on.
struct RangeTag: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyleBox(.labelS)
                .foregroundStyle(isSelected ? Color.white : Color.textSecondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs)
                .background(isSelected ? Color.hex(0x8555EF) : Color.bgSurfaceRaised, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
