import SwiftUI

// MARK: - 43–46 Policy documents

/// 43 이용약관 · 44 개인정보 처리방침 · 45 민감정보 수집·이용 동의 · 46 결제·환불 정책.
/// TODO: Load the reviewed legal text from the server so it can change without a release.
enum PolicyDoc: String, CaseIterable, Identifiable {
    case terms, privacy, sensitive, payment

    var id: Self { self }

    var title: String {
        switch self {
        case .terms: "이용약관"
        case .privacy: "개인정보 처리방침"
        case .sensitive: "민감정보 수집·이용 동의"
        case .payment: "결제·환불 정책"
        }
    }

    /// Top app bar title; 46 uses a narrower dot.
    var barTitle: String { self == .payment ? "결제 · 환불 정책" : title }

    var effectiveDate: String { "시행일 2026년 11월 1일" }

    var sections: [(String, String)] {
        switch self {
        case .terms: [
            ("제1조 (목적)", "이 약관은 YOUNIYA가 제공하는 마음 기록 서비스의 이용 조건과 절차, 이용자와 회사의 권리와 의무를 정합니다."),
            ("제2조 (서비스의 성격)", "YOUNIYA는 자기 이해를 돕는 기록 도구이며, 의료·상담·진단을 대신하지 않습니다. 위기 상황에서는 전문 기관의 도움을 받으세요."),
            ("제3조 (이용자의 글)", "이용자가 쓴 글의 권리는 이용자에게 있으며, 회사는 서비스 제공 외의 목적으로 글을 사용하지 않습니다."),
            ("제4조 (코인과 결제)", "코인은 마음 망원경 등 선택 기능에 사용됩니다. 기록 작성은 코인 없이 이용할 수 있습니다."),
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
            ("환불", "사용하지 않은 코인은 구매 후 7일 이내 환불을 요청할 수 있습니다. 사용한 코인은 환불되지 않습니다."),
            ("분석 실패 시", "분석에 실패한 경우 코인은 차감되지 않거나 자동으로 반환됩니다."),
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
                        .textStyleBox(.h1)
                        .foregroundStyle(Color.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(doc.effectiveDate)
                        .textStyleBox(.caption)
                        .foregroundStyle(Color.textSecondary)

                    ForEach(doc.sections, id: \.0) { heading, body in
                        VStack(alignment: .leading, spacing: Space.sm) {
                            Text(heading)
                                .textStyleBox(.h3)
                                .foregroundStyle(Color.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text(body)
                                .textStyleBox(.bodyM)
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
