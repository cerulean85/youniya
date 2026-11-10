import AuthenticationServices
import UIKit

/// 02 "Apple로 계속하기": asks for an Apple ID credential and returns its
/// identity token (a JWT) for `POST /v1/auth/apple`. No name or email is
/// requested; the server only needs the stable `sub`.
@MainActor
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<String, Error>?
    /// 91 계정 영구 삭제: return the one-time authorization code instead of the identity token.
    private var wantsCode = false

    /// Thrown when the user closes the sheet; nothing to show.
    struct Cancelled: Error {}

    /// 91: the authorization code the server trades for a token to revoke (5.1.1(v)).
    func authorizationCode() async throws -> String {
        wantsCode = true
        return try await identityToken()
    }

    func identityToken() async throws -> String {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { c in
            continuation = c
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let idToken = credential?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let code = credential?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            if let token = wantsCode ? code : idToken {
                continuation?.resume(returning: token)
            } else {
                continuation?.resume(throwing: APIError(status: 0, code: "invalid_id_token",
                                                        message: "로그인 정보를 확인하지 못했어요."))
            }
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor in
            continuation?.resume(throwing: cancelled ? Cancelled() : APIError(
                status: 0, code: "apple_sign_in_failed", message: "Apple 로그인을 마치지 못했어요. 다시 시도해 주세요."))
            continuation = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first ?? ASPresentationAnchor()
        }
    }
}
