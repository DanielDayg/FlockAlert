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

    func handleSignIn(result: Result<ASAuthorization, Error>) {
        guard case .success(let auth) = result,
              let cred = auth.credential as? ASAuthorizationAppleIDCredential,
              let context = modelContext
        else { return }

        let userID = cred.user
        let name = [cred.fullName?.givenName, cred.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        let displayName = name.isEmpty ? "FlockAlert User" : name
        let email = cred.email

        // Check if profile already exists
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
