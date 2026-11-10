import SwiftUI

/// 12 Star Detail: the full entry, its card (if floated), and actions.
struct StarDetailView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onBack: () -> Void
    /// 12-6 「새 글을 써서 잇기」 → 14 별 잇기 · 새 별 쓰기
    var onRewrite: () -> Void
    /// "내용 먼저 확인" on 19 → 20 Privacy Check.
    var onReviewShare: () -> Void
    /// After 15 "영구 삭제"; the parent closes the page and shows a 42 toast.
    var onDeleted: (() -> Void)? = nil
    /// "글 수정"
    var onEdit: () -> Void = {}
    /// A kept star's "별 띄우기" → 06/07.
    var onFloat: () -> Void = {}
    /// 05-2 고쳐 쓰기 (a star with starlight is locked, 2026-11-09).
    var onRevise: () -> Void = {}
    /// 12-6 「이미 쓴 별과 잇기」 → 12-7
    var onLinkExisting: () -> Void = {}
    /// 「이어진 별」 chip → that star
    var onOpenLinked: (StarItem) -> Void = { _ in }
    /// 12-4 「받은 별빛 한 줄 N개 ›」
    var onLines: () -> Void = {}

    @State private var confirmDelete = DebugScreen.is("15")
    @State private var confirmShare = DebugScreen.is("19")
    @State private var shareSheetHeight: CGFloat = 336
    /// 19-1: opens after 19 "익명으로 나누기" closes.
    @State private var pickQuote = DebugScreen.is("19-1")
    /// 12-5: 별빛 풀이 folded at first (open for the 12-5 review).
    @State private var showBreakdown = DebugScreen.is("12-5")
    /// 12-6 이 별과 무엇을 이을까요?
    @State private var askLink = DebugScreen.is("12-6")
    @State private var askLinkHeight: CGFloat = 300
    @State private var wantsPick = false
    @State private var pickerHeight: CGFloat = 480
    @State private var screenHeight: CGFloat = 844
    @State private var sheetHeight: CGFloat = 336

    var body: some View {
        if let star = model.stars.first(where: { $0.id == starID }) {
            detail(star)
        } else {
            // 122
            NotFoundView(onBack: onBack)
        }
    }

    private func detail(_ star: StarItem) -> some View {
        VStack(spacing: 0) {
            TopAppBar(title: "별 상세", onBack: onBack)

            LoadingGate {
                ScrollView {
                    content(star)
                        .padding(.horizontal, Space.xl)
                        .padding(.top, Space.sm)
                        .padding(.bottom, Space.xxxl)
                }
                .scrollIndicators(.hidden)
            } placeholder: {
                StarDetailSkeleton()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background { StarField() }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { screenHeight = $0 }
        .task(id: star.isShared) { if star.isShared { await model.refreshQuoteMissing(starID) } }
    }

    private func content(_ star: StarItem) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(star.isFloated ? star.longDateText : star.longDateText + " · 별빛 없는 별")
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                Text(star.title)
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            // 12-3: the edited text lost the shared 대표 문장.
            if star.isShared && star.shareQuoteMissing == true {
                NoticeBanner(message: "광장에 나눈 이 별의 대표 문장이 고친 글에 없어요. 대표 문장을 다시 골라 주세요.")
                Button("대표 문장 고르기") { pickQuote = true }
                    .buttonStyle(.secondary)
            }

            if !star.body.isEmpty {
                Text(star.body)
                    .textStyle(.journalBody)
                    .foregroundStyle(Color.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let analysis = star.analysis {
                // 12 / 12-5: the 별빛 풀이 starts folded here; the card or the
                // toggle opens it.
                TodayStarCard(analysis: analysis)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.3)) { showBreakdown.toggle() } }
                if showBreakdown {
                    StarlightBreakdown(analysis: analysis)
                        .transition(.opacity)
                }
                BreakdownToggle(isOpen: $showBreakdown)
            }

            if !star.isFloated {
                // 12-1: a star without starlight can get it later (once), from
                // 50 characters, at the same price as a new one.
                let long = star.body.count >= AppModel.minFloatLength
                Button("별빛 받기", action: onFloat)
                    .buttonStyle(.primary)
                    .disabled(!long)
                Text(long ? (model.isFloatFree ? "오늘 무료 1번 · 이후 " : "") + "한 번에 \(AppModel.floatCost)코인 · \(AppModel.minFloatLength)자부터 받을 수 있어요"
                          : "\(AppModel.minFloatLength)자부터 별빛을 받을 수 있어요 · 지금 \(star.body.count)자")
                    .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            // 12 / 12-4: lines others left on this star (only I read them).
            let lineCount = star.lineCount ?? model.mockReceivedLines[star.id]?.count ?? 0
            if star.isShared || lineCount > 0 {
                Button(lineCount > 0 ? "받은 별빛 한 줄 \(lineCount)개 ›" : "받은 별빛 한 줄 ›", action: onLines)
                    .buttonStyle(.secondary)
            }

            linkedGroup(star)

            if star.isFloated {
                Button("별 잇기") { askLink = true }
                    .buttonStyle(.primary)
            } else {
                // Figma 12-1: 다시 쓰기 follows a report's question, so a kept star
                // (no analysis) offers 글 수정 here instead.
                Button("글 수정", action: onEdit)
                    .buttonStyle(.secondary)
            }
            if star.isFloated {
                if star.isShared {
                    Button("우주 광장에서 거두기") { model.setShared(false, for: starID) }
                        .buttonStyle(.secondary)
                } else {
                    Button("우주 광장에 나누기") { if model.plazaAllowed() { confirmShare = true } }
                        .buttonStyle(.secondary)
                }
            }

            HStack(spacing: Space.md) {
                ShareLink(item: exportText(star)) {
                    Text("내보내기")
                }
                .buttonStyle(.ghost)

                if star.isFloated {
                    Button("고쳐 쓰기", action: onRevise)
                        .buttonStyle(.ghost)
                }

                Button("삭제") { confirmDelete = true }
                    .buttonStyle(.ghost)
            }
        }
        // 15 Delete Confirm
        .sheet(isPresented: $confirmDelete) {
            DeleteStarSheet(
                exportText: exportText(star),
                onKeep: { confirmDelete = false },
                onDelete: {
                    confirmDelete = false
                    model.deleteStar(starID)
                    (onDeleted ?? onBack)()
                }
            )
            // Size the sheet to its content, like the Figma bottom sheet.
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
            .presentationDetents([.height(sheetHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "delete-sheet") }
        }
        // 19 Share Consent
        .sheet(isPresented: $confirmShare, onDismiss: {
            if wantsPick { wantsPick = false; pickQuote = true }
        }) {
            ShareConsentSheet(
                onShare: {
                    // 19-1: pick the one sentence first.
                    wantsPick = true
                    confirmShare = false
                },
                onReview: {
                    confirmShare = false
                    onReviewShare()
                },
                onCancel: { confirmShare = false }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shareSheetHeight = $0 }
            .presentationDetents([.height(shareSheetHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "share-sheet") }
        }
        // 12-6 이 별과 무엇을 이을까요?
        .sheet(isPresented: $askLink) {
            ActionSheetContent(
                title: "이 별과 무엇을 이을까요?",
                message: "이은 별은 서로의 별 상세에 '이어진 별'로 보여요. 여러 별과 이을 수 있고, 언제든 끊을 수 있어요.",
                primary: ("새 글을 써서 잇기", { askLink = false; onRewrite() }),
                secondary: ("이미 쓴 별과 잇기", { askLink = false; onLinkExisting() }),
                ghost: ("취소", { askLink = false })
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { askLinkHeight = $0 }
            .presentationDetents([.height(askLinkHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "link-ask") }
        }
        // 19-1 어떤 문장을 나눌까요?
        .sheet(isPresented: $pickQuote) {
            SentencePickerSheet(
                title: "대표 문장 고르기",
                detail: "고른 문장은 광장 목록에 대표로 보여요. 글 전체도 함께 공개되고, 전화번호·이메일은 ●●●로 가려져요.",
                actionTitle: model.stars.first { $0.id == starID }?.isShared == true ? "이 문장으로 바꾸기" : "이 문장으로 나누기",
                options: model.sentenceOptions(for: starID),
                maxHeight: screenHeight * 0.85,
                onPick: { sentence in
                    model.setShared(true, for: starID, quote: sentence)
                    pickQuote = false
                },
                onCancel: { pickQuote = false },
                fullText: model.stars.first { $0.id == starID }.map { ($0.title, $0.body) }
            )
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pickerHeight = $0 }
            .presentationDetents([.height(pickerHeight)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Radius.xl)
            .presentationBackground { SheetBackground(seed: "quote-sheet") }
        }
    }

    /// 12-2 「이어진 별 N」: mood dot · title · date chips; a long press undoes one.
    @ViewBuilder private func linkedGroup(_ star: StarItem) -> some View {
        let linked = model.linkedStars(star.id)
        if !linked.isEmpty {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("이어진 별 \(linked.count)").textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                FlowRow(spacing: Space.sm) {
                    ForEach(linked) { other in
                        Button { onOpenLinked(other) } label: {
                            HStack(spacing: 6) {
                                Circle().fill(other.mood.color).frame(width: 7, height: 7)
                                Text(other.title).textStyle(.labelS).foregroundStyle(Color.textPrimary).lineLimit(1)
                                Text(other.shortDateText).textStyle(.caption).foregroundStyle(Color.textTertiary)
                            }
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, Space.sm)
                            .background(Color.bgSurface, in: .capsule)
                            .overlay(Capsule().strokeBorder(Color.borderDefault, lineWidth: 1))
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("연결 끊기", role: .destructive) {
                                Task { await model.unlinkStars(star.id, other.id) }
                            }
                        }
                        .accessibilityHint("길게 누르면 연결을 끊을 수 있어요")
                    }
                }
            }
        }
    }

    /// Plain-text export of the entry (title, date, body).
    private func exportText(_ star: StarItem) -> String {
        [star.title, star.longDateText, "", star.body]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
