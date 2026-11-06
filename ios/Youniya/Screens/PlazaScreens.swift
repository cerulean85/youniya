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

    private static let patterns: [(KeyPath<PrivacyScan, Int>, String)] = [
        // Phone numbers and email addresses
        (\.contacts, #"\b0\d{1,2}[-. ]?\d{3,4}[-. ]?\d{4}\b|[\w.+-]+@[\w-]+\.[\w.]+"#),
        // A Korean name followed by a title or honorific (민지 씨, 지훈이 형)
        (\.names, #"[가-힣]{2,3}(?=\s?(?:씨|님|선배|후배|언니|오빠|누나|형|선생님)(?:이랑|에게|한테|[이가은는을를랑과와도의께])?(?![가-힣]))"#),
        // Place names by their suffix (강남역, 망원시장, 연남동 카페)
        (\.places, #"[가-힣]{2,8}(?:역|구청|공원|학교|대학교|병원|카페|시장|해변|터미널)(?![가-힣])"#),
    ]

    init(_ text: String) {
        var out = text
        var counts: [KeyPath<PrivacyScan, Int>: Int] = [:]
        for (kind, pattern) in Self.patterns {
            guard let regex = try? Regex(pattern) else { continue }
            counts[kind] = out.matches(of: regex).count
            out = out.replacing(regex, with: "●●●")
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
                Text("점수도 순위도 없는 곳이에요.\n마음에 닿으면 '공명'만 남길 수 있어요.")
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

// MARK: - 22 Other Nebula

/// 22 Other Nebula (다른 이의 성운): an anonymous nebula opened from the plaza.
/// Shows only titles and resonance counts, never the other person's text.
struct OtherNebulaView: View {
    @Environment(AppModel.self) private var model
    var nebula: PlazaNebula
    var onBack: () -> Void
    /// A star card → 23 Starlight Line with that star's one line.
    var onOpenLine: (String) -> Void

    var body: some View {
        let resonated = model.resonated.contains(nebula.id)
        VStack(spacing: 0) {
            TopAppBar(title: "이름 없는 성운", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text(nebula.name)
                            .textStyle(.h1)
                            .foregroundStyle(Color.textPrimary)
                        Text("익명의 별 \(nebula.starCount)개가 모인 성운이에요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    PlazaHero()
                        .frame(maxWidth: .infinity)

                    ForEach(nebula.entries, id: \.title) { entry in
                        Button { onOpenLine(entry.line) } label: {
                            InfoCard(seed: nebula.name + entry.title, title: entry.title, detail: "공명 \(entry.resonance)")
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)

            Button(resonated ? "공명을 남겼어요" : "공명 남기기") {
                withAnimation(.snappy) { model.toggleResonance(nebula.id) }
            }
            .buttonStyle(.secondary)
            .accessibilityAddTraits(resonated ? .isSelected : [])
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
    }
}

extension PlazaNebula {
    /// TODO: From the plaza API. Figma `22 다른 이의 성운` sample data.
    var starCount: Int { 12 - order * 2 }
    var entries: [(title: String, resonance: Int, line: String)] {
        [("저녁이 길게 느껴진 날", 8 - order, "그런 마음이 어둠 속에서도 조용히 빛나고 있어요."),
         ("놓아주고 싶은 말", 5 + order % 2, line)]
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

#Preview("22") {
    OtherNebulaView(nebula: PlazaNebula.samples[0], onBack: {}, onOpenLine: { _ in }).environment(AppModel())
}
