import SwiftUI

/// Figma `Chip`: emotion tone tag. Selected chips take the tone's tint and border.
struct MoodTag: View {
    var mood: Mood
    var isSelected: Bool = true

    var body: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(mood.color)
                .frame(width: 8, height: 8)
            Text(mood.label)
                .textStyle(.labelS)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(isSelected ? mood.tint : Color.bgSurface, in: .capsule)
        .overlay(Capsule().strokeBorder(isSelected ? mood.color : Color.borderDefault, lineWidth: 1))
    }
}

/// Tappable `MoodTag` for picking a mood.
struct MoodChip: View {
    var mood: Mood
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MoodTag(mood: mood, isSelected: isSelected)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack(spacing: Space.sm) {
        ForEach(Mood.allCases) { MoodChip(mood: $0, isSelected: $0 == .calm) {} }
    }
    .padding()
    .background(Color.bgCanvas)
}
