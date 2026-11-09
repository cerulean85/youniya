import SwiftUI

// MARK: - Skeleton block (47–50, 110–112)

/// Figma `Skeleton`: a flat #1A2338 block that stands in for content while it loads.
/// It pulses gently unless Reduce Motion is on.
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var radius: CGFloat = Radius.md

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.bgSurfaceRaised)
            .frame(maxWidth: width ?? .infinity)
            .frame(width: width, height: height)
    }
}

/// Lays out skeleton blocks with the screen padding and a slow pulse,
/// and reads as one "loading" element to VoiceOver.
struct SkeletonStack<Content: View>: View {
    var spacing: CGFloat = Space.lg
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(dim ? 0.55 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("불러오는 중이에요")
    }
}

// MARK: - Loading gate

/// Shows `placeholder` until the content's data has loaded, then fades to `content`.
/// The backend is mocked, so loading only happens when the dev "로딩 흉내" switch
/// (or the `-simulateLoading YES` launch argument) is on.
/// TODO: Drive this from the real API request state.
struct LoadingGate<Content: View, Placeholder: View>: View {
    @Environment(AppModel.self) private var model
    @ViewBuilder var content: Content
    @ViewBuilder var placeholder: Placeholder
    @State private var loaded = false

    var body: some View {
        ZStack(alignment: .top) {
            if model.simulateLoading && !loaded {
                placeholder.transition(.opacity)
            } else {
                content.transition(.opacity)
            }
        }
        .simulatedLoad($loaded)
    }
}

/// For screens that also change controls outside the gated part while loading
/// (111 and 112 disable their bottom buttons). Sets `loaded` once the simulated load ends.
private struct SimulatedLoad: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var loaded: Bool

    func body(content: Content) -> some View {
        content.task {
            guard model.simulateLoading, !loaded else { return }
            try? await Task.sleep(for: .seconds(AppModel.simulatedLoadSeconds))
            withAnimation(.easeOut(duration: 0.25)) { loaded = true }
        }
    }
}

extension View {
    func simulatedLoad(_ loaded: Binding<Bool>) -> some View {
        modifier(SimulatedLoad(loaded: loaded))
    }
}

// MARK: - Screens

/// 47 스켈레톤 · 홈
struct HomeSkeleton: View {
    var body: some View {
        SkeletonStack {
            SkeletonBlock(width: 160, height: 28)
            SkeletonBlock(height: 20)
            VStack(alignment: .leading, spacing: Space.md) {
                SkeletonBlock(width: 120, height: 16)
                SkeletonBlock(height: 56)
                SkeletonBlock(height: 12)
                SkeletonBlock(height: 12)
            }
            .padding(Space.lg)
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.xl))
            SkeletonBlock(height: 52, radius: Radius.lg)
            SkeletonBlock(height: 52, radius: Radius.lg)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.lg)
    }
}

/// 48 스켈레톤 · 별 상세
struct StarDetailSkeleton: View {
    var body: some View {
        SkeletonStack {
            SkeletonBlock(width: 120, height: 14)
            SkeletonBlock(width: 240, height: 28)
            SkeletonBlock(height: 14)
            SkeletonBlock(height: 14)
            SkeletonBlock(height: 14)
            SkeletonBlock(width: 200, height: 14)
            SkeletonBlock(height: 200, radius: Radius.xl)
            SkeletonBlock(height: 52, radius: Radius.lg)
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.sm)
    }
}

/// 49 스켈레톤 · 별빛 기록 and 50 스켈레톤 · 우주 광장: a title and a column of cards.
struct ListSkeleton: View {
    var titleWidth: CGFloat
    var rowHeight: CGFloat
    var rows: Int

    var body: some View {
        SkeletonStack {
            SkeletonBlock(width: titleWidth, height: 28)
            ForEach(0..<rows, id: \.self) { _ in
                SkeletonBlock(height: rowHeight, radius: Radius.lg)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.lg)
    }
}

#Preview("47") {
    HomeSkeleton().frame(maxHeight: .infinity, alignment: .top).background(Color.bgCanvas)
}
