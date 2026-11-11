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
            // Figma 43 (18:841), 2026-11-10: no telescope.
            ("제1조 (목적)", "이 약관은 YOUNIYA(이하 \"서비스\")가 제공하는 마음 기록 서비스의 이용 조건과 절차, 이용자와 운영자의 권리와 의무를 정합니다."),
            ("제2조 (용어)", "• 별: 이용자가 쓴 하루의 글과, 그 글로 만든 별을 말합니다.\n• 별 띄우기: 글을 별로 띄우는 일을 말합니다. 별빛 받고 띄우기는 별빛 프리즘이 글을 분석해 별빛(1~999)과 별빛 풀이를 함께 남기는 일이고, 별빛 없이 띄우기는 분석 없이 글만 별로 남기는 일입니다.\n• 별자리: 한 달 동안 띄운 별이 그달의 별자리 모양으로 저절로 모여 완성되는 것을 말합니다.\n• 별 잇기: 이용자가 자신의 별끼리 서로 이어 두는 일을 말합니다.\n• 우주 광장: 이용자가 나누기로 고른 별(대표 문장과 글 전체)을 별지기 이름과 함께 다른 이용자에게 보여 주는 공간을 말합니다.\n• 코인: 무료 횟수를 넘는 별빛 받기에 쓰는 서비스 안의 이용권을 말합니다."),
            ("제3조 (약관의 게시와 변경)", "운영자는 이 약관을 앱의 설정 › 약관 및 정책과 웹사이트에 게시합니다. 약관을 바꿀 때는 시행 7일 전부터, 이용자에게 불리한 변경은 30일 전부터 바뀌는 내용과 이유를 알립니다. 바뀐 약관에 동의하지 않으면 이용을 멈추고 계정을 삭제할 수 있습니다."),
            ("제4조 (계정)", "이용자는 Apple 또는 Google 계정으로 로그인해 가입합니다. 계정은 본인만 사용해야 하며, 다른 사람에게 빌려주거나 넘길 수 없습니다. 이용자는 설정 › 계정 영구 삭제에서 언제든 탈퇴할 수 있습니다."),
            ("제5조 (서비스의 성격)", "YOUNIYA는 자기 이해를 돕는 기록 도구이며, 의료·상담·진단을 대신하지 않습니다. 별빛 프리즘의 분석은 AI가 만든 참고 정보이며, 그 정확성을 보장하지 않습니다.\n\n글에서 위기 신호가 보이면 그 글은 쓴 그대로 저장하되 분석하거나 공유하지 않고, 24시간 위기 상담(109) 안내를 보여 드립니다."),
            ("제6조 (이용자의 글)", "이용자가 쓴 글의 권리는 이용자에게 있으며, 운영자는 서비스 제공 외의 목적으로 글을 사용하지 않습니다. 글과 분석 결과는 AI 모델 학습에 쓰지 않습니다.\n\n이용자가 별을 우주 광장에 나누면 고른 대표 문장과 그 별의 글 전체(제목과 본문)가 이용자의 별지기 이름과 함께 다른 이용자에게 보입니다. 글에 쓴 이름이나 장소는 그대로 보이고, 전화번호·이메일 같은 연락처는 자동으로 가려집니다. 별빛을 받은 별은 고칠 수 없고, 고쳐 쓰면 새 별이 됩니다. 별빛 없이 띄운 별은 나눈 뒤 고치면 광장의 글도 바뀝니다. 이용자는 언제든 공유를 거둘 수 있습니다."),
            ("제7조 (우주 광장 이용 규칙)", "우주 광장에서는 다음 행동을 할 수 없습니다.\n• 자신이나 다른 사람의 연락처, 주소 등 개인정보를 드러내는 일\n• 다른 사람을 괴롭히거나 혐오·차별을 부추기는 일\n• 광고, 홍보, 다른 서비스로 이끄는 일\n• 다른 사람을 사칭하거나 법령에 어긋나는 내용을 올리는 일\n\n이용자는 불편한 별이나 별빛 한 줄을 신고하거나 그 별지기를 차단할 수 있습니다. 신고한 내용은 신고한 사람에게 바로 숨겨지며, 신고가 3건 쌓이면 운영자가 확인할 때까지 모두에게 숨겨집니다."),
            ("제8조 (코인과 결제)", "기록 작성과 별빛 없이 띄우기는 코인 없이 이용할 수 있습니다. 별빛 받기는 하루 1번 무료이며, 그 뒤에는 코인을 씁니다. 코인 충전, 환불, 사용 기준은 결제·환불 정책을 따릅니다."),
            ("제9조 (서비스의 변경과 중단)", "운영자는 점검, 장애, 운영상 필요에 따라 서비스의 일부 또는 전부를 바꾸거나 멈출 수 있으며, 미리 알릴 수 없는 경우가 아니면 앱 안에서 먼저 알립니다. 서비스를 종료할 때는 30일 전에 알리고, 그동안 이용자가 데이터를 내보낼 수 있게 합니다."),
            ("제10조 (이용 제한)", "이용자가 이 약관을 어기면 운영자는 해당 공유를 숨기거나 우주 광장 이용을 제한할 수 있습니다. 이 경우 이용자는 문의하기로 이의를 제기할 수 있습니다."),
            ("제11조 (준거법과 분쟁 해결)", "이 약관은 대한민국 법을 따릅니다. 서비스 이용으로 분쟁이 생기면 먼저 문의하기로 협의하며, 소송이 필요한 경우 민사소송법에 따른 관할 법원에서 다룹니다."),
        ]
        case .privacy: [
            // Figma 44 (18:872), 2026-11-10: no telescope.
            ("1. 수집하는 항목", "· 필수: Apple 또는 Google 계정의 고유 식별자(이름·이메일은 받지 않습니다), 별지기 이름 · 가입할 때\n· 필수: 쓴 글(제목·본문·임시 저장 글), 별빛 분석·별빛 풀이·별자리 이야기 · 기록하고 분석할 때\n· 필수: 코인 충전·사용 내역, 앱 스토어(App Store·Google Play) 거래 번호, 환불 정보 제공 동의 여부 · 결제할 때\n· 필수: 약관·민감정보 동의 일시, 설정값 · 이용하는 동안\n· 선택: 알림용 기기 토큰 · 알림을 허용할 때\n· 선택: 답장 받을 이메일, 문의 유형과 내용 · 문의할 때\n· 자동: 접속 IP(요청 제한용, 하루 안에 삭제), 글을 뺀 오류 기록 · 이용하는 동안"),
            ("2. 이용 목적", "• 별·별자리·별빛 풀이를 만들어 보여 주는 서비스 제공\n• 계정 식별과 로그인 유지\n• 코인 지급, 환불 요청 판단과 App Store에 대한 사용 내역 회신\n• 우주 광장의 신고·차단 처리와 남용 방지\n• 문의 응대와 공지 알림\n• 오류 확인과 서비스 안정성 개선\n\n글과 분석 결과는 광고나 AI 모델 학습에 사용하지 않습니다."),
            ("3. 보유 기간과 파기", "개인정보는 이용자가 계정을 영구 삭제할 때까지 보관하며, 삭제하면 바로 지웁니다. 장애 복구용 백업 사본은 14일이 지나면 지워집니다. 다만 코인 결제 기록(앱 스토어 거래 번호, 상품, 일시)은 「전자상거래 등에서의 소비자보호에 관한 법률」에 따라 계정과의 연결을 끊은 채 5년간 보관한 뒤 지웁니다. 전자적 파일은 복구할 수 없는 방법으로 지웁니다."),
            ("4. 처리 위탁과 국외 이전", "서비스 운영을 위해 아래 업체에 개인정보 처리를 맡기며, 서비스를 이용할 때 네트워크로 전송됩니다.\n· Google LLC (Gemini API): 별빛 받기를 위한 글 분석 · 미국\n· Vercel Inc.: 서버 운영 · 미국\n· Neon: 데이터베이스 보관(글과 분석은 암호화) · 미국 (AWS 오하이오)\n· Functional Software, Inc. (Sentry): 오류 기록 수집(글 제외) · 미국\n· Apple Inc.: Apple 로그인, App Store 결제, iPhone 알림 전송 · 미국\n· Google LLC: Google 로그인, Google Play 결제, Android 알림 전송(Firebase) · 미국\n\n국외 이전을 원하지 않으면 계정을 삭제해 거부할 수 있으나, 이 경우 서비스를 이용할 수 없습니다."),
            ("5. 제3자 제공", "개인정보를 제3자에게 제공하지 않습니다. 다만 법령에 근거가 있거나 수사기관이 법령에 정한 절차에 따라 요청하는 경우는 예외로 합니다."),
            ("6. 안전성 확보 조치", "• 글과 분석 결과, 문의 내용은 암호화해 저장합니다.\n• 운영자가 정보를 보거나 조치한 기록을 모두 남깁니다.\n• 오류 기록에는 글과 개인정보를 담지 않습니다.\n• 알림에는 글이나 분석 내용을 넣지 않습니다."),
            ("7. 이용자의 권리", "이용자는 언제든 자신의 개인정보를 열람·정정·삭제하거나 처리 정지를 요구할 수 있습니다.\n• 설정 › 데이터 내보내기: 모든 기록을 텍스트나 PDF로 받기\n• 별 상세 › 삭제: 별 하나씩 지우기\n• 설정 › 모든 공유 거두기: 우주 광장에서 내 별 내리기\n• 설정 › 계정 영구 삭제: 모든 데이터 지우기\n• 그 밖의 요청: 앱의 문의하기"),
            ("8. 개인정보 보호책임자", "개인정보 처리에 관한 문의와 불만은 아래로 연락해 주세요.\n· 개인정보 보호책임자: Kim Jin-hwan\n· 연락처: zhwan85@gmail.com · 앱의 문의하기\n\n개인정보 침해에 대한 상담이 필요하면 개인정보침해신고센터(118), 개인정보분쟁조정위원회(1833-6972), 대검찰청(1301), 경찰청(182)에 문의할 수 있습니다."),
            ("9. 처리방침의 변경", "이 방침을 바꿀 때는 시행 7일 전부터, 중요한 변경은 30일 전부터 앱과 웹사이트에 알립니다."),
        ]
        case .sensitive: [
            // Figma 45 (18:903), 2026-11-10: no telescope.
            ("1. 수집 항목", "이용자가 쓴 심리 일기(제목·본문·임시 저장 글)와 그로부터 만들어진 감정 분석 결과는 「개인정보 보호법」의 민감정보에 해당할 수 있습니다. 여기에는 별빛 프리즘의 별빛과 별빛 풀이, 별자리 이야기가 포함됩니다."),
            ("2. 이용 목적", "이용자 본인에게 별과 별자리, 별빛 풀이를 보여주는 용도로만 사용하며, 제3자에게 제공하지 않습니다. 광고나 AI 모델 학습에는 사용하지 않습니다."),
            ("3. 처리 방법", "• 글과 분석 결과는 암호화해 저장합니다.\n• 별빛 받기를 할 때만 글을 AI 분석 업체(Google Gemini API)에 보내 분석을 맡깁니다. 별빛 없이 띄운 글은 보내지 않습니다.\n• 위기 신호가 보이는 글은 분석하거나 공유하지 않습니다.\n• 우주 광장에 별을 나누면 이용자가 동의한 경우에 한해 대표 문장과 글 전체가 계정 이름과 점수 없이 보입니다. 글에 쓴 이름과 장소는 가려지지 않으니, 나누기 전에 미리 보기로 확인해 주세요. 연락처는 자동으로 가려집니다."),
            ("4. 보유 기간", "계정을 영구 삭제하거나 별을 지울 때까지 보관합니다. 삭제하면 바로 지워지며, 장애 복구용 백업 사본에서도 14일 안에 사라집니다."),
            ("5. 동의 거부 권리", "동의하지 않을 수 있으나, 이 경우 기록 기능을 이용할 수 없습니다. 동의 후에도 설정에서 계정을 삭제해 동의를 철회할 수 있습니다."),
        ]
        case .payment: [
            // Figma 46 (18:931), 2026-11-10: no telescope.
            ("1. 코인 상품", "· 코인 110: 110 코인 · 1,100원\n· 코인 330: 330 코인 · 3,300원\n· 코인 1,100: 1,000 코인 + 보너스 100 코인 · 9,900원\n\n1코인은 10원 가치이며, 가격은 부가가치세를 포함합니다."),
            ("2. 결제", "코인은 앱 스토어(App Store 또는 Google Play) 결제를 통해 충전되며 결제가 확인되면 즉시 지급됩니다. 같은 결제는 두 번 지급되지 않습니다."),
            ("3. 코인 사용", "· 별빛 받기: 하루 1번 무료 · 이후 5 코인\n· 기록 작성 · 별빛 없이 띄우기: 언제나 무료\n\n무료 횟수를 먼저 쓰고, 그 뒤에 코인을 씁니다. 하루 무료 별빛 받기는 다음 날로 넘어가지 않습니다."),
            ("4. 환불", "구매 후 7일 이내에 환불을 요청할 수 있습니다. 환불하면 그 결제로 받은 코인만큼 잔액에서 거두며, 거둔 뒤 잔액이 0보다 적어지는 경우(이미 코인을 사용한 경우)에는 환불되지 않습니다.\n\n환불은 결제한 곳에 따라 요청합니다.\n· App Store: Apple의 문제 신고하기에서 요청합니다. 충전할 때 동의한 경우, 환불을 요청하면 해당 결제의 코인 사용 내역이 Apple에 전달됩니다.\n· Google Play: 결제 후 48시간 안에는 Google Play의 주문 내역에서 요청할 수 있고, 그 뒤에는 앱의 문의하기에서 문의 유형을 결제로 골라 요청해 주세요. 운영자가 확인한 뒤 Google Play를 통해 환불합니다."),
            ("5. 환불된 결제", "그럼에도 App Store나 Google Play에서 결제가 환불되면 그 결제로 받은 코인을 거둡니다. 잔액이 부족하면 남아 있는 코인만 거두며, 코인 잔액은 0 아래로 내려가지 않습니다."),
            ("6. 분석 실패 시", "코인은 결과가 만들어진 뒤에만 차감됩니다. 분석에 실패하면 코인은 차감되지 않으며, 별은 별빛 없는 별로 남아 나중에 다시 띄울 수 있습니다."),
            ("7. 계정 삭제와 코인", "계정을 영구 삭제하면 남은 코인도 함께 사라지며 되살릴 수 없습니다. 삭제하기 전에 필요한 환불을 먼저 요청해 주세요. 결제 기록은 관련 법령에 따라 계정과의 연결을 끊은 채 5년간 보관됩니다."),
            ("8. 문의", "결제와 코인에 관한 문의는 앱의 문의하기에서 문의 유형을 결제로 골라 남겨 주세요."),
        ]
        // TODO: Final wording from legal review.
        case .marketing: [
            // Figma 299:13784, 2026-11-09.
            ("받는 소식", "새로 생긴 기능, 코인 충전 혜택과 이벤트 같은 광고성 정보를 앱 알림으로 보내 드립니다. 알림 제목 앞에는 (광고)를 붙입니다. 별 만들기 알림과 서비스 공지처럼 꼭 필요한 알림은 이 동의와 따로 관리되며, 기록을 재촉하거나 연속 기록을 요구하는 알림은 보내지 않습니다."),
            ("보내는 횟수와 시간", "한 달에 4번을 넘기지 않으며, 밤 9시부터 다음 날 아침 8시 사이에는 보내지 않습니다."),
            ("이용하는 정보", "알림을 보내기 위해 기기 알림 토큰, 동의 여부와 동의 일시만 사용합니다. 이용자가 쓴 글, 별빛과 별빛 풀이는 알림 대상을 고르는 데 쓰지 않습니다."),
            ("보관 기간", "동의를 철회하거나 계정을 삭제하면 바로 지웁니다."),
            ("동의 결과 안내", "동의하거나 철회하면 그 날짜와 결과를 앱 알림으로 알려 드립니다. 동의한 날부터 2년마다 계속 받으실지 다시 여쭤봅니다."),
            ("동의 거부와 철회", "선택 항목이라 동의하지 않아도 모든 기능을 그대로 쓸 수 있고, 불이익은 없습니다. 동의한 뒤에도 설정 › 알림에서 언제든 끌 수 있습니다."),
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
    /// 68-1: M1 after a locked sky's preview.
    @State private var showMembership = false
    /// v1.1: "아이콘도 바꿀까요?" once, when a member applies a sky.
    @State private var askIcon = false

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
                        // v1.0: only the free skies. v1.1 (68-1): the others follow,
                        // with a "멤버십" tag and a lock for non-members.
                        ForEach(model.membershipOn ? SkyTheme.free + SkyTheme.allCases.filter { !$0.isFree } : SkyTheme.free) { theme in
                            let locked = !theme.isFree && !model.isMember
                            SkyOptionRow(theme: theme, isSelected: theme == selected, locked: locked) {
                                if locked { preview(theme) } else {
                                    withAnimation(.snappy(duration: 0.2)) { selected = theme }
                                }
                            }
                        }
                    }

                }
                .padding(.horizontal, Space.xl)
                .padding(.top, Space.xl)
                .padding(.bottom, Space.lg)
            }
            .scrollIndicators(.hidden)

            // 68-1: fixed above the button so the scroll never hides it.
            if model.membershipOn && !model.isMember {
                HStack(alignment: .top, spacing: Space.md) {
                    Image(.iconInfo).renderingMode(.template).resizable().frame(width: 20, height: 20)
                        .foregroundStyle(Color.accentTint).accessibilityHidden(true)
                    Text("오로라 숲, 잔불 노을, 장미빛 새벽은 별지기 멤버십으로 열 수 있어요. 눌러서 미리 볼 수 있어요.")
                        .textStyle(.bodyS).foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.lg)
                .background(Color.bgSurfaceRaised, in: .rect(cornerRadius: Radius.lg))
                .padding(.horizontal, Space.xl)
                .padding(.bottom, Space.md)
            }
            Button("적용하기") {
                let changed = selected != model.settings.sky
                withAnimation(.easeInOut(duration: 0.5)) { model.settings.sky = selected }
                if changed && model.isMember && UIApplication.shared.supportsAlternateIcons
                    && UIApplication.shared.alternateIconName != selected.appIconName {
                    askIcon = true
                } else {
                    onBack()
                }
            }
            .alert("아이콘도 바꿀까요?", isPresented: $askIcon) {
                Button("바꾸기") {
                    Task { @MainActor in
                        try? await UIApplication.shared.setAlternateIconName(selected.appIconName)
                        onBack()
                    }
                }
                Button("그대로 두기", role: .cancel) { onBack() }
            } message: {
                Text("홈 화면의 YOUNIYA 아이콘을 \(selected.name) 색으로 바꿔요.")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background { StarField() }
        .onAppear { selected = model.settings.sky }
        .membershipSheet(isPresented: $showMembership)
    }

    /// 68-1: the whole app in that sky for 3 seconds, then M1.
    private func preview(_ theme: SkyTheme) {
        model.previewSky = theme
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            model.previewSky = nil
            showMembership = true
        }
    }
}

/// Figma `Theme / …` row: swatch, name and mood, radio.
private struct SkyOptionRow: View {
    var theme: SkyTheme
    var isSelected: Bool
    /// 68-1: a membership sky for a non-member.
    var locked = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                SkySwatch(theme: theme)
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        Text(theme.name)
                            .textStyle(.labelM)
                            .foregroundStyle(Color.textPrimary)
                        if locked { Tag(text: "멤버십", tone: .gold) }
                    }
                    Text(theme.detail)
                        .textStyle(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if locked {
                    Image(.iconLock).resizable().frame(width: 22, height: 22)
                        .accessibilityLabel("멤버십")
                } else {
                    // Figma `Radio`: 22pt, filled violet when selected.
                    ZStack {
                        Circle().strokeBorder(isSelected ? Color.brandPrimary : Color.borderDefault, lineWidth: 2)
                        if isSelected { Circle().fill(Color.brandPrimary) }
                    }
                    .frame(width: 22, height: 22)
                }
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
                        Text("우주 광장에 나눈 별 \(shared.count)개예요. 거두면 광장에서 바로 사라지고, 받은 공명과 별빛 한 줄은 그대로 간직돼요.")
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
