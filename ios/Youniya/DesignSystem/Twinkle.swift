import SwiftUI

/// A looping keyframe track, transcribed from Figma motion data.
/// Every segment uses ease-in-out, as in the Figma timelines.
struct Twinkle {
    var duration: Double
    /// (progress 0...1, opacity)
    var keys: [(Double, Double)]

    func opacity(at time: Double) -> Double {
        let p = (time.truncatingRemainder(dividingBy: duration)) / duration
        guard let last = keys.last else { return 1 }
        if p >= last.0 { return last.1 }
        for i in 0..<(keys.count - 1) where p < keys[i + 1].0 {
            let (t0, v0) = keys[i], (t1, v1) = keys[i + 1]
            let x = (p - t0) / (t1 - t0)
            let eased = x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
            return v0 + (v1 - v0) * eased
        }
        return last.1
    }
}

/// Drives a view's opacity (and optionally scale) from a `Twinkle` track.
/// With Reduce Motion on, the view stays at its first keyframe.
struct TwinkleModifier: ViewModifier {
    var twinkle: Twinkle
    /// Maps opacity to scale, e.g. Figma stars go 1→0.7 while opacity goes 1→0.3.
    var scale: ((Double) -> Double)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(twinkle.keys.first?.1 ?? 1)
        } else {
            TimelineView(.animation) { context in
                let o = twinkle.opacity(at: context.date.timeIntervalSinceReferenceDate)
                content
                    .opacity(o)
                    .scaleEffect(scale?(o) ?? 1)
            }
        }
    }
}

extension View {
    func twinkle(_ t: Twinkle, scale: ((Double) -> Double)? = nil) -> some View {
        modifier(TwinkleModifier(twinkle: t, scale: scale))
    }
}
