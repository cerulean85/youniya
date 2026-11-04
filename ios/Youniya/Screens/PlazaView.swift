import SwiftUI

/// Another user's nebula as shown in the plaza. Never includes their text.
struct PlazaNebula: Identifiable, Hashable {
    enum Pattern { case a, b }
    var id: String { name }
    var name: String
    /// One line of starlight left by the owner.
    var line: String
    var pattern: Pattern
    /// Depth distribution: deep / clear / warm (sums to ~1).
    var depth: (deep: Double, clear: Double, warm: Double) = (0.41, 0.31, 0.28)
    /// How close it is to the viewer's own tone (0...1), for "나와 결이 비슷한".
    var similarity: Double
    var order: Int

    static func == (l: Self, r: Self) -> Bool { l.name == r.name }
    func hash(into h: inout Hasher) { h.combine(name) }

    /// TODO: Replace with the plaza API. Samples from Figma `09 우주 광장 · 별`.
    static let samples: [PlazaNebula] = [
        PlazaNebula(name: "고요한 새벽의 고래자리", line: "그런 마음, 저도 알아요.", pattern: .a, similarity: 0.62, order: 0),
        PlazaNebula(name: "늦은 밤의 등대자리", line: "오늘도 여기까지 왔어요.", pattern: .b, similarity: 0.91, order: 1),
        PlazaNebula(name: "비를 기다리는 나무자리", line: "느려도 괜찮은 밤이에요.", pattern: .b, similarity: 0.78, order: 2),
        PlazaNebula(name: "천천히 날아오른 새자리", line: "당신의 별빛이 닿았어요.", pattern: .a, similarity: 0.45, order: 3),
    ]
}

/// 09 Plaza (우주 광장 tab): others' stars as silhouettes; tap to read one line,
/// leave a resonance. No rankings or comments.
struct PlazaView: View {
    var onOpen: (_ title: String) -> Void

    private enum Segment: String, CaseIterable { case star = "별", nebula = "성운" }
    private enum Sort: String, CaseIterable { case newest = "새로 뜬 것", similar = "나와 결이 비슷한" }

    @State private var segment: Segment = .star
    @State private var sort: Sort = .newest
    @Environment(AppModel.self) private var model

    private var items: [PlazaNebula] {
        switch sort {
        case .newest: PlazaNebula.samples.sorted { $0.order < $1.order }
        case .similar: PlazaNebula.samples.sorted { $0.similarity > $1.similarity }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("우주 광장")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                    Text("누군가의 별이에요. 눌러서 한 문장을 읽고, 마음이 닿으면 공명을 남겨 보세요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                segmentControl

                if segment == .star {
                    HStack(spacing: Space.sm) {
                        ForEach(Sort.allCases, id: \.self) { s in
                            Button { withAnimation(.snappy) { sort = s } } label: { sortChip(s) }
                                .buttonStyle(.plain)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.md), GridItem(.flexible(), spacing: Space.md)],
                              spacing: Space.md) {
                        ForEach(items) { item in
                            NebulaCard(item: item, resonated: model.resonated.contains(item.id),
                                       onOpen: { onOpen(item.name) },
                                       onResonate: { model.toggleResonance(item.id) })
                        }
                    }
                } else {
                    // `72 우주 광장 · 성운` is a later screen.
                    ComingSoonView(title: "성운 광장")
                        .frame(height: 280)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.lg)
        }
        .scrollIndicators(.hidden)
    }

    /// Figma `Segment`: pill track, selected segment filled violet.
    private var segmentControl: some View {
        HStack(spacing: Space.xs) {
            ForEach(Segment.allCases, id: \.self) { s in
                let on = segment == s
                Button { withAnimation(.snappy) { segment = s } } label: {
                    Text(s.rawValue)
                        .textStyle(.labelM)
                        .foregroundStyle(on ? Color.textOnBrand : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .background(on ? Color.brandPrimary : .clear, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(Space.xs)
        .background(Color.bgSurfaceRaised, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
    }

    private func sortChip(_ s: Sort) -> some View {
        let on = sort == s
        return HStack(spacing: Space.sm) {
            Circle().fill(Color.brandPrimary).frame(width: 8, height: 8)
            Text(s.rawValue)
                .textStyle(.labelS)
                .foregroundStyle(on ? Color.textPrimary : Color.textSecondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(on ? Color.tintPrimary : Color.bgSurface, in: .capsule)
        .overlay(Capsule().strokeBorder(on ? Color.brandPrimary : Color.borderDefault, lineWidth: 1))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Figma `Nebula Card`: silhouette, depth bar, name, one line, resonance.
struct NebulaCard: View {
    var item: PlazaNebula
    var resonated: Bool
    var onOpen: () -> Void
    var onResonate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Image(item.pattern == .a ? .plazaSilhouetteA : .plazaSilhouetteB)
                        .resizable()
                        .aspectRatio(141 / 110, contentMode: .fit)
                    Text(item.name)
                        .textStyle(.labelS)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Text(item.line)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                    depthBar
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)

            Button(action: onResonate) {
                HStack(spacing: Space.xs) {
                    Image(.plazaStarShape)
                        .resizable()
                        .frame(width: 12.26, height: 12.26)
                        .frame(width: 12, height: 12)
                        .opacity(resonated ? 1 : 0.6)
                    Text(resonated ? "공명했어요" : "공명")
                        .textStyle(.labelS)
                        .foregroundStyle(Color.brandPrimary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(resonated ? .isSelected : [])
        }
        .padding(Space.md)
        .cosmos(item.name, in: RoundedRectangle(cornerRadius: Radius.lg))
        .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg)
            .strokeBorder(resonated ? Color.brandPrimary : Color.borderDefault, lineWidth: 1))
    }

    /// Figma `Depth Bar`: three flat segments (deep / clear / warm).
    private var depthBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.brandPrimary.frame(width: geo.size.width * item.depth.deep)
                Color.starClear.frame(width: geo.size.width * item.depth.clear)
                Color.brandWarm
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

#Preview {
    PlazaView(onOpen: { _ in })
        .environment(AppModel())
        .background(Color.bgCanvas)
}
