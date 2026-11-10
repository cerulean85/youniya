import SwiftUI

/// 75 / 75-3 / 75-4 다른 이의 별: one shared star — its 대표 문장 and whole text,
/// the keeper's name (→ 76-1), resonance and 별빛 한 줄 (→ 74).
struct PlazaStarView: View {
    @Environment(AppModel.self) private var model
    var star: PlazaNebula
    var onBack: () -> Void
    /// 75-2: back to the previous page with the "차단했어요" toast.
    var onBlocked: () -> Void = {}
    /// 75-4: the keeper's name → 76-1.
    var onKeeper: (String) -> Void = { _ in }
    /// 74 별빛 한 줄 건네기.
    var onLine: () -> Void = {}

    @State private var showMenu = DebugScreen.is("75-1")
    /// Live 75-3: the whole text, from the plaza star's detail.
    @State private var liveText: (title: String, body: String)?

    /// 75-4: the star's own title as its keeper wrote it, not the AI star name.
    private var title: String {
        if let t = liveText?.title, !t.isEmpty { return t }
        return star.fullTitle ?? star.starTitle ?? star.name
    }
    private var key: String { star.id }
    private var resonated: Bool { model.resonated.contains(key) }
    private var quote: String { star.line }
    private var depth: Int { star.cardDepth }
    /// 75-3: the whole star (title and body, contacts masked by the server).
    private var fullText: (title: String, body: String)? {
        let p = star
        guard p.fullText else { return nil }
        if let liveText { return (liveText.title.isEmpty ? p.name : liveText.title, liveText.body) }
        return p.fullBody.map { (p.fullTitle ?? p.name, $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "다른 이의 별", onBack: onBack, onMore: { showMenu.toggle() })

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    header

                    VStack(alignment: .leading, spacing: Space.xs) {
                        // The quote is empty while its owner picks a new one (12-3).
                        if !quote.isEmpty {
                            Text("“\(quote)”")
                                .textStyle(.observation).foregroundStyle(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(fullText != nil ? "대표 문장이에요. 아래에서 글 전체를 읽을 수 있어요."
                                             : "본인이 고른 한 문장만 나눈 별이에요")
                            .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.lg)
                    .flatCard(seed: "star-quote")

                    if let fullText {
                        // The title is in the header above, so only the body here.
                        VStack(alignment: .leading, spacing: Space.sm) {
                            // Figma: Serif 15, line height 175%.
                            Text(fullText.body)
                                .font(.custom("NotoSerifKR-Regular", size: 15, relativeTo: .callout))
                                .lineSpacing(15 * 0.75 - 4)
                                .foregroundStyle(Color.textSecondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    actions
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .task {
            if model.useLiveAPI, star.fullText, let id = star.serverID {
                liveText = await model.plazaStarText(id)
            }
        }
        .modifier(PlazaSafetyModifier(showMenu: $showMenu, target: .star, nebulaName: title,
                                       serverID: star.serverID, onBlocked: onBlocked))
    }

    /// 75-4 `Star Header`: a 56×56 thumbnail of the star beside its
    /// title, the keeper's name and the depth, so the text comes right after.
    private var header: some View {
        HStack(spacing: 14) {
            // The same thumbnail as the 09-5 row that opened it, at 56pt.
            PlazaStarThumb(item: star, side: 56)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title)
                    .textStyle(.h2).foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: Space.sm) {
                    if let name = star.nickname {
                        // 75-4: the keeper's name opens their page.
                        Button { onKeeper(name) } label: { Tag(text: "\(name) ›", tone: .neutral) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(name)의 밤하늘 보기")
                    } else {
                        Tag(text: "익명의 별지기", tone: .neutral)
                    }
                    if !star.hasStarlight {
                        Tag(text: "별빛 없는 별", tone: .neutral)
                    } else {
                        Tag(text: "깊이 \(depth)단계", tone: .gold)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var actions: some View {
        let resonate = Button(resonated ? "공명했어요" : "공명 남기기") {
            guard model.plazaAllowed() else { return }
            withAnimation(.snappy) { model.toggleResonance(key) }
        }
        // 09-6: while restricted these look dimmed and open 09-7.
        let dim = model.isPlazaRestricted ? 0.45 : 1
        // 75-4: 공명 남기기, 별빛 한 줄 건네기, and the keeper's page.
        VStack(spacing: Space.md) {
            resonate.buttonStyle(.primary)
                .opacity(dim)
                .accessibilityAddTraits(resonated ? .isSelected : [])
            Button("별빛 한 줄 건네기") { if model.plazaAllowed() { onLine() } }
                .buttonStyle(.secondary)
                .opacity(dim)
            if let name = star.nickname {
                Button("\(name)의 밤하늘") { onKeeper(name) }.buttonStyle(.secondary)
            }
        }
    }
}

