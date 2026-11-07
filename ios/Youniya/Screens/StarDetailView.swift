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

    @State private var confirmDelete = DebugScreen.is("15")
    @State private var confirmShare = DebugScreen.is("19")
    @State private var shareSheetHeight: CGFloat = 336
    /// 19-1: opens after 19 "익명으로 나누기" closes.
    @State private var pickQuote = DebugScreen.is("19-1")
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
    }

    private func content(_ star: StarItem) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(star.longDateText)
                    .textStyle(.caption)
                    .foregroundStyle(Color.textTertiary)
                Text(star.title)
                    .textStyle(.h1)
                    .foregroundStyle(Color.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if !star.body.isEmpty {
                Text(star.body)
                    .textStyle(.journalBody)
                    .foregroundStyle(Color.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let analysis = star.analysis {
                TodayStarCard(analysis: analysis)
            } else if !star.isFloated {
                Text("조용히 간직한 별이에요. 분석 없이 그대로 남겨 두었어요.")
                    .textStyle(.bodyS)
                    .foregroundStyle(Color.textTertiary)
            }

            Button("이 주제로 다시 쓰기") { onRewrite() }
                .buttonStyle(.primary)
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
                title: "어떤 문장을 나눌까요?",
                detail: "고른 한 문장만 익명으로 올라가요. 이름·연락처·장소는 ●●●로 가려져요.",
                actionTitle: "이 문장 나누기",
                options: model.sentenceOptions(for: starID),
                maxHeight: screenHeight * 0.85,
                onPick: { sentence in
                    model.setShared(true, for: starID, quote: sentence)
                    pickQuote = false
                },
                onCancel: { pickQuote = false }
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
