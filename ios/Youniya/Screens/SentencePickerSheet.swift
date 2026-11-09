import SwiftUI

// MARK: - 19-1 / 71-1 Sentence picker

/// One sentence the user can share, with where it came from (71-1 only).
struct SentenceOption: Identifiable, Hashable {
    var id: Int
    /// 71-1: "별 제목 · 11월 3일". Nil on 19-1, where all come from one star.
    var caption: String?
    /// The original sentence, exactly as written: the server checks it is in the
    /// star's text and masks it again before anything is public.
    var sentence: String
}

/// How a sentence will look once masked, and what was hidden.
struct MaskPreview: Equatable {
    var masked: String
    var names = 0
    var contacts = 0
    var places = 0

    var total: Int { names + contacts + places }

    /// "이름 1곳을 가린 채로 올라가요", or nil when nothing is hidden.
    var note: String? {
        let parts = [("이름", names), ("연락처", contacts), ("장소", places)]
            .filter { $0.1 > 0 }
            .map { "\($0.0) \($0.1)곳" }
        return parts.isEmpty ? nil : parts.joined(separator: "·") + "을 가린 채로 올라가요"
    }

    /// The on-device pass (same patterns as the server).
    init(local text: String, contactsOnly: Bool = false) {
        let s = PrivacyScan(text, contactsOnly: contactsOnly)
        self.init(masked: s.masked, names: s.names, contacts: s.contacts, places: s.places)
    }

    init(masked: String, names: Int = 0, contacts: Int = 0, places: Int = 0) {
        self.masked = masked
        self.names = names
        self.contacts = contacts
        self.places = places
    }
}

extension String {
    /// The sentences of a star's text, each with its end mark. Every one is a
    /// substring of the text, as the server requires for a quote.
    var shareSentences: [String] {
        var out: [String] = []
        var current = ""
        let ends: Set<Character> = [".", "!", "?", "…", "。"]
        let chars = Array(self)
        for (i, c) in chars.enumerated() {
            if c == "\n" {
                out.append(current)
                current = ""
                continue
            }
            current.append(c)
            // Cut after the last of a run of end marks ("?!", "...") and closing quotes.
            let next = i + 1 < chars.count ? chars[i + 1] : nil
            if ends.contains(c), let n = next, ends.contains(n) || n == "\"" || n == "”" || n == "'" { continue }
            if ends.contains(c) || ((c == "\"" || c == "”" || c == "'") && i > 0 && ends.contains(chars[i - 1])) {
                out.append(current)
                current = ""
            }
        }
        out.append(current)
        return out
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 && $0.count <= 300 }
    }
}

extension Array where Element == SentenceOption {
    /// The default pick: the longest sentence (as before the picker existed).
    var longestID: Int? { self.max(by: { $0.sentence.count < $1.sentence.count })?.id }
}

/// 19-1 어떤 문장을 나눌까요? / 71-1 함께 보일 한 줄을 골라요.
/// One radio card per sentence; the chosen one shows how the server will mask it.
struct SentencePickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.skyTheme) private var theme
    var title: String
    var detail: String
    var actionTitle: String
    var options: [SentenceOption]
    /// The sheet's height cap (85% of the screen); the list scrolls inside it.
    var maxHeight: CGFloat
    var onPick: (String) -> Void
    var onCancel: () -> Void
    /// 19-1: the whole star goes public with the picked 대표 문장. Only phone
    /// numbers and emails are hidden, and the masked text can be previewed.
    var fullText: (title: String, body: String)? = nil

    @State private var selected: Int?
    @State private var showFullText = false
    /// Server previews by option id (live), fetched once per pick.
    @State private var previews: [Int: MaskPreview] = [:]
    @State private var listHeight: CGFloat = 0
    @State private var chromeHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chromeHeight = $0 }

            ScrollView {
                VStack(spacing: Space.sm) {
                    ForEach(options) { optionCard($0) }
                    if let fullText { fullTextPreview(fullText) }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .frame(height: min(listHeight, listCap))

            VStack(spacing: Space.md) {
                Button(actionTitle) {
                    if let s = options.first(where: { $0.id == selected }) { onPick(s.sentence) }
                }
                .buttonStyle(.primary)
                .disabled(selected == nil)
                Button("취소", action: onCancel).buttonStyle(.ghost)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.md)
        .padding(.bottom, Space.xxl)
        .onAppear { if selected == nil { selected = options.longestID } }
        .task(id: selected) {
            guard let id = selected, previews[id] == nil,
                  let option = options.first(where: { $0.id == id }) else { return }
            previews[id] = await model.maskPreview(option.sentence, contactsOnly: fullText != nil)
        }
    }

    /// Room left for the list: cap minus handle, copy, buttons and paddings.
    private var listCap: CGFloat {
        // Buttons 48 + 12 + 48, three 16pt gaps, 12 top and 32 bottom padding.
        max(160, maxHeight - chromeHeight - 108 - 3 * Space.lg - Space.md - Space.xxl)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Capsule().fill(Color.borderDefault).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title).textStyle(.h3).foregroundStyle(Color.textPrimary)
                Text(detail).textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    /// Figma `Radio` (18pt): a slate ring, or an accent ring around a white dot.
    /// Drawn rather than the SVG so it follows the sky theme.
    private func radio(_ isOn: Bool) -> some View {
        ZStack {
            if isOn {
                Circle().fill(theme.accent.strong)
                Circle().fill(Color.white).frame(width: 8, height: 8)
            } else {
                Circle().strokeBorder(Color.textSecondary, lineWidth: 1.5)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }

    private func optionCard(_ option: SentenceOption) -> some View {
        let isOn = option.id == selected
        // The chosen card shows the server's masking; the rest, the on-device pass.
        let preview = (isOn ? previews[option.id] : nil)
            ?? MaskPreview(local: option.sentence, contactsOnly: fullText != nil)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selected = option.id }
        } label: {
            HStack(spacing: Space.md) {
                radio(isOn)
                VStack(alignment: .leading, spacing: Space.xs) {
                    if let caption = option.caption {
                        Text(caption).textStyle(.caption).foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    Text("“\(preview.masked)”")
                        .textStyle(.bodyM)
                        .foregroundStyle(Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isOn, let note = preview.note {
                        Text(note).textStyle(.labelS).foregroundStyle(theme.accent.tint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, 14)
            // Figma: slate card 70%, 1pt border; selected: accent tint 14%, 1.5pt
            // accent border (violet in the Figma frame), like the selected DotChip.
            .background(isOn ? theme.accent.tint.opacity(0.14) : Color.bgSurface.opacity(0.7),
                        in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(isOn ? theme.accent.strong : Color.borderDefault, lineWidth: isOn ? 1.5 : 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

extension SentencePickerSheet {
    /// 19-1: "글 전체 미리 보기", folded; opens to the title and body as they
    /// will look on the plaza (phone numbers and emails as ●●●).
    fileprivate func fullTextPreview(_ text: (title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { showFullText.toggle() }
            } label: {
                HStack {
                    Text("글 전체 미리 보기").textStyle(.labelM).foregroundStyle(Color.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(showFullText ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(showFullText ? "펼침" : "접힘")

            if showFullText {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(PrivacyScan(text.title, contactsOnly: true).masked)
                        .textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Text(PrivacyScan(text.body, contactsOnly: true).masked)
                        .textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, 14)
        .background(Color.bgSurface.opacity(0.7), in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.borderDefault, lineWidth: 1))
        .padding(.top, Space.xs)
    }
}

// MARK: - AppModel

/// `mode`: "contacts" for a whole-text share (19-1), "all" otherwise (71-1).
private struct ScanIn: Encodable { var text: String; var mode = "all" }
private struct ScanOut: Decodable {
    struct Counts: Decodable { var names: Int; var contacts: Int; var places: Int }
    var masked: String
    var counts: Counts
}

extension AppModel {
    /// 19-1 / 71-1 preview: the server's masking of one chosen sentence
    /// (`POST /v1/plaza/privacy-scan`, 60 a minute). Mock, or when the call
    /// fails: the on-device pass with the same patterns.
    @MainActor func maskPreview(_ sentence: String, contactsOnly: Bool = false) async -> MaskPreview {
        guard useLiveAPI, isSignedIn else { return MaskPreview(local: sentence, contactsOnly: contactsOnly) }
        do {
            let r: ScanOut = try await APIClient.shared.post("/v1/plaza/privacy-scan",
                                                             body: ScanIn(text: sentence, mode: contactsOnly ? "contacts" : "all"))
            return MaskPreview(masked: r.masked, names: r.counts.names, contacts: r.counts.contacts, places: r.counts.places)
        } catch {
            return MaskPreview(local: sentence, contactsOnly: contactsOnly)
        }
    }

    /// 19-1: the sentences of one star, in the order written.
    func sentenceOptions(for id: StarItem.ID) -> [SentenceOption] {
        guard let star = stars.first(where: { $0.id == id }) else { return [] }
        return star.body.shareSentences.enumerated().map { SentenceOption(id: $0, sentence: $1) }
    }

}
