import Foundation
import AuthenticationServices
import UIKit

struct AppleSignInResult: Sendable, Equatable {
    let user: String
    let email: String?
    let fullName: PersonNameComponents?

    static func == (lhs: AppleSignInResult, rhs: AppleSignInResult) -> Bool {
        lhs.user == rhs.user && lhs.email == rhs.email && lhs.fullName == rhs.fullName
    }
}

enum AppleSignInError: Error, Equatable, Sendable {
    case cancelled
    case failed
    case missingEntitlement
    case unknown
}

protocol AppleSignInRequesting: Sendable {
    func signIn() async throws -> AppleSignInResult
}

/// Drives the Sign In with Apple flow via AuthenticationServices.
/// Requires the "Sign in with Apple" capability + entitlement to be enabled on the app
/// target. Without it, `performRequests()` fails at runtime with `ASAuthorizationError`.
@MainActor
final class AppleSignInCoordinator: NSObject, AppleSignInRequesting {

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var controller: ASAuthorizationController?

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { cont in
            guard self.continuation == nil else {
                cont.resume(throwing: AppleSignInError.failed)
                return
            }
            self.continuation = cont

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(returning result: AppleSignInResult) {
        continuation?.resume(returning: result)
        continuation = nil
        controller = nil
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        controller = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.finish(throwing: AppleSignInError.unknown)
                return
            }
            let result = AppleSignInResult(
                user: credential.user,
                email: credential.email,
                fullName: credential.fullName
            )
            self.finish(returning: result)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let mapped: AppleSignInError
            if let asError = error as? ASAuthorizationError {
                switch asError.code {
                case .canceled:
                    mapped = .cancelled
                case .unknown:
                    mapped = .unknown
                default:
                    mapped = .failed
                }
            } else if (error as NSError).code == -7026 {
                mapped = .missingEntitlement
            } else {
                mapped = .failed
            }
            self.finish(throwing: mapped)
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? UIWindow()
        }
    }
}
