import SwiftUI

/// Width of the invisible strip at a screen edge that starts an edge swipe.
private let edgeWidth: CGFloat = 20

// MARK: - Back swipe (from the left edge)

/// Swipe right from the left edge to go back. The page follows the finger,
/// then slides off (or springs back if the swipe was short).
struct EdgeSwipeBack: ViewModifier {
    var enabled: Bool
    var onBack: () -> Void
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                content
                    .offset(x: offset)
                    .shadow(color: .black.opacity(offset > 0 ? 0.4 : 0), radius: 16)

                if enabled {
                    Color.clear
                        .frame(width: edgeWidth)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                        .gesture(drag(width: geo.size.width))
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
            }
        }
        // VoiceOver: two-finger scrub goes back.
        .accessibilityAction(.escape) { if enabled { onBack() } }
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { offset = max(0, $0.translation.width) }
            .onEnded { value in
                let commit = value.translation.width > width * 0.25
                    || value.predictedEndTranslation.width > width * 0.5
                if commit {
                    withAnimation(.easeOut(duration: 0.2)) { offset = width } completion: { onBack() }
                } else {
                    withAnimation(.spring(duration: 0.3)) { offset = 0 }
                }
            }
    }
}

extension View {
    func edgeSwipeBack(enabled: Bool = true, onBack: @escaping () -> Void) -> some View {
        modifier(EdgeSwipeBack(enabled: enabled, onBack: onBack))
    }
}

// MARK: - Drawer (from the right edge)

/// Swipe left from the right edge to pull a drawer in. Swipe right on the
/// drawer, or tap the scrim, to close it.
struct EdgeSwipeDrawer<Drawer: View>: ViewModifier {
    @Binding var isOpen: Bool
    var enabled: Bool
    @ViewBuilder var drawer: () -> Drawer

    /// How much of the drawer is showing while a finger is on it (0...width).
    @State private var dragReveal: CGFloat?

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let width = min(320, geo.size.width * 0.84)
            let reveal = dragReveal ?? (isOpen ? width : 0)
            let progress = reveal / width

            ZStack(alignment: .trailing) {
                content

                // Scrim (Figma `Scrim`: bg/canvas)
                Color.bgCanvas
                    .opacity(0.65 * progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(progress > 0)
                    .onTapGesture { setOpen(false) }
                    .gesture(closeDrag(width: width))
                    .accessibilityHidden(true)

                drawer()
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .offset(x: width - reveal)
                    .gesture(closeDrag(width: width))
                    .opacity(progress > 0 ? 1 : 0)
                    .accessibilityHidden(!isOpen)

                if enabled && !isOpen {
                    Color.clear
                        .frame(width: edgeWidth)
                        .frame(maxHeight: .infinity)
                        .contentShape(.rect)
                        .gesture(openDrag(width: width))
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func openDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { dragReveal = min(width, max(0, -$0.translation.width)) }
            .onEnded { value in
                let open = -value.translation.width > width * 0.35
                    || -value.predictedEndTranslation.width > width * 0.6
                setOpen(open)
            }
    }

    private func closeDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { dragReveal = min(width, max(0, width - $0.translation.width)) }
            .onEnded { value in
                let close = value.translation.width > width * 0.35
                    || value.predictedEndTranslation.width > width * 0.6
                setOpen(!close)
            }
    }

    private func setOpen(_ open: Bool) {
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            isOpen = open
            dragReveal = nil
        }
    }
}

extension View {
    func edgeSwipeDrawer<Drawer: View>(
        isOpen: Binding<Bool>,
        enabled: Bool = true,
        @ViewBuilder drawer: @escaping () -> Drawer
    ) -> some View {
        modifier(EdgeSwipeDrawer(isOpen: isOpen, enabled: enabled, drawer: drawer))
    }
}
