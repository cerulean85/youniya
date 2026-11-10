import SwiftUI

/// 11 Consent: shown once after the first sign-in.
struct ConsentView: View {
    @Environment(AppModel.self) private var model
    /// Back to login (signs out).
    var onBack: () -> Void

    private enum Term: String, CaseIterable, Identifiable {
        case terms = "(필수) 이용약관"
        case privacy = "(필수) 개인정보 처리방침"
        case sensitive = "(필수) 심리 일기 수집·이용(민감정보)"
        case marketing = "(선택) 새 기능·혜택 알림"
        var id: Self { self }
        var isRequired: Bool { self != .marketing }
        /// The full-text page (43–45, and the marketing consent).
        var document: PolicyDoc {
            switch self {
            case .terms: .terms
            case .privacy: .privacy
            case .sensitive: .sensitive
            case .marketing: .marketing
            }
        }
    }

    @State private var agreed: Set<Term> = []
    @State private var openDocument: Term?

    private var allAgreed: Bool { agreed.count == Term.allCases.count }
    private var canStart: Bool { Term.allCases.filter(\.isRequired).allSatisfy(agreed.contains) }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "가입 동의", onBack: onBack)

            VStack(alignment: .leading, spacing: Space.lg) {
                Text("시작하기 전에\n함께 약속할게요")
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)

                NoticeBanner(message: "쓴 글은 AI 학습에 쓰이지 않아요. 언제든 모두 삭제할 수 있고, YOUNIYA는 상담이나 진단을 대신하지 않아요.")

                VStack(spacing: 0) {
                    CheckboxRow(label: "전체 동의", isChecked: allAgreed, showsChevron: false) {
                        agreed = allAgreed ? [] : Set(Term.allCases)
                    }
                    ForEach(Term.allCases) { term in
                        CheckboxRow(label: term.rawValue, isChecked: agreed.contains(term),
                                    onToggle: { toggle(term) },
                                    onOpen: { openDocument = term })
                    }
                }

                Spacer(minLength: 0)

                Button("동의하고 시작하기") {
                    model.acceptConsent(marketing: agreed.contains(.marketing))
                }
                .buttonStyle(.primary)
                .disabled(!canStart)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .sheet(item: $openDocument) { term in
            PolicyDocView(doc: term.document, onBack: { openDocument = nil })
                .presentationBackground(Color.bgCanvas)
        }
    }

    private func toggle(_ term: Term) {
        if agreed.contains(term) { agreed.remove(term) } else { agreed.insert(term) }
    }
}

/// Figma `Checkbox Row`: 22pt rounded box, label, optional chevron to the full text.
struct CheckboxRow: View {
    var label: String
    var isChecked: Bool
    var showsChevron = true
    var onToggle: () -> Void
    var onOpen: () -> Void = {}

    var body: some View {
        HStack(spacing: Space.md) {
            Button(action: onToggle) {
                HStack(spacing: Space.md) {
                    ZStack {
                        if isChecked {
                            RoundedRectangle(cornerRadius: 6).fill(Color.brandPrimary)
                            Image(.iconCheck).resizable().frame(width: 14, height: 14)
                        } else {
                            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.borderDefault, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 22, height: 22)

                    Text(label)
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityAddTraits(isChecked ? .isSelected : [])

            if showsChevron {
                Button(action: onOpen) {
                    chevron.contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) 전문 보기")
            } else {
                // Figma shows the chevron on every row; without a full text it just toggles.
                chevron
                    .contentShape(.rect)
                    .onTapGesture(perform: onToggle)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.md - 5)
    }

    /// Figma `Icon/chevron-right`: 18pt, text/tertiary.
    private var chevron: some View {
        Image(.iconChevronRight)
            .renderingMode(.template)
            .resizable()
            .frame(width: 18, height: 18)
            .foregroundStyle(Color.textTertiary)
            .frame(width: 32, height: 32)
    }
}

/// Figma `Notice Banner`: Info (violet, info icon) or Warm (gold, star icon).
struct NoticeBanner: View {
    enum Tone { case info, warm }
    var message: String
    var tone: Tone = .info

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            switch tone {
            case .info:
                Image(.iconInfo).renderingMode(.template).resizable().frame(width: 20, height: 20)
                    .foregroundStyle(Color.accentTint)
            case .warm:
                Image(.iconStar).renderingMode(.template).resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.starBright)
            }
            Text(message)
                .textStyle(.bodyS)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.lg)
        .background(tone == .info ? Color.tintPrimarySoft : Color.tintGold, in: .rect(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ConsentView(onBack: {})
        .environment(AppModel())
}
