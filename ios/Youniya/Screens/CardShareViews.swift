import SwiftUI

/// 12-13 / 08-9 공유 시트: a card made on the device (never uploaded), shared to
/// Instagram Stories, saved to Photos, or sent through the system share sheet.
/// The writing itself is never on the card.
enum ShareCard {
    /// Figma draws the 1080×1920 card at a third of its size.
    static let size = CGSize(width: 360, height: 640)

    @MainActor
    static func render(_ card: some View, model: AppModel) -> UIImage? {
        let renderer = ImageRenderer(content:
            card
                .frame(width: size.width, height: size.height)
                .environment(model)
                .environment(\.skyTheme, model.previewSky ?? model.settings.sky)
                .environment(\.motionReduced, true)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Instagram Stories sharing (a background image). Meta requires a Facebook
/// App ID as `source_application`; without one, or without Instagram, the
/// button is hidden.
enum InstagramStories {
    static var appID: String {
        (Bundle.main.object(forInfoDictionaryKey: "InstagramAppID") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    private static var url: URL? {
        URL(string: "instagram-stories://share?source_application=\(appID)")
    }

    @MainActor static var isAvailable: Bool {
        guard !appID.isEmpty, let url else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    @MainActor static func share(_ image: UIImage) {
        guard let url, let data = image.pngData() else { return }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": data,
              "com.instagram.sharedSticker.appID": appID]],
            options: [.expirationDate: Date().addingTimeInterval(300)])
        UIApplication.shared.open(url)
    }
}

// MARK: - 12-14 별 카드 이미지

struct StarShareCard: View {
    @Environment(AppModel.self) private var model
    var star: StarItem
    var withTitle: Bool

    var body: some View {
        ZStack(alignment: .top) {
            StarField()
            VStack(spacing: 0) {
                Text(topLine)
                    .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    .padding(.top, 64)
                if withTitle {
                    Text(star.title)
                        .font(.custom("NotoSerifKR-SemiBold", size: 20))
                        .tracking(-0.06)
                        .foregroundStyle(Color.textPrimary.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, Space.xl)
                        .padding(.top, 18)
                }
                Spacer(minLength: 0)
            }
            // The star sits at the card's center line (Figma 240…360).
            starMark
                .frame(width: 120, height: 120)
                .position(x: 180, y: 300)
            VStack(spacing: Space.md) {
                if let value = star.analysis?.starlight, star.isFloated {
                    StarlightBadge(value: value)
                } else {
                    Text("별빛 없는 별").textStyle(.labelS).foregroundStyle(Color.textSecondary)
                }
                HStack(spacing: Space.sm) {
                    ForEach(moods) { MoodTag(mood: $0) }
                }
            }
            .padding(.top, 430)
            CardFooter()
        }
        .frame(width: ShareCard.size.width, height: ShareCard.size.height)
        .clipped()
    }

    @ViewBuilder private var starMark: some View {
        if star.isFloated {
            ShapeStar(spec: star.analysis?.shape ?? StarShapeSpec(points: 5, sharpness: .normal),
                      color: star.mood.color, size: 120, halo: true)
        } else {
            // A star without starlight: a small light in its mood color.
            Circle()
                .fill(RadialGradient(colors: [star.mood.color, star.mood.color.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 28))
                .frame(width: 56, height: 56)
                .overlay(Circle().fill(.white.opacity(0.9)).frame(width: 8, height: 8))
        }
    }

    /// "11월 3일 · 11월 페가수스자리"
    private var topLine: String {
        let date = star.createdAt ?? .now
        let day = star.createdAt.map(Self.day) ?? star.shortDateText
        return "\(day) · \(model.constellation(MonthConstellation.monthKey(date)).title.replacingOccurrences(of: " · ", with: " "))"
    }

    private var moods: [Mood] {
        var list = star.analysis?.tones ?? []
        if list.isEmpty { list = [star.mood] + (star.extraMoods ?? []) }
        var seen = Set<Mood>()
        return list.filter { seen.insert($0).inserted }.prefix(3).map { $0 }
    }

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: d)
    }
}

// MARK: - 08-9 별자리 카드 이미지

struct ConstellationShareCard: View {
    @Environment(AppModel.self) private var model
    var constellation: MonthConstellation

    var body: some View {
        let c = constellation
        ZStack(alignment: .top) {
            StarField()
            Text(Self.monthTitle(c.month))
                .textStyle(.caption).foregroundStyle(Color.textTertiary)
                .padding(.top, 64)
            // The figure large across the top, each star in its own shape.
            ConstellationFigureView(constellation: c, shapes: shapes(c))
                .padding(.horizontal, 6)
                .padding(.vertical, 18)
                .frame(width: 360, height: 320)
                .position(x: 180, y: 88 + 320 / 2)
            VStack(spacing: 0) {
                Text(c.name)
                    .font(.custom("NotoSerifKR-SemiBold", size: 30))
                    .foregroundStyle(Color.textPrimary)
                    .frame(height: 38)
                Text(c.isComplete ? "\(c.total)자리를 모두 채웠어요 · 별 \(c.stars.count)개"
                                  : "\(c.total)자리 중 \(c.filled)자리를 채웠어요 · 별 \(c.stars.count)개")
                    .font(.custom("Pretendard-Regular", size: 14))
                    .foregroundStyle(Color.textTertiary.opacity(0.85))
                    .padding(.top, 8)
                Capsule().fill(Color.white.opacity(0.15))
                    .frame(width: 200, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.starBright)
                            .frame(width: 200 * CGFloat(c.filled) / CGFloat(max(1, c.total)), height: 4)
                    }
                    .padding(.top, 14)
            }
            .padding(.top, 418)
            CardFooter()
        }
        .frame(width: ShareCard.size.width, height: ShareCard.size.height)
        .clipped()
    }

    private func shapes(_ c: MonthConstellation) -> [UUID: StarShapeSpec] {
        var map: [UUID: StarShapeSpec] = [:]
        for s in c.stars {
            // The constellation's own shape (live), else the star's on this device.
            if let shape = s.shape ?? model.stars.first(where: { $0.id == s.id })?.analysis?.shape { map[s.id] = shape }
        }
        return map
    }

    /// "2026년 11월 · 별자리 완성"
    static func monthTitle(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]) else { return "이달의 별자리" }
        // Shared only once a month is complete (2026-11-10).
        return "\(parts[0])년 \(m)월 · 별자리 완성"
    }
}

/// "YOUNIYA / 쓴 마음이 별이 되는 밤하늘 일기" at the card's foot.
private struct CardFooter: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("YOUNIYA")
                .font(.custom("NotoSerifKR-SemiBold", size: 18))
                .tracking(2.16)
                .foregroundStyle(Color.textPrimary)
                .frame(height: 30)
            Text("쓴 마음이 별이 되는 밤하늘 일기")
                .textStyle(.caption).foregroundStyle(Color.textTertiary)
                .padding(.bottom, 32)
        }
    }
}

// MARK: - 12-13 / 08-9 공유 시트

struct CardShareSheet<Card: View>: View {
    @Environment(AppModel.self) private var model
    var title: String
    /// 12-13 「별 제목 넣기」; nil hides the row (the constellation card).
    var withTitle: Binding<Bool>?
    @ViewBuilder var card: () -> Card
    /// Closes the sheet with a toast for the page underneath.
    var onDone: (ToastCardMessage?) -> Void

    @State private var image: UIImage?
    @State private var instagram = false

    var body: some View {
        VStack(spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title).textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text("글은 담기지 않아요. 별 모양·별빛·날짜·마음만 담겨요.")
                    .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Preview: the card at half its drawn size.
            card()
                .frame(width: ShareCard.size.width, height: ShareCard.size.height)
                .scaleEffect(0.5)
                .frame(width: 180, height: 320)
                .clipShape(.rect(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                .shadow(color: Color.brandPrimary.opacity(0.35), radius: 16)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("카드 미리 보기")

            if let withTitle {
                HStack(spacing: Space.md) {
                    Image(.iconPencil).renderingMode(.template).resizable()
                        .frame(width: 22, height: 22).foregroundStyle(Color.textSecondary)
                    Toggle("별 제목 넣기", isOn: withTitle)
                        .textStyle(.bodyM).foregroundStyle(Color.textPrimary)
                        .tint(Color.brandPrimary)
                }
                .padding(.vertical, Space.md)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.borderDefault).frame(height: 1) }
            }

            VStack(spacing: Space.md) {
                if instagram {
                    Button("인스타그램 스토리에 공유") {
                        if let image { InstagramStories.share(image) }
                        onDone(nil)
                    }
                    .buttonStyle(.primary)
                }
                Button("이미지로 저장") {
                    if let image { UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil) }
                    onDone(ToastCardMessage(title: "이미지로 저장했어요"))
                }
                .buttonStyle(.secondary)
                if let image {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(title, image: Image(uiImage: image))) {
                        Text("다른 앱으로 공유")
                    }
                    .buttonStyle(.ghost)
                }
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
        .onAppear {
            instagram = InstagramStories.isAvailable
            image = ShareCard.render(card(), model: model)
        }
        .onChange(of: withTitle?.wrappedValue) {
            image = ShareCard.render(card(), model: model)
        }
    }
}

extension View {
    /// The share sheet as a bottom sheet sized to its content.
    func cardShareSheet<Card: View>(isPresented: Binding<Bool>, title: String, withTitle: Binding<Bool>? = nil,
                                    toast: Binding<ToastCardMessage?>, @ViewBuilder card: @escaping () -> Card) -> some View {
        modifier(CardShareSheetModifier(isPresented: isPresented, title: title, withTitle: withTitle, toast: toast, card: card))
    }
}

private struct CardShareSheetModifier<Card: View>: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var withTitle: Binding<Bool>?
    @Binding var toast: ToastCardMessage?
    var card: () -> Card
    @State private var height: CGFloat = 720
    @State private var pending: ToastCardMessage?

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            if let pending { toast = pending; self.pending = nil }
        }) {
            CardShareSheet(title: title, withTitle: withTitle, card: card) { message in
                pending = message
                isPresented = false
            }
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "card-share") }
        }
    }
}

// MARK: - 08-10 {별자리}를 완성했어요

/// 08-10 (568:15248): shown once a month after the card of the star that
/// filled the last place. 「별자리 카드로 나누기」 opens the 08-9 sheet.
struct ConstellationCompleteView: View {
    @Environment(AppModel.self) private var model
    var month: String
    /// Closes the flow (or, for a star without starlight, opens its page).
    var onClose: () -> Void = {}
    var onShowNebula: () -> Void

    @State private var share = false
    @State private var toast: ToastCardMessage?

    var body: some View {
        let c = model.constellation(month)
        VStack(spacing: Space.lg) {
            FlowTopBar(title: "", onClose: onClose)
            Text("\(c.name)를 완성했어요")
                .textStyle(.h2).foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            ConstellationShareCard(constellation: c)
                .frame(width: ShareCard.size.width, height: ShareCard.size.height)
                .scaleEffect(0.72)
                .frame(width: ShareCard.size.width * 0.72, height: ShareCard.size.height * 0.72)
                .clipShape(.rect(cornerRadius: 20))
                // 568:15315: a clear edge on the dimmed sky.
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                .shadow(color: Color.brandPrimary.opacity(0.45), radius: 24)
                .accessibilityHidden(true)
            Text("\(c.monthLabel)에 띄운 별 \(c.stars.count)개가 \(c.name)를 모두 채웠어요.")
                .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            VStack(spacing: Space.sm) {
                Button("별자리 카드로 나누기") { share = true }
                    .buttonStyle(.primary)
                Button("별자리 보기", action: onShowNebula)
                    .buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.lg)
        .background {
            StarField().overlay(Color.black.opacity(0.55))
        }
        .cardShareSheet(isPresented: $share, title: "별자리 카드로 나누기", toast: $toast) {
            ConstellationShareCard(constellation: c)
        }
        .toastCard($toast)
    }

    private static func key(_ month: String) -> String { "constellationCompleteShown.\(month)" }
    static func wasShown(_ month: String) -> Bool { UserDefaults.standard.bool(forKey: key(month)) }
    static func markShown(_ month: String) { UserDefaults.standard.set(true, forKey: key(month)) }
}
