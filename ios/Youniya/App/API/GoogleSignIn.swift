import AuthenticationServices
import CryptoKit
import UIKit

/// 02 "Google로 계속하기": Google's OAuth sign-in in the system web sheet
/// (authorization code + PKCE, no client secret, as for an iOS-type client),
/// returning the ID token for `POST /v1/auth/google`. Only `openid` is asked:
/// the server needs the stable `sub`, not a name or email.
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// The iOS OAuth client (Google Cloud Console, bundle id com.dycdyp.youniya).
    /// The server lists the same id in GOOGLE_CLIENT_IDS. A client id is public.
    static let clientID = "226582034976-8joj5khaeknijgaflnj837q0nkj9ajvj.apps.googleusercontent.com"
    /// Google's redirect for iOS clients: the reversed client id.
    private static let scheme = "com.googleusercontent.apps.226582034976-8joj5khaeknijgaflnj837q0nkj9ajvj"
    private static var redirectURI: String { scheme + ":/oauthredirect" }

    /// Thrown when the user closes the sheet; nothing to show.
    struct Cancelled: Error {}

    private var session: ASWebAuthenticationSession?

    func idToken() async throws -> String {
        let verifier = Self.randomURLSafe(32)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomURLSafe(16)

        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        auth.queryItems = [
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "prompt", value: "select_account"),
        ]

        let callback: URL = try await withCheckedThrowingContinuation { c in
            let s = ASWebAuthenticationSession(url: auth.url!, callbackURLScheme: Self.scheme) { url, error in
                if let url {
                    c.resume(returning: url)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    c.resume(throwing: Cancelled())
                } else {
                    c.resume(throwing: Self.failed)
                }
            }
            s.presentationContextProvider = self
            // A fresh sign-in each time, no shared Safari cookies.
            s.prefersEphemeralWebBrowserSession = true
            session = s
            if !s.start() { c.resume(throwing: Self.failed) }
        }
        session = nil

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if items.first(where: { $0.name == "error" })?.value == "access_denied" { throw Cancelled() }
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else { throw Self.failed }
        return try await Self.exchange(code: code, verifier: verifier)
    }

    /// Code → tokens at Google's token endpoint; only the ID token is kept.
    private static func exchange(code: String, verifier: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "code", value: code),
            .init(name: "code_verifier", value: verifier),
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "redirect_uri", value: redirectURI),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        struct Tokens: Decodable { var id_token: String? }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let token = try? JSONDecoder().decode(Tokens.self, from: data).id_token else { throw failed }
        return token
    }

    private static let failed = APIError(status: 0, code: "google_sign_in_failed",
                                         message: "Google 로그인을 마치지 못했어요. 다시 시도해 주세요.")

    private static func randomURLSafe(_ bytes: Int) -> String {
        var b = [UInt8](repeating: 0, count: bytes)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes, &b)
        return base64URL(Data(b))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }
}
