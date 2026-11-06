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
                Text("조용히 품은 별이에요. 분석 없이 그대로 간직하고 있어요.")
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
        .sheet(isPresented: $confirmShare) {
            ShareConsentSheet(
                onShare: {
                    model.setShared(true, for: starID)
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
    }

    /// Plain-text export of the entry (title, date, body).
    private func exportText(_ star: StarItem) -> String {
        [star.title, star.longDateText, "", star.body]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
