import SwiftUI

/// 12 Star Detail: the full entry, its card (if floated), and actions.
struct StarDetailView: View {
    @Environment(AppModel.self) private var model
    var starID: StarItem.ID
    var onBack: () -> Void
    /// "이 주제로 다시 쓰기" → 14 Rewrite
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
    /// 12 「마음 망원경 켜기」 (24/25) or 12-2 「망원경 리포트 보기 ›」 (10).
    var onTelescope: () -> Void = {}

    @State private var confirmDelete = DebugScreen.is("15")
    @State private var confirmShare = DebugScreen.is("19")
    @State private var shareSheetHeight: CGFloat = 336
    /// 19-1: opens after 19 "익명으로 나누기" closes.
    @State private var pickQuote = DebugScreen.is("19-1")
    /// 12-5: 별빛 풀이 folded at first (open for the 12-5 review).
    @State private var showBreakdown = DebugScreen.is("12-5")
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

            // Figma 12 / 12-2: straight to the telescope from a floated star.
            if star.isFloated {
                Button(model.report(for: star.id) == nil ? "마음 망원경 켜기" : "망원경 리포트 보기 ›",
                       action: onTelescope)
                    .buttonStyle(.secondary)
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
            if star.isFloated {
                Button("이 주제로 다시 쓰기") { onRewrite() }
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
                    Button("우주 광장에 나누기") { confirmShare = true }
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

    /// Plain-text export of the entry (title, date, body).
    private func exportText(_ star: StarItem) -> String {
        [star.title, star.longDateText, "", star.body]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
