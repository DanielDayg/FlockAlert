import AuthenticationServices
import SwiftData
import SwiftUI

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var currentProfile: UserProfile?

    private var modelContext: ModelContext?

    static let shared = AuthManager()

    func configure(context: ModelContext) {
        self.modelContext = context
        checkExistingSession()
    }

    private func checkExistingSession() {
        guard let savedID = UserDefaults.standard.string(forKey: "appleUserID"),
              let context = modelContext
        else { return }

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserID == savedID }
        )
        if let profile = try? context.fetch(descriptor).first {
            currentProfile = profile
            isSignedIn = true
        }
    }

    // MARK: - Sign In

    func signIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            print("Sign in with Apple failed: \(error)")
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let context = modelContext
            else { return }

            let userID = cred.user
            let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let displayName = name.isEmpty ? "FlockAlert User" : name
            let email = cred.email

            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.appleUserID == userID }
            )
            if let existing = try? context.fetch(descriptor).first {
                currentProfile = existing
            } else {
                let profile = UserProfile(appleUserID: userID, displayName: displayName, email: email)
                context.insert(profile)
                try? context.save()
                currentProfile = profile
            }

            UserDefaults.standard.set(userID, forKey: "appleUserID")
            isSignedIn = true

            // Link RevenueCat customer to Apple user ID
            Task { await SubscriptionManager.shared.loginRevenueCat(appleUserID: userID) }
        }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        currentProfile = nil
        isSignedIn = false
    }

    func awardPoints(_ amount: Int, context: ModelContext) {
        guard let profile = currentProfile else { return }
        profile.points += amount
        try? context.save()
    }

    func recordReport(context: ModelContext) {
        guard let profile = currentProfile else { return }
        profile.camerasReported += 1
        profile.points += 10
        try? context.save()
    }

    func recordVerification(photoData: Data?, context: ModelContext) {
        guard let profile = currentProfile else { return }
        let pts = photoData != nil ? 25 : 10
        profile.photosUploaded += 1
        profile.points += pts
        try? context.save()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            self.handleSignIn(result: .success(authorization))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        print("Sign in with Apple error: \(error)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // ASAuthorizationController may call this on the main thread in iOS 26+.
        // DispatchQueue.main.sync from the main thread causes a deadlock, so we
        // check Thread.isMainThread and only sync-dispatch when we're off it.
        let findKeyWindow = {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
        if Thread.isMainThread {
            return findKeyWindow()
        } else {
            return DispatchQueue.main.sync { findKeyWindow() }
        }
    }
}
