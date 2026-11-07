import SwiftUI

// v1.1 멤버십 장면 테마 (Figma "Themes · 우주의 색" 348:7090 / 348:7292 / 348:7499).
// Drawn by `StarField`, above the stars and below the content, on the same
// 390×844 canvas. Performance (FIGMA review): blurs are rendered once and only
// moved or faded; at most 30 fps; still when hidden, in the background, in Low
// Power Mode, with Reduce Motion / "애니메이션 줄이기", and on writing screens.

extension EnvironmentValues {
    /// A member's sky with its scene (or `-debugTheme aurora+` for the review).
    @Entry var skyScene = false
}

extension SkyTheme {
    /// The member skies that come with a scene.
    var hasScene: Bool { self == .aurora || self == .ember || self == .rose }
    /// Rose+: the star field at 60%.
    var sceneStarOpacity: Double { self == .rose ? 0.6 : 1 }
    /// The alternate app icon for this sky (nil: the default icon).
    var appIconName: String? {
        switch self {
        case .aurora: "AppIcon-Aurora"
        case .ember: "AppIcon-Ember"
        case .rose: "AppIcon-Rose"
        default: nil
        }
    }
}

/// Pre-rendered blurred pieces: the blur is drawn once, then the scene only
/// moves and fades them (offset and opacity, composited on the GPU).
@MainActor
private enum SceneSprites {
    private static var cache: [String: Image] = [:]

    static func image<V: View>(_ key: String, @ViewBuilder _ view: () -> V) -> Image {
        if let hit = cache[key] { return hit }
        let renderer = ImageRenderer(content: view())
        renderer.scale = 2
        let image = renderer.uiImage.map { Image(uiImage: $0) } ?? Image(systemName: "circle")
        cache[key] = image
        return image
    }

    /// Aurora+: one soft band (520×90 plus the blur margin).
    static func band(_ i: Int, _ colors: [Color]) -> Image {
        image("band\(i)") {
            Capsule()
                .fill(LinearGradient(colors: colors.map { $0.opacity(0.8) } + [.clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 520, height: 90)
                .blur(radius: 28)
                .padding(60)
        }
    }

    /// Rose+: a soft pink cloud.
    static var cloud: Image {
        image("cloud") {
            Ellipse().fill(Color.hex(0xF9A8D4).opacity(0.16))
                .frame(width: 240, height: 78)
                .blur(radius: 18)
                .padding(40)
        }
    }

    /// Ember+: one glowing ember.
    static func ember(_ warm: Bool) -> Image {
        image("ember\(warm)") {
            Circle().fill(warm ? Color.hex(0xFBBF24) : Color.hex(0xFB923C))
                .frame(width: 3, height: 3)
                .shadow(color: .hex(0xF97316), radius: 3)
                .padding(6)
        }
    }
}

extension EnvironmentValues {
    /// v1.1: the scene moves only where the night sky is the point (04, nebula,
    /// plaza tabs). Writing and reading screens keep it still.
    @Entry var sceneMotion = false
    /// Home (04): the aurora forest sits under the hero constellation instead
    /// of behind the tab bar.
    @Entry var sceneOnHome = false
}

struct SkySceneLayer: View {
    var sky: SkyTheme
    /// Reduce Motion or the app's "애니메이션 줄이기".
    var still: Bool

    @Environment(\.sceneMotion) private var sceneMotion
    @Environment(\.sceneOnHome) private var onHome
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// Rose+: the dawn brightens over 1.5 s when the app opens.
    @State private var dawn = 0.0

    /// Stopped scenes stay as they are (the last frame).
    private var paused: Bool { still || lowPower || !sceneMotion || !visible || scenePhase != .active }

    var body: some View {
        // At most 30 fps; one timeline drives every piece.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            switch sky {
            case .aurora: aurora(t)
            case .ember: ember(t)
            case .rose: rose(t)
            default: EmptyView()
            }
        }
        .onAppear {
            visible = true
            guard sky == .rose else { return }
            if paused { dawn = 1 } else { withAnimation(.easeOut(duration: 1.5)) { dawn = 1 } }
        }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .allowsHitTesting(false)
    }

    private static func wave(_ t: Double, _ period: Double, phase: Double = 0) -> Double {
        sin((t / period + phase) * 2 * .pi)
    }

    // MARK: Aurora+

    /// Three bands (14 / 18 / 22 s, ±24 pt across, ±8 pt up and down, opacity
    /// 0.35↔0.6 over 9 s) and a still forest along the bottom.
    private func aurora(_ t: Double) -> some View {
        let glow = 0.475 + 0.125 * Self.wave(t, 9)
        let bands: [(y: CGFloat, period: Double, colors: [Color])] = [
            (150, 14, [.hex(0x10B981), .hex(0x2DD4BF)]),
            (210, 18, [.hex(0x2DD4BF), .hex(0x3B82F6)]),
            (110, 22, [.hex(0x34D399), .hex(0x10B981)]),
        ]
        return ZStack(alignment: .topLeading) {
            ForEach(bands.indices, id: \.self) { i in
                let b = bands[i]
                SceneSprites.band(i, b.colors)
                    .rotationEffect(.degrees([-8, 6, -3][i]))
                    .opacity(glow)
                    .offset(x: -125 + 24 * Self.wave(t, b.period, phase: Double(i) * 0.3),
                            y: b.y - 60 + 8 * Self.wave(t, b.period, phase: Double(i) * 0.3 + 0.25))
            }
            ForestSilhouette()
                .fill(Color.hex(0x04110E).opacity(0.92))
                .frame(width: 390, height: onHome ? 90 : 140)
                // 04: fade out at the foot so it doesn't end in a hard edge.
                .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                             .init(color: .black, location: onHome ? 0.55 : 1),
                                             .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                // 04: y 240–330, behind "최근 별"; elsewhere along the bottom.
                .offset(y: onHome ? 240 : 844 - 140)
        }
    }

    // MARK: Ember+

    /// A sunset horizon (brightness 0.85↔1.0 over 8 s) and 24 embers rising
    /// over 6–12 s, fading as they go.
    private func ember(_ t: Double) -> some View {
        let glow = 0.925 + 0.075 * Self.wave(t, 8)
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.clear, .hex(0xF43F5E).opacity(0.25), .hex(0xF97316).opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: 390, height: 320)
                .opacity(glow)
                .offset(y: 844 - 320)
            ForEach(0..<24, id: \.self) { i in
                var rng = SeededRandom(seed: "ember-\(i)")
                let period = rng.next(in: 6...12)
                let phase = rng.next(in: 0...1)
                let x = rng.next(in: 10...380)
                let p = (t / period + phase).truncatingRemainder(dividingBy: 1)
                SceneSprites.ember(i % 3 == 0)
                    .opacity((1 - p) * 0.9)
                    .offset(x: x - 7.5 + 10 * sin(p * 6), y: 844 - 47.5 - p * 480)
            }
        }
    }

    // MARK: Rose+

    /// Dawn brightening toward the bottom, and five pink clouds drifting
    /// left to right over 40–60 s.
    private func rose(_ t: Double) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.clear, .hex(0xEC4899).opacity(0.18), .hex(0xFB923C).opacity(0.3)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: 390, height: 420)
                .opacity(0.5 + 0.5 * dawn)
                .offset(y: 844 - 420)
            ForEach(0..<5, id: \.self) { i in
                var rng = SeededRandom(seed: "rose-cloud-\(i)")
                let period = rng.next(in: 40...60)
                let phase = rng.next(in: 0...1)
                let y = rng.next(in: 420...760)
                let k = rng.next(in: 0.7...1.1)
                let p = (t / period + phase).truncatingRemainder(dividingBy: 1)
                SceneSprites.cloud
                    .scaleEffect(k)
                    .offset(x: -320 + p * 710, y: y - 79)
            }
        }
    }
}

/// Aurora+: a row of pine trees along the bottom of the canvas.
private struct ForestSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: "forest")
        return Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            var x = rect.minX - 10
            while x < rect.maxX + 10 {
                let w = rng.next(in: 22...40)
                let h = rng.next(in: 50...Double(rect.height))
                p.addLine(to: CGPoint(x: x, y: rect.maxY - h * 0.25))
                p.addLine(to: CGPoint(x: x + w / 2, y: rect.maxY - h))
                p.addLine(to: CGPoint(x: x + w, y: rect.maxY - h * 0.25))
                x += w * 0.8
            }
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
