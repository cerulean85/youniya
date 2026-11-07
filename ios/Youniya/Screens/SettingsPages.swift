import SwiftUI

// MARK: - 43–46 Policy documents

/// 43 이용약관 · 44 개인정보 처리방침 · 45 민감정보 수집·이용 동의 · 46 결제·환불 정책.
/// TODO: Load the reviewed legal text from the server so it can change without a release.
enum PolicyDoc: String, CaseIterable, Identifiable {
    case terms, privacy, sensitive, payment
    /// The optional consent on 11. No Figma page; it follows the 43–45 layout.
    case marketing

    var id: Self { self }

    var title: String {
        switch self {
        case .terms: "이용약관"
        case .privacy: "개인정보 처리방침"
        case .sensitive: "민감정보 수집·이용 동의"
        case .payment: "결제·환불 정책"
        case .marketing: "새 기능·혜택 알림 수신 동의"
        }
    }

    /// Top app bar title; 46 uses a narrower dot.
    var barTitle: String {
        switch self {
        case .payment: "결제 · 환불 정책"
        case .marketing: "새 기능·혜택 알림"
        default: title
        }
    }

    var effectiveDate: String { "시행일 2026년 11월 1일" }

    var sections: [(String, String)] {
        switch self {
        case .terms: [
            ("제1조 (목적)", "이 약관은 YOUNIYA가 제공하는 마음 기록 서비스의 이용 조건과 절차, 이용자와 회사의 권리와 의무를 정합니다."),
            ("제2조 (서비스의 성격)", "YOUNIYA는 자기 이해를 돕는 기록 도구이며, 의료·상담·진단을 대신하지 않습니다. 위기 상황에서는 전문 기관의 도움을 받으세요."),
            ("제3조 (이용자의 글)", "이용자가 쓴 글의 권리는 이용자에게 있으며, 회사는 서비스 제공 외의 목적으로 글을 사용하지 않습니다."),
            ("제4조 (코인과 결제)", "코인은 마음 망원경, 서사 다듬기, 하루 1개를 넘는 별 띄우기에 사용됩니다. 기록 작성과 조용히 간직하기는 코인 없이 이용할 수 있습니다."),
        ]
        case .privacy: [
            ("1. 수집하는 항목", "이메일, 로그인 식별자, 기기 정보, 이용자가 작성한 글과 분석 결과를 수집합니다."),
            ("2. 이용 목적", "서비스 제공, 계정 관리, 결제 처리, 문의 응대에 사용합니다. AI 모델 학습에는 사용하지 않습니다."),
            ("3. 보관과 삭제", "이용자는 설정에서 언제든 모든 데이터를 내보내거나 영구 삭제할 수 있습니다."),
            ("4. 문의", "개인정보 관련 문의는 앱 내 문의하기로 접수해 주세요."),
        ]
        case .sensitive: [
            ("수집 항목", "이용자가 쓴 심리 일기와 그로부터 만들어진 감정 분석 결과는 민감정보에 해당할 수 있습니다."),
            ("이용 목적", "이용자 본인에게 별과 성운을 보여주는 용도로만 사용하며, 제3자에게 제공하지 않습니다."),
            ("동의 거부 권리", "동의하지 않을 수 있으나, 이 경우 기록 기능을 이용할 수 없습니다. 동의 후에도 설정에서 철회할 수 있습니다."),
        ]
        case .payment: [
            ("결제", "코인은 앱 스토어 결제를 통해 충전되며 즉시 지급됩니다."),
            // TODO: Legal review of the refund wording (Figma 46, 2026-11-07).
            ("환불", "구매 후 7일 이내에 환불을 요청할 수 있습니다. 환불하면 그 결제로 받은 코인만큼 잔액에서 거두며, 거둔 뒤 잔액이 0보다 적어지는 경우(이미 코인을 사용한 경우)에는 환불되지 않습니다. 환불을 요청하면 해당 결제의 코인 사용 내역이 앱 스토어에 전달됩니다."),
            ("환불된 결제", "그럼에도 앱 스토어에서 결제가 환불되면 그 결제로 받은 코인을 거둡니다. 잔액이 부족하면 남아 있는 코인만 거두며, 코인 잔액은 0 아래로 내려가지 않습니다."),
            ("분석 실패 시", "분석에 실패한 경우 코인은 차감되지 않거나 자동으로 반환됩니다."),
        ]
        // TODO: Final wording from legal review.
        case .marketing: [
            ("받는 소식", "새로 생긴 기능, 코인 혜택과 이벤트 소식을 앱 알림으로 보내 드립니다. 기록을 재촉하거나 연속 기록을 요구하는 알림은 보내지 않습니다."),
            ("이용하는 정보", "알림을 보내기 위해 기기 알림 식별자와 동의 여부만 사용합니다. 이용자가 쓴 글과 분석 결과는 사용하지 않습니다."),
            ("보관 기간", "동의를 철회하거나 계정을 삭제할 때까지 보관하며, 그 즉시 지웁니다."),
            ("동의 거부와 철회", "선택 항목이라 동의하지 않아도 모든 기능을 쓸 수 있습니다. 동의한 뒤에도 설정 › 알림에서 언제든 끌 수 있습니다."),
        ]
        }
    }
}

/// 43–46: title, effective date, then numbered sections.
struct PolicyDocView: View {
    var doc: PolicyDoc
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: doc.barTitle, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    Text(doc.title)
                        .textStyle(.h1)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(doc.effectiveDate)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textSecondary)

                    ForEach(doc.sections, id: \.0) { heading, body in
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text(heading)
                                .textStyle(.h3)
                                .foregroundStyle(Color.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text(body)
                                .textStyle(.bodyM)
                                .foregroundStyle(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xxxl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
    }
}

// MARK: - 68 Sky Color

/// 68 우주의 색: pick a sky; "적용하기" saves it and the whole app follows.
struct SkyColorView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void

    @State private var selected: SkyTheme = .violet

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "우주의 색", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        Text("어떤 밤하늘이\n편안한가요?")
                            .textStyle(.h1)
                            .foregroundStyle(Color.textPrimary)
                        Text("우주의 색은 사람마다 다르게 느껴져요. 언제든 바꿀 수 있고, 기록은 그대로예요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    VStack(spacing: Space.md) {
                        ForEach(SkyTheme.allCases) { theme in
                            SkyOptionRow(theme: theme, isSelected: theme == selected) {
                                withAnimation(.snappy(duration: 0.2)) { selected = theme }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            Button("적용하기") {
                withAnimation(.easeInOut(duration: 0.5)) { model.settings.sky = selected }
                onBack()
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .onAppear { selected = model.settings.sky }
    }
}

/// Figma `Theme / …` row: swatch, name and mood, radio.
private struct SkyOptionRow: View {
    var theme: SkyTheme
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                SkySwatch(theme: theme)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(theme.name)
                        .textStyle(.labelM)
                        .foregroundStyle(Color.textPrimary)
                    Text(theme.detail)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Figma `Radio`: 22pt, filled violet when selected.
                ZStack {
                    Circle().strokeBorder(isSelected ? Color.brandPrimary : Color.borderDefault, lineWidth: 2)
                    if isSelected { Circle().fill(Color.brandPrimary) }
                }
                .frame(width: 22, height: 22)
            }
            .padding(Space.md)
            // Figma: surface + Cosmos BG, 1pt slate border; 2pt violet when selected.
            .cosmos("sky-\(theme.rawValue)", in: RoundedRectangle(cornerRadius: Radius.lg))
            .background(Color.bgSurface, in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(isSelected ? Color.borderFocus : Color.borderDefault, lineWidth: isSelected ? 2 : 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Figma `Swatch` (76×52): three soft glows over the night, with one star each.
private struct SkySwatch: View {
    var theme: SkyTheme

    var body: some View {
        let (a, b, c) = theme.colors
        ZStack(alignment: .topLeading) {
            Color.hex(0x0A0D1A)
            glow(a, 0.8, size: 70, x: -10, y: -26)
            glow(b, 0.6, size: 60, x: 30, y: 10)
            glow(c, 0.5, size: 40, x: 8, y: 20)
            dot(a, x: 18, y: 18)
            dot(b, x: 44, y: 32)
            dot(c, x: 60, y: 14)
        }
        .frame(width: 76, height: 52)
        .clipShape(.rect(cornerRadius: Radius.md))
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, _ alpha: Double, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(alpha), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }

    private func dot(_ color: Color, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(color).frame(width: 4, height: 4).offset(x: x, y: y)
    }
}

// MARK: - Toast (T1)

/// Figma `Toast`: a short pill above the bottom edge, with a cyan dot.
struct ToastView: View {
    var message: String

    var body: some View {
        HStack(spacing: Space.sm) {
            Circle().fill(Color.starClear).frame(width: 6, height: 6)
            Text(message)
                .textStyle(.bodyS)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.md)
        .cosmos("toast", in: Capsule())
        .background(Color.bgSurfaceRaised, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Shows `message` as a toast for about two seconds, then clears it.
    func toast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                ToastView(message: text)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: text) {
                        UIAccessibility.post(notification: .announcement, argument: text)
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(.easeInOut(duration: 0.3)) { message.wrappedValue = nil }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: message.wrappedValue)
    }
}

#Preview("43") {
    PolicyDocView(doc: .terms, onBack: {})
}

#Preview("68") {
    SkyColorView(onBack: {}).environment(AppModel())
}

// MARK: - 93 Data export

/// Writes the export into Documents, which the Files app shows under YOUNIYA.
/// The journal itself stays in Application Support, out of Files.
enum DataExport {
    enum Format { case text, pdf }

    static func write(_ text: String, as format: Format) throws -> URL {
        let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        let base = "YOUNIYA-\(f.string(from: .now))"
        switch format {
        case .text:
            let url = docs.appending(path: base + ".txt")
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        case .pdf:
            let url = docs.appending(path: base + ".pdf")
            try pdf(text).write(to: url, options: .atomic)
            return url
        }
    }

    /// A4 pages of plain text, paginated by the print renderer.
    private static func pdf(_ text: String) -> Data {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        let html = "<div style=\"font-family: -apple-system; font-size: 12pt; line-height: 1.6\">\(escaped)</div>"
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(UIMarkupTextPrintFormatter(markupText: html), startingAtPageAt: 0)
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        renderer.setValue(page, forKey: "paperRect")
        renderer.setValue(page.insetBy(dx: 48, dy: 56), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, nil)
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

// MARK: - 17/18 나눈 별 (87 → 우주 광장)

/// The stars shared to the plaza, opened from Settings › 우주 광장 › 나눈 별.
/// No Figma page; built from the records list (Star Row) and the empty state.
struct SharedStarsView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpenStar: (StarItem) -> Void
    var onPlaza: () -> Void

    @State private var toast: ToastCardMessage?
    /// Live: GET /v1/me/shares → stars, newest share first.
    @State private var liveShares: [SharedStar] = []

    private var shared: [StarItem] {
        guard model.useLiveAPI else { return model.stars.filter(\.isShared) }
        return liveShares.compactMap { s in
            guard let id = UUID(uuidString: s.starId) else { return nil }
            // Figma 17 row: title · written_at (KST) · starlight
            return model.stars.first { $0.id == id } ?? StarItem(
                id: id, title: s.title, dateText: StarItem.dateText(s.writtenAt),
                state: .floated(starlight: s.starlight), createdAt: s.writtenAt, sharedToPlaza: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "나눈 별", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    if !shared.isEmpty {
                        Text("우주 광장에 익명으로 나눈 별 \(shared.count)개예요. 거두면 광장에서 바로 사라지고, 받은 공명과 별빛 한 줄은 그대로 간직돼요.")
                            .textStyle(.bodyM)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if shared.isEmpty {
                        EmptyStateView(
                            title: "아직 나눈 별이 없어요",
                            message: "띄운 별을 열어 ‘우주 광장에 나누기’를 누르면\n여기에 모여요.",
                            action: ("우주 광장 둘러보기", .outline, onPlaza)
                        )
                        .padding(.top, Space.xxxl)
                    } else {
                        LazyVStack(spacing: Space.md) {
                            ForEach(shared) { star in
                                row(star)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xxxl)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .toastCard($toast)
        .animation(.snappy, value: shared.map(\.id))
        .task { await loadLive() }
    }

    private func loadLive() async {
        guard model.useLiveAPI else { return }
        do {
            liveShares = try await model.loadSharedStars()
        } catch {
            model.handle(error)
        }
    }

    private func row(_ star: StarItem) -> some View {
        VStack(alignment: .trailing, spacing: Space.xs) {
            Button { onOpenStar(star) } label: { StarRow(star: star) }
                .buttonStyle(.plain)
            Button("광장에서 거두기") { withdraw(star) }
            .textStyle(.labelS)
            .foregroundStyle(Color.textSecondary)
            .buttonStyle(.plain)
            .padding(.vertical, Space.xs)
            .padding(.trailing, Space.xs)
            .accessibilityLabel("\(star.title) 광장에서 거두기")
        }
        .transition(.opacity)
    }

    private func withdraw(_ star: StarItem) {
        guard model.useLiveAPI else {
            model.setShared(false, for: star.id)
            toast = .init(title: "광장에서 거뒀어요", detail: "언제든 다시 나눌 수 있어요")
            return
        }
        Task { @MainActor in
            do {
                try await model.withdrawShareLive(starID: star.id.apiID)
                liveShares.removeAll { $0.starId == star.id.apiID }
                toast = .init(title: "광장에서 거뒀어요", detail: "언제든 다시 나눌 수 있어요")
            } catch {
                model.handle(error)
            }
        }
    }
}
