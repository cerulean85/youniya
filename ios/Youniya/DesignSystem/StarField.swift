import SwiftUI

/// `BG/Star Field` from Figma: three nebula glows, twinkling dust,
/// and two faint constellations, laid out on a 390×844 canvas and
/// scaled to the screen width.
struct StarField: View {
    private static let canvas = CGSize(width: 390, height: 844)
    @Environment(\.motionReduced) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / Self.canvas.width
            ZStack(alignment: .topLeading) {
                Color.bgCanvas

                Group {
                    place(.nebulaViolet, x: 150, y: -140, w: 420, h: 420)
                    place(.nebulaPink, x: -160, y: 520, w: 420, h: 420)
                    place(.nebulaCyan, x: 200, y: 360, w: 260, h: 260)
                    place(.constellation0, x: 48, y: 119.56, w: 182.364, h: 48.9005)
                    place(.constellation1, x: 259.77, y: 599.45, w: 90.5463, h: 60.7564)
                }

                // One timeline drives all dots (cheaper than one per dot).
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(Self.dots.enumerated()), id: \.offset) { _, d in
                            let track = Twinkle(duration: 6, keys: d.keys)
                            Circle()
                                .fill(Color.textPrimary)
                                .frame(width: d.size, height: d.size)
                                .opacity(reduceMotion ? d.keys[0].1 : track.opacity(at: t))
                                .offset(x: d.x, y: d.y)
                        }
                    }
                }
            }
            .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            // Taller screens than the 390×844 canvas keep the canvas color below.
            .background(Color.bgCanvas)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func place(_ image: ImageResource, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        Image(image)
            .resizable()
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }

    private struct Dot {
        var x: CGFloat, y: CGFloat, size: CGFloat
        var keys: [(Double, Double)]
    }

    /// Dust (46) and constellation stars (7). Positions and 6s opacity keyframes
    /// come from the Figma `BG/Star Field` component.
    private static let dots: [Dot] = [
        Dot(x: 191.26, y: 473.31, size: 3, keys: [(0, 0.372), (0.07667, 0.08), (0.35, 0.37)]),
        Dot(x: 172.85, y: 427.39, size: 3, keys: [(0, 0.689), (0.195, 0.08), (0.425, 0.489)]),
        Dot(x: 229.87, y: 346.74, size: 1.5, keys: [(0, 0.579), (0.07667, 0.08), (0.26333, 0.579), (0.44833, 0.43)]),
        Dot(x: 29.87, y: 420.78, size: 1.5, keys: [(0, 0.329), (0.14, 0.08), (0.28167, 0.329), (0.42333, 0.26)]),
        Dot(x: 218.56, y: 411.24, size: 2, keys: [(0, 0.72), (0.145, 0.08), (0.41, 0.608)]),
        Dot(x: 378.26, y: 101.93, size: 1.5, keys: [(0, 0.345), (0.02667, 0.08), (0.24667, 0.345), (0.46667, 0.259)]),
        Dot(x: 163.5, y: 464.46, size: 2, keys: [(0, 0.335), (0.12167, 0.08), (0.29667, 0.335), (0.47333, 0.313)]),
        Dot(x: 384.39, y: 376.13, size: 1.5, keys: [(0, 0.415), (0.03333, 0.08), (0.165, 0.415), (0.29667, 0.08), (0.42833, 0.134)]),
        Dot(x: 59.9, y: 652.27, size: 2, keys: [(0, 0.29), (0.21, 0.08), (0.46333, 0.18)]),
        Dot(x: 361.24, y: 201.42, size: 2, keys: [(0, 0.368), (0.08333, 0.08), (0.29333, 0.368), (0.50167, 0.346)]),
        Dot(x: 235.16, y: 339.07, size: 1.5, keys: [(0, 0.318), (0.16, 0.08), (0.325, 0.318), (0.49167, 0.317)]),
        Dot(x: 87.31, y: 380.11, size: 3, keys: [(0, 0.274), (0.065, 0.08), (0.18667, 0.274), (0.30833, 0.08), (0.42833, 0.097)]),
        Dot(x: 160.78, y: 574.71, size: 1.5, keys: [(0, 0.412), (0.02333, 0.08), (0.26833, 0.412), (0.51167, 0.363)]),
        Dot(x: 170.92, y: 418.44, size: 1.5, keys: [(0, 0.475), (0.13333, 0.08), (0.33333, 0.475)]),
        Dot(x: 171.33, y: 222.87, size: 1.5, keys: [(0, 0.316), (0.03667, 0.08), (0.19167, 0.316), (0.34833, 0.084)]),
        Dot(x: 105.44, y: 647.06, size: 1.5, keys: [(0, 0.713), (0.22333, 0.08), (0.50167, 0.285)]),
        Dot(x: 335.55, y: 630.79, size: 1.5, keys: [(0, 0.262), (0.08667, 0.08), (0.32167, 0.262), (0.555, 0.261)]),
        Dot(x: 126.22, y: 301.72, size: 2, keys: [(0, 0.593), (0.17833, 0.08), (0.36833, 0.558)]),
        Dot(x: 287.52, y: 225.11, size: 2, keys: [(0, 0.43), (0.07333, 0.08), (0.22, 0.43), (0.365, 0.114)]),
        Dot(x: 228.45, y: 372.31, size: 3, keys: [(0, 0.745), (0.02, 0.08), (0.28833, 0.745), (0.55667, 0.707)]),
        Dot(x: 177.94, y: 736.23, size: 2, keys: [(0, 0.313), (0.145, 0.08), (0.36833, 0.301)]),
        Dot(x: 309.35, y: 756.44, size: 2, keys: [(0, 0.327), (0.03833, 0.08), (0.21833, 0.327), (0.39833, 0.147)]),
        Dot(x: 275.76, y: 588.87, size: 1.5, keys: [(0, 0.365), (0.10667, 0.08), (0.24167, 0.365), (0.37667, 0.141)]),
        Dot(x: 323.92, y: 142.36, size: 3, keys: [(0, 0.291), (0.09, 0.08), (0.34833, 0.29)]),
        Dot(x: 8.19, y: 453.32, size: 1.5, keys: [(0, 0.323), (0.19667, 0.08), (0.41, 0.257)]),
        Dot(x: 192.67, y: 43.93, size: 2, keys: [(0, 0.282), (0.08333, 0.08), (0.25167, 0.282), (0.42167, 0.188)]),
        Dot(x: 138.71, y: 194.38, size: 1.5, keys: [(0, 0.318), (0.00667, 0.08), (0.13167, 0.318), (0.25833, 0.08), (0.38333, 0.239)]),
        Dot(x: 64.19, y: 0.76, size: 2, keys: [(0, 0.452), (0.155, 0.08), (0.40333, 0.39)]),
        Dot(x: 42.53, y: 403.46, size: 2, keys: [(0, 0.628), (0.04, 0.08), (0.24333, 0.628), (0.44667, 0.408)]),
        Dot(x: 176.05, y: 623.6, size: 1.5, keys: [(0, 0.608), (0.12167, 0.08), (0.28, 0.608), (0.44, 0.486)]),
        Dot(x: 249.28, y: 226.14, size: 2, keys: [(0, 0.691), (0.09333, 0.08), (0.375, 0.664)]),
        Dot(x: 32.32, y: 57.71, size: 2, keys: [(0, 0.265), (0.21333, 0.08), (0.45167, 0.173)]),
        Dot(x: 234.15, y: 370.97, size: 1.5, keys: [(0, 0.703), (0.09, 0.08), (0.28333, 0.703), (0.47667, 0.617)]),
        Dot(x: 205.97, y: 355.79, size: 3, keys: [(0, 0.699), (0.005, 0.08), (0.155, 0.699), (0.30333, 0.08), (0.45333, 0.131)]),
        Dot(x: 258.18, y: 421.02, size: 1.5, keys: [(0, 0.479), (0.16333, 0.08), (0.435, 0.363)]),
        Dot(x: 377.16, y: 747.74, size: 2, keys: [(0, 0.601), (0.04, 0.08), (0.26667, 0.601), (0.49333, 0.508)]),
        Dot(x: 307.05, y: 772.07, size: 1.5, keys: [(0, 0.568), (0.135, 0.08), (0.31833, 0.568), (0.50167, 0.561)]),
        Dot(x: 323.51, y: 371.58, size: 3, keys: [(0, 0.736), (0.04333, 0.08), (0.18167, 0.736), (0.32167, 0.08), (0.46, 0.089)]),
        Dot(x: 216.42, y: 550.55, size: 1.5, keys: [(0, 0.641), (0.23, 0.08), (0.49167, 0.262)]),
        Dot(x: 195.87, y: 374.74, size: 1.5, keys: [(0, 0.276), (0.09667, 0.08), (0.315, 0.276), (0.53167, 0.273)]),
        Dot(x: 143.92, y: 394.08, size: 1.5, keys: [(0, 0.327), (0.00167, 0.08), (0.175, 0.327), (0.34833, 0.084)]),
        Dot(x: 264, y: 142.28, size: 1.5, keys: [(0, 0.407), (0.075, 0.08), (0.20333, 0.407), (0.33333, 0.08)]),
        Dot(x: 8.42, y: 809.82, size: 2, keys: [(0, 0.444), (0.03833, 0.08), (0.29, 0.444), (0.54167, 0.423)]),
        Dot(x: 71.72, y: 554.99, size: 1.5, keys: [(0, 0.403), (0.14833, 0.08), (0.35667, 0.395)]),
        Dot(x: 354, y: 505.73, size: 1.5, keys: [(0, 0.339), (0.04667, 0.08), (0.21, 0.339), (0.37333, 0.112)]),
        Dot(x: 134.23, y: 352.05, size: 1.5, keys: [(0, 0.293), (0.10167, 0.08), (0.22, 0.293), (0.34, 0.081)]),
        // Constellation stars
        Dot(x: 46, y: 148, size: 4, keys: [(0, 0.5), (0.10333, 0.15), (0.34333, 0.499)]),
        Dot(x: 108, y: 118, size: 4, keys: [(0, 0.5), (0.195, 0.15), (0.39333, 0.433)]),
        Dot(x: 168, y: 166, size: 4, keys: [(0, 0.5), (0.08667, 0.15), (0.23833, 0.5), (0.39167, 0.255)]),
        Dot(x: 228, y: 128, size: 4, keys: [(0, 0.5), (0.035, 0.15), (0.31167, 0.5), (0.58667, 0.496)]),
        Dot(x: 258, y: 638, size: 4, keys: [(0, 0.5), (0.16167, 0.15), (0.39333, 0.451)]),
        Dot(x: 308, y: 598, size: 4, keys: [(0, 0.5), (0.05, 0.15), (0.23667, 0.5), (0.42333, 0.314)]),
        Dot(x: 348, y: 658, size: 4, keys: [(0, 0.5), (0.12, 0.15), (0.26167, 0.5), (0.405, 0.325)]),
    ]
}

#Preview {
    StarField()
}
