import SwiftUI

/// 56–60 스토리: how a nebula forms, in five steps. Shown once.
struct NebulaStoryIntroView: View {
    var onFinish: () -> Void

    private struct Page {
        var title: String
        var sub: String
        /// Stars in the Figma frame (center, diameter, color) and lines between them.
        var stars: [(CGPoint, CGFloat, Color)]
        var lines: [(Int, Int)]
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static let pages: [Page] = [
        Page(title: "첫 별이 떴어요", sub: "어느 밤, 마음 하나가 조용히 빛나기 시작했어요.",
             stars: [(p(195, 333), 36, .starBright)], lines: []),
        Page(title: "곁에 또 하나", sub: "슬픔 옆에서 다른 마음도 깨어났어요.",
             stars: [(p(134, 313), 22, .starBright), (p(254, 363), 22, .emotionSorrow)], lines: [(0, 1)]),
        Page(title: "빛이 이어졌어요", sub: "서로 다른 마음이 천천히 이어지고 있어요.",
             stars: [(p(114, 293), 20, .starBright), (p(224, 263), 18, .emotionCalm), (p(274, 373), 20, .brandPrimary)],
             lines: [(0, 1), (1, 2)]),
        Page(title: "성운이 흐르기 시작해요", sub: "모인 별들이 하나의 모양을 이루어요.",
             stars: [(p(104, 273), 18, .starBright), (p(194, 343), 24, .brandWarm), (p(284, 283), 18, .emotionCalm), (p(224, 413), 16, .emotionSorrow)],
             lines: [(0, 1), (1, 2), (2, 3)]),
        Page(title: "이것이 나의 성운이에요", sub: "빠르지도 느리지도 않게, 당신의 속도로 만들어졌어요.",
             stars: [(p(94, 263), 16, .starBright), (p(184, 313), 20, .brandWarm), (p(274, 263), 16, .emotionCalm),
                     (p(144, 403), 18, .emotionSorrow), (p(254, 403), 18, .brandPrimary)],
             lines: [(0, 1), (1, 2), (2, 3), (3, 4)]),
    ]

    @State private var index = 0

    var body: some View {
        let page = Self.pages[index]
        let last = index == Self.pages.count - 1
        VStack(spacing: 0) {
            // Figma progress: five 3pt bars, filled up to this page.
            HStack(spacing: Space.xs) {
                ForEach(Self.pages.indices, id: \.self) { i in
                    Capsule().fill(i <= index ? Color.hex(0x8555EF) : Color.borderDefault).frame(height: 3)
                }
            }
            .padding(.top, Space.xl)
            .accessibilityElement()
            .accessibilityLabel("\(Self.pages.count)장 중 \(index + 1)장")

            VStack(spacing: Space.lg) {
                Text(page.title).textStyle(.h2).foregroundStyle(Color.textPrimary)
                Text(page.sub).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, Space.xl)
            .id(index)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            // Figma `Stage` (342×320, top at 173): coordinates are frame points.
            GeometryReader { geo in
                let dx = (geo.size.width - 342) / 2 - 24
                let at: (CGPoint) -> CGPoint = { CGPoint(x: $0.x + dx, y: $0.y - 173) }
                ZStack(alignment: .topLeading) {
                    ForEach(page.lines.indices, id: \.self) { i in
                        let (a, b) = page.lines[i]
                        Path { p in
                            p.move(to: at(page.stars[a].0))
                            p.addLine(to: at(page.stars[b].0))
                        }
                        .stroke(Color.starClear, lineWidth: 1.2)
                    }
                    ForEach(page.stars.indices, id: \.self) { i in
                        let s = page.stars[i]
                        Circle().fill(s.2)
                            .frame(width: s.1, height: s.1)
                            .shadow(color: s.2.opacity(0.5), radius: 10)
                            .position(at(s.0))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
            .frame(height: 320)
            .padding(.top, Space.md)
            .accessibilityHidden(true)

            Spacer(minLength: 0)

            VStack(spacing: Space.md) {
                Button(last ? "성운 보러 가기" : "다음") {
                    if last { onFinish() } else { withAnimation(.easeInOut(duration: 0.5)) { index += 1 } }
                }
                .buttonStyle(.primary)
                if !last {
                    Button("건너뛰기", action: onFinish).buttonStyle(.ghost)
                }
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.xl)
        .background { StarField() }
        .contentShape(.rect)
        // Swipe left/right between pages.
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            withAnimation(.easeInOut(duration: 0.4)) {
                if v.translation.width < -40, index < Self.pages.count - 1 { index += 1 }
                if v.translation.width > 40, index > 0 { index -= 1 }
            }
        })
    }
}

#Preview {
    NebulaStoryIntroView(onFinish: {})
}
