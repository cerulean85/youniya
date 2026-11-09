import SwiftUI

// MARK: - 09-6 / 04-1 gold banner

/// Figma `Notice · Gold`: a title, one or two lines, and a link on the right.
struct OperatorBanner: View {
    var title: String
    var message: String
    var link: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).textStyle(.labelM).foregroundStyle(Color.starBright)
                    Spacer(minLength: Space.sm)
                    Text("\(link) ›").textStyle(.labelS).foregroundStyle(Color.starBright)
                }
                Text(message).textStyle(.caption).foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.lg)
            .background(Color.tintGold.opacity(0.6), in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.starBright.opacity(0.55), lineWidth: 1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 09-7 광장 이용 제한 안내

struct PlazaRestrictedSheet: View {
    @Environment(AppModel.self) private var model
    var onInquiry: () -> Void

    var body: some View {
        ActionSheetContent(
            title: "광장 이용이 잠시 멈춰 있어요",
            message: "\(model.restrictedText(withTime: true))까지 별을 나누거나 공명·곁에 두기·별빛 한 줄을 남길 수 없어요. 신고가 확인되어 운영자가 정한 조치예요.\n내 기록과 별은 그대로이고, 광장의 다른 별은 계속 읽을 수 있어요.",
            primary: ("확인", { model.showPlazaRestricted = false }),
            secondary: ("문의하기", { model.showPlazaRestricted = false; onInquiry() }),
            ghost: nil
        )
    }
}

// MARK: - 130 알림함

/// 130 알림 (523:15104): operator actions and notices, newest first. A row
/// opens what it is about; unread rows have a brighter dot.
struct InboxView: View {
    @Environment(AppModel.self) private var model
    var onBack: () -> Void
    var onOpen: (NotificationTarget) -> Void

    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "알림", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("운영자 조치와 공지를 모아 둬요. 누르면 관련 화면으로 가요.")
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                    if model.inbox.isEmpty && loaded {
                        Text("아직 받은 알림이 없어요. 운영자 조치와 공지가 생기면 여기에 모여요.")
                            .textStyle(.bodyM).foregroundStyle(Color.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                    ForEach(model.inbox) { row($0) }
                }
                .padding(.horizontal, Space.xl)
                .padding(.vertical, Space.sm)
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .task {
            await model.loadInbox()
            loaded = true
        }
    }

    private func row(_ item: InboxItem) -> some View {
        let (label, color) = item.kindLabel
        return Button {
            Task { await model.markRead([item.id]) }
            if let t = item.target, t != .inbox { onOpen(t) }
        } label: {
            HStack(alignment: .top, spacing: Space.md) {
                Circle().fill(color.opacity(item.read ? 0.35 : 1)).frame(width: 7, height: 7).padding(.top, 5)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(label).textStyle(.caption).foregroundStyle(color)
                    Text(item.title).textStyle(.labelM).foregroundStyle(Color.textPrimary)
                    Text(item.body).textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text([PlazaStarRow.when(item.createdAt), item.target?.label.map { "\($0) ›" }]
                            .compactMap { $0 }.joined(separator: " · "))
                        .textStyle(.caption).foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Space.lg)
            .itemCard(seed: "inbox-\(item.id)", minHeight: 0)
            .opacity(item.read ? 0.85 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.read ? "" : "읽지 않음")
    }
}

// MARK: - 131 공지 상세

struct NoticeDetailView: View {
    @Environment(AppModel.self) private var model
    var noticeID: String
    var onBack: () -> Void

    private var notice: AppNoticeItem? { model.notices.first { $0.id == noticeID } }

    var body: some View {
        VStack(spacing: 0) {
            TopAppBar(title: "공지", onBack: onBack)
            ScrollView {
                if let n = notice {
                    VStack(alignment: .leading, spacing: Space.md) {
                        Text("\(Self.day(n.publishedAt)) · 공지").textStyle(.caption).foregroundStyle(Color.textTertiary)
                        Text(n.title).textStyle(.h2).foregroundStyle(Color.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(n.body).textStyle(.bodyM).foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.xl)
                    .padding(.vertical, Space.sm)
                } else {
                    ProgressView().tint(.white).frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background { StarField() }
        .task { if notice == nil { await model.loadNotices() } }
    }

    private static func day(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일"
        return f.string(from: d)
    }
}
