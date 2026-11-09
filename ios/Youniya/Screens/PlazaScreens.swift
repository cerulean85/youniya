import SwiftUI

// MARK: - 20 Privacy Check

/// 20 Privacy Check (공유 전 확인): reached from 19 "내용 먼저 확인".
/// Shows how many names, contacts and places were found in the entry.
struct PrivacyCheckView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onBack: () -> Void

    var body: some View {
        let scan = PrivacyScan(model.stars.first { $0.id == starID }?.body ?? "")
        VStack(spacing: 0) {
            TopAppBar(title: "공유 전 확인", onBack: onBack)

            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Text("이름이나 장소가 있나요?")
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                    Text("글 속 개인정보를 가려 두었어요. 확인하고 나눌 수 있어요.")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                NoticeBanner(message: "이름, 연락처, 장소는 자동으로 가려져요.")

                if scan.total > 0 {
                    InfoCard(seed: "privacy", title: "가려진 항목 \(scan.total)개", detail: scan.summary)
                } else {
                    InfoCard(seed: "privacy", title: "가려진 항목이 없어요", detail: "그대로 나눠도 괜찮아 보여요.")
                }

                Spacer(minLength: Space.xl)

                VStack(spacing: Space.md) {
                    Button("확인했어요") {
                        // TODO: Upload the masked text (`scan.masked`) to the plaza API.
                        model.setShared(true, for: starID)
                        onBack()
                    }
                    .buttonStyle(.primary)
                    Button("취소", action: onBack)
                        .buttonStyle(.ghost)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }
}

/// On-device first pass at finding personal details. The server should run
/// the real check before anything is published.
struct PrivacyScan {
    private(set) var names = 0
    private(set) var contacts = 0
    private(set) var places = 0
    private(set) var masked: String

    var total: Int { names + contacts + places }

    /// "이름 1 · 장소 1", skipping empty kinds.
    var summary: String {
        [("이름", names), ("연락처", contacts), ("장소", places)]
            .filter { $0.1 > 0 }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: " · ")
    }

    /// The same patterns as the API (`server/youniya_api/privacy.py`), which masks
    /// again before anything is published. NSRegularExpression because Swift
    /// `Regex` has no lookbehind.
    private static let patterns: [(KeyPath<PrivacyScan, Int>, String)] = [
        // Phone numbers and email addresses. Digit lookarounds, not \b: Hangul counts
        // as a word character, so "010-1234-5678로" has no \b after the number.
        (\.contacts, #"(?<!\d)0\d{1,2}[-. ]?\d{3,4}[-. ]?\d{4}(?!\d)|[\w.+-]+@[\w-]+\.[A-Za-z.]+"#),
        // A Korean name followed by a title or honorific (민지 씨, 지훈이 형)
        (\.names, #"[가-힣]{2,3}(?=\s?(?:씨|님|선배|후배|언니|오빠|누나|형|선생님)(?:이랑|에게|한테|[이가은는을를랑과와도의께])?(?![가-힣]))"#),
        // Place names by their suffix (강남역, 망원시장, 연남동 카페), also with a particle (강남역에서)
        (\.places, #"[가-힣]{2,8}(?:역|구청|공원|학교|대학교|병원|카페|시장|해변|터미널)(?=(?:에서|에|으로|로|은|는|이|가|을|를|과|와|의|도)?(?![가-힣]))"#),
    ]

    /// `contactsOnly`: a star shared with its whole text (19) hides only phone
    /// numbers and emails; names and places stay as written.
    init(_ text: String, contactsOnly: Bool = false) {
        var out = text
        var counts: [KeyPath<PrivacyScan, Int>: Int] = [:]
        for (kind, pattern) in Self.patterns where !contactsOnly || kind == \.contacts {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                assertionFailure("Bad privacy pattern: \(pattern)")
                continue
            }
            let range = NSRange(out.startIndex..., in: out)
            counts[kind] = regex.numberOfMatches(in: out, range: range)
            out = regex.stringByReplacingMatches(in: out, range: range, withTemplate: "●●●")
        }
        masked = out
        names = counts[\.names] ?? 0
        contacts = counts[\.contacts] ?? 0
        places = counts[\.places] ?? 0
    }
}

/// Figma item card used on 20 and 22: title and detail on a cosmos surface.
struct InfoCard: View {
    var seed: String
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .textStyle(.labelM)
                .foregroundStyle(Color.textPrimary)
            Text(detail)
                .textStyle(.bodyS)
                .foregroundStyle(Color.textSecondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.lg)
        .itemCard(seed: seed)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 21 Plaza Welcome

/// 21 Plaza Welcome (광장 첫 안내): shown the first time the plaza tab opens.
struct PlazaWelcomeView: View {
    var onBrowse: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(spacing: Space.lg) {
            PlazaHero()

            VStack(spacing: Space.sm) {
                Text("우주 광장에 오신 걸\n환영해요")
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)
                Text("점수도 순위도 없는 곳이에요.\n마음에 닿으면 '공명'이나 '별빛 한 줄'을 남길 수 있어요.")
                    .textStyle(.bodyM)
                    .foregroundStyle(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Space.xl)

            VStack(spacing: Space.md) {
                Button("둘러보기", action: onBrowse)
                    .buttonStyle(.primary)
                Button("다음에", action: onLater)
                    .buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StarField() }
    }
}

/// Figma `Hero` on 21 and 22 (342×140): a small violet star with a gold core,
/// two faint orbits, and ten twinkling grey stars.
struct PlazaHero: View {
    private struct S { var center: CGPoint; var keys: [(Double, Double)] }
    // Centers of the 5×5 stars; keys are the Figma tracks scaled to 1→0.3.
    private let stars: [S] = [
        S(center: CGPoint(x: 40.5, y: 40.5), keys: [(0, 1), (0.01, 0.3), (0.53, 1), (1, 0.3)]),
        S(center: CGPoint(x: 90.5, y: 100.5), keys: [(0, 1), (0.235, 0.3), (0.63, 1), (1, 0.3)]),
        S(center: CGPoint(x: 140.5, y: 50.5), keys: [(0, 1), (0.115, 0.3), (0.845, 1), (1, 0.3)]),
        S(center: CGPoint(x: 200.5, y: 110.5), keys: [(0, 1), (0.445, 0.3), (1, 1)]),
        S(center: CGPoint(x: 250.5, y: 55.5), keys: [(0, 1), (0.145, 0.3), (0.635, 1), (1, 0.3)]),
        S(center: CGPoint(x: 300.5, y: 95.5), keys: [(0, 1), (0.32, 0.3), (0.69, 1), (1, 0.3)]),
        S(center: CGPoint(x: 70.5, y: 20.5), keys: [(0, 1), (0.305, 0.3), (1, 1)]),
        S(center: CGPoint(x: 230.5, y: 20.5), keys: [(0, 0.3), (0.58, 1), (1, 0.3)]),
        S(center: CGPoint(x: 320.5, y: 30.5), keys: [(0, 1), (0.265, 0.3), (0.725, 1), (1, 0.3)]),
        S(center: CGPoint(x: 20.5, y: 110.5), keys: [(0, 1), (0.05, 0.3), (0.39, 1), (0.73, 0.3), (1, 1)]),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(stars.indices, id: \.self) { i in
                Circle().fill(Color.textSecondary)
                    .frame(width: 5, height: 5)
                    .twinkle(Twinkle(duration: 2, keys: stars[i].keys), scale: StarScale.dim)
                    .opacity(0.7)
                    .position(stars[i].center)
            }
            Circle().strokeBorder(Color.brandPrimary, lineWidth: 1)
                .frame(width: 130, height: 130).opacity(0.3)
                .position(x: 171, y: 70)
            Circle().strokeBorder(Color.brandPrimary, lineWidth: 1.5)
                .frame(width: 86, height: 86).opacity(0.5)
                .position(x: 171, y: 70)
            Circle().fill(Color.brandPrimary)
                .frame(width: 26, height: 26)
                .shadow(color: Color.brandPrimary.opacity(0.4), radius: 12)
                .twinkle(Twinkle(duration: 2, keys: [(0, 1), (0.475, 0.3), (1, 1)]), scale: StarScale.dim)
                .position(x: 171, y: 70)
            Circle().fill(Color.starBright)
                .frame(width: 10, height: 10)
                .shadow(color: Color.starBright.opacity(0.5), radius: 14)
                .twinkle(Twinkle(duration: 2, keys: [(0, 1), (0.155, 0.3), (0.705, 1), (1, 0.3)]), scale: StarScale.dim)
                .position(x: 171, y: 70)
        }
        .fitCanvas(width: 342, height: 140)
        .accessibilityHidden(true)
    }
}

#Preview("20") {
    let model = AppModel()
    model.fillSampleStars()
    return PrivacyCheckView(starID: model.stars[0].id, onBack: {}).environment(model)
}

#Preview("21") {
    PlazaWelcomeView(onBrowse: {}, onLater: {})
}

