import SwiftUI

extension View {
    /// Lays the view out on its fixed Figma canvas (`width`×`height`) and scales it
    /// down evenly when the space is narrower (iPhone SE: 327pt instead of 342pt).
    /// It never scales up, and it never makes the parent wider than the screen.
    func fitCanvas(width: CGFloat, height: CGFloat, alignment: HorizontalAlignment = .leading) -> some View {
        GeometryReader { geo in
            let scale = min(1, geo.size.width / width)
            self
                .frame(width: width, height: height)
                .scaleEffect(scale, anchor: .topLeading)
                .offset(x: alignment == .center ? (geo.size.width - width * scale) / 2 : 0)
        }
        .aspectRatio(width / height, contentMode: .fit)
        .frame(maxWidth: width)
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}
