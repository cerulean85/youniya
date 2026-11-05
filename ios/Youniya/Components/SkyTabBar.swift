import SwiftUI

enum SkyTab: CaseIterable, Identifiable {
    case sky, nebula, plaza, records
    var id: Self { self }

    var title: String {
        switch self {
        case .sky: "밤하늘"
        case .nebula: "성운"
        case .plaza: "우주 광장"
        case .records: "기록"
        }
    }

    var icon: ImageResource {
        switch self {
        case .sky: .iconMoon
        case .nebula: .iconNebula
        case .plaza: .iconStar
        case .records: .iconArchive
        }
    }
}

/// Figma `Tab Bar`: four tabs around a raised violet pencil FAB.
/// Custom (not `TabView`) because the design reserves a center slot for the FAB.
struct SkyTabBar: View {
    @Binding var selection: SkyTab
    var onCompose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.sky)
            Spacer(minLength: 0)
            item(.nebula)
            Spacer(minLength: 0)
            Color.clear.frame(width: 70, height: 52) // FAB slot
            Spacer(minLength: 0)
            item(.plaza)
            Spacer(minLength: 0)
            item(.records)
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .padding(.top, 5)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            Color.bgSurface
                .overlay { CosmosBackground(seed: "tab-bar") }
                .overlay(alignment: .top) { Color.borderDefault.frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) { fab }
    }

    private func item(_ tab: SkyTab) -> some View {
        let active = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Color.clear
                    .frame(width: 4, height: 4)
                    .overlay {
                        if active {
                            Image(.tabDotActive).resizable().frame(width: 60, height: 60)
                        }
                    }
                Image(tab.icon)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(tab.title)
                    .textStyle(.captionTab)
                    .fixedSize()
            }
            .foregroundStyle(active ? Color.starBright : Color.textTertiary)
            .frame(width: 70, height: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var fab: some View {
        Button(action: onCompose) {
            // FAB: violet gradient circle with glow; icon = `Icon/write-star` (pencil + sparkle)
            Image(.fab)
                .resizable()
                .frame(width: 108, height: 108)
                .overlay { WriteStarIcon() }
                .frame(width: 60, height: 60)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        // FAB center sits 5pt below the bar's top edge.
        .offset(y: 5 - 30)
        .accessibilityLabel("별 만들기")
    }
}

/// Figma `Icon/write-star` (26pt): pencil plus a sparkle that pulses
/// (6s: scale 0.8 → 1.25 → 1.15, then holds).
private struct WriteStarIcon: View {
    var body: some View {
        ZStack {
            Image(.fabPencil)
                .resizable()
                .frame(width: 15.775, height: 15.775)
                .offset(x: -1.67, y: 1.68)
            Image(.fabSparkle)
                .resizable()
                .frame(width: 4.98, height: 4.98)
                .modifier(PulseScale(track: Twinkle(duration: 6, keys: [(0, 0.8), (0.25, 1.25), (0.5, 1.1457)])))
                .offset(x: 7.56, y: -8.13)
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

/// Drives scale from a keyframe track (values are scale factors, not opacity).
private struct PulseScale: ViewModifier {
    var track: Twinkle
    @Environment(\.motionReduced) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            TimelineView(.animation) { context in
                content.scaleEffect(track.opacity(at: context.date.timeIntervalSinceReferenceDate))
            }
        }
    }
}

#Preview {
    @Previewable @State var tab = SkyTab.sky
    VStack {
        Spacer()
        SkyTabBar(selection: $tab) {}
    }
    .background(Color.bgCanvas)
}
