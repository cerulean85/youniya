import SwiftUI

// MARK: - 88 Telescope observation

/// 88 마음 망원경 · 관측 연출: a beam passes over the diary, lighting the
/// sentences where feelings stay, one lens at a time.
/// Shown while the report is prepared (after 25). Leaving is fine.
struct TelescopeObserveView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionReduced) private var reduceMotion
    var star: StarItem
    var onDone: () -> Void
    var onClose: () -> Void

    private static let lenses = ["별의 깊이", "빛의 선명함", "마음의 무게"]
    /// One pass of the beam per lens.
    private static let pass: Double = 1.6

    @State private var start = Date.now

    /// The diary split into sentences.
    private var sentences: [String] {
        var out: [String] = []
        var cur = ""
        for ch in star.body {
            if ch == "\n" {
                if !cur.trimmingCharacters(in: .whitespaces).isEmpty { out.append(cur.trimmingCharacters(in: .whitespaces)) }
                cur = ""
                continue
            }
            cur.append(ch)
            if ".!?。".contains(ch) {
                out.append(cur.trimmingCharacters(in: .whitespaces))
                cur = ""
            }
        }
        if !cur.trimmingCharacters(in: .whitespaces).isEmpty { out.append(cur.trimmingCharacters(in: .whitespaces)) }
        return Array(out.prefix(8))
    }

    /// Sentences with a feeling signal. TODO: From the analysis API.
    private var lit: Set<Int> {
        let words = ["마음", "기다", "느림", "쉬고", "싶", "슬", "외로", "화", "불안", "괜찮", "몰라", "좋", "힘들"]
        var out = Set(sentences.indices.filter { i in words.contains { sentences[i].contains($0) } && i > 0 })
        if out.isEmpty, sentences.count > 1 { out = [sentences.count - 1] }
        return Set(out.prefix(3))
    }

    var body: some View {
        let sentences = self.sentences, lit = self.lit
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = reduceMotion ? Self.pass * 3 : ctx.date.timeIntervalSince(start)
            let lens = min(2, Int(t / Self.pass))
            let progress = (t.truncatingRemainder(dividingBy: Self.pass)) / Self.pass
            // Lit sentences turn on as the first beam passes them, then stay.
            let shown: Set<Int> = t >= Self.pass ? lit
                : Set(lit.filter { Double($0 + 1) / Double(max(1, sentences.count)) <= progress })

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 40, height: 40)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("닫기")
                    Text("마음 망원경")
                        .textStyle(.labelM)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, Space.md)
                .frame(height: 52)

                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("문장 사이를 비추는 중").textStyle(.h2).foregroundStyle(Color.textPrimary)
                        Text("망원경 빛이 글을 천천히 지나가며, 감정의 신호가 머문 문장에 불을 켜요.")
                            .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    HStack(spacing: Space.sm) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.starBright).frame(width: 7, height: 7)
                                .shadow(color: Color.starBright.opacity(0.95), radius: 3)
                            Text(shown.isEmpty ? "감정 신호를 찾는 중" : "감정 신호 \(shown.count)개를 찾았어요")
                                .textStyle(.labelS).foregroundStyle(Color.brandPrimaryText)
                                .contentTransition(.numericText())
                        }
                        .padding(.horizontal, Space.md).padding(.vertical, 5)
                        .background(Color.tintPrimary, in: .capsule)
                        Tag(text: "렌즈 \(lens + 1) / 3", tone: .neutral)
                    }
                    .accessibilityElement(children: .combine)

                    scanCard(sentences: sentences, shown: shown, beam: reduceMotion ? nil : progress)

                    HStack(spacing: Space.sm) {
                        ForEach(Self.lenses.indices, id: \.self) { i in
                            lensTag(Self.lenses[i], done: i < lens, now: i == lens)
                        }
                    }

                    Text("불이 켜진 문장은 리포트의 근거 문장으로 함께 보여 드려요. 평가가 아니라 함께 바라본 자리예요.")
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    Button("백그라운드로 두기") {
                        _ = model.prepareReport(for: star.id)
                        onClose()
                    }
                    .buttonStyle(.ghost)
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.xl)
            }
        }
        .background { StarField() }
        .task {
            start = .now
            if model.useLiveAPI { _ = model.prepareReport(for: star.id) }
            try? await Task.sleep(for: .seconds(reduceMotion ? 2 : Self.pass * 3))
            guard !Task.isCancelled else { return }
            _ = model.prepareReport(for: star.id)
            onDone()
        }
    }

    /// Figma `Diary Scan`: sentences, the lit ones boxed in violet, a cyan beam.
    private func scanCard(sentences: [String], shown: Set<Int>, beam: Double?) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(sentences.indices, id: \.self) { i in
                let on = shown.contains(i)
                Text(sentences[i])
                    .textStyle(.bodyM)
                    .foregroundStyle(on ? Color.textPrimary : Color.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 6).fill(Color.tintPrimary)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.brandPrimary, lineWidth: 1))
                                .shadow(color: Color.hex(0x8C5CF5).opacity(0.35), radius: 6)
                        }
                    }
                    .animation(.easeOut(duration: 0.4), value: on)
                    .accessibilityLabel(on ? "불이 켜진 문장: \(sentences[i])" : sentences[i])
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 18)
        .itemCard(seed: "diary-scan", minHeight: 0)
        .overlay(alignment: .top) {
            if let beam {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        Rectangle().fill(Color.starClear.opacity(0.12)).frame(height: 44).blur(radius: 5)
                        Rectangle().fill(Color.starClear).frame(height: 2)
                            .shadow(color: Color.starClear.opacity(0.8), radius: 4)
                    }
                    .frame(height: 44)
                    .offset(y: geo.size.height * beam - 36)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    private func lensTag(_ title: String, done: Bool, now: Bool) -> some View {
        Text(done ? "\(title) ✓" : title)
            .textStyle(.labelS)
            .foregroundStyle(now ? Color.brandPrimaryText : Color.textSecondary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, done ? Space.sm : Space.xs)
            .background(now ? Color.tintPrimary : Color.bgSurfaceRaised, in: .capsule)
            .overlay { if done { Capsule().strokeBorder(Color.borderDefault, lineWidth: 1) } }
            .accessibilityValue(done ? "끝났어요" : now ? "보는 중" : "")
    }
}

// MARK: - 61–64 Star birth

/// 61–64 별 탄생: a point of light gathers (0s), spreads (0.6s), takes shape
/// (1.2s) and settles (1.7s). Then "별 보기".
struct StarBirthView: View {
    @Environment(\.motionReduced) private var reduceMotion
    /// 별빛 없이 띄운 별: ends as a small, faint star in its mood's color.
    var unlitColor: Color? = nil
    var onShow: () -> Void

    @State private var phase = DebugScreen.is("62") ? 1 : 0

    private static let titles = ["마음을 모으는 중", "빛이 번져요", "별이 모양을 이뤄요", "별이 떴어요"]

    var body: some View {
        let done = phase == 3
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0).frame(maxHeight: done ? 24 : 199)

            Text(Self.titles[phase])
                .textStyle(.h2)
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)

            ZStack {
                // Halo: gold, then violet as it takes shape, then gold again.
                Circle()
                    .fill((phase == 2 ? Color.brandPrimary : Color.starBright).opacity(0.16))
                    .frame(width: [0, 90, 140, 150][phase], height: [0, 90, 140, 150][phase])
                    .shadow(color: (phase == 2 ? Color.brandPrimary : Color.starBright).opacity(phase == 3 ? 0 : 0.45), radius: 14)
                let core = unlitColor ?? Color.starBright
                let sizes: [CGFloat] = unlitColor == nil ? [6, 16, 40, 48] : [6, 12, 20, 22]
                Circle()
                    .fill(core.opacity(phase == 0 ? 0.9 : (unlitColor == nil ? 1 : 0.7)))
                    .frame(width: sizes[phase], height: sizes[phase])
                    .shadow(color: core.opacity(phase == 0 ? 0 : (unlitColor == nil ? 0.5 : 0.25)), radius: 14)
                if done {
                    Circle().fill(Color.starClear).frame(width: 6, height: 6)
                        .shadow(color: Color.starClear.opacity(0.4), radius: 10)
                        .offset(x: -84, y: -82)
                        .transition(.opacity)
                    Circle().fill(Color.brandWarm).frame(width: 5, height: 5)
                        .shadow(color: Color.brandWarm.opacity(0.35), radius: 12)
                        .offset(x: 87, y: 68)
                        .transition(.opacity)
                }
            }
            .frame(height: done ? 320 : 320)
            .accessibilityHidden(true)

            Spacer(minLength: 0)

            Button("별 보기", action: onShow)
                .buttonStyle(.primary)
                .opacity(done ? 1 : 0)
                .disabled(!done)
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StarField() }
        .task {
            if reduceMotion {
                phase = 3
                return
            }
            // Figma timeline: 0.0s · 0.6s first-light · 1.2s · 1.7s star-birth
            for (i, wait) in [0.6, 0.6, 0.5].enumerated() {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: i == 2 ? 0.5 : 0.6)) { phase = i + 1 }
            }
            UIAccessibility.post(notification: .announcement, argument: "별이 떴어요")
        }
    }
}

#Preview("88") {
    let model = AppModel()
    model.fillSampleStars()
    return TelescopeObserveView(star: model.stars[0], onDone: {}, onClose: {}).environment(model)
}

#Preview("61–64") {
    StarBirthView(onShow: {})
}
