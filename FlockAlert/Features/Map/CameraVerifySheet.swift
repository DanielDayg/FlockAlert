import SwiftUI
import SwiftData
import PhotosUI

struct CameraVerifySheet: View {
    let camera: Camera
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var pointsEarned = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                if !authManager.isSignedIn {
                    notSignedInView
                } else if submitted {
                    successView
                } else {
                    formView
                }
            }
            .navigationTitle("Verify Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.flockTextSub)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Camera info header
                GlassCard(cornerRadius: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.flockPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(camera.cameraModel ?? "Flock Safety Camera")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.flockText)
                            if !camera.locationLabel.isEmpty {
                                Text(camera.locationLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.flockTextSub)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                }

                // Points info
                GlassCard(cornerRadius: 16) {
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text("+10")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.flockPrimary)
                            Text("text only")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.flockTextSub)
                        }
                        .frame(maxWidth: .infinity)

                        Divider().frame(height: 40).background(Color.white.opacity(0.1))

                        VStack(spacing: 4) {
                            Text("+25")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.flockSafe)
                            Text("with photo")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.flockTextSub)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                }

                // Photo picker
                GlassCard(cornerRadius: 16) {
                    VStack(spacing: 12) {
                        Text("ATTACH PHOTO")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                            .tracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.flockSafe.opacity(0.4), lineWidth: 1)
                                )
                        }

                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack {
                                Image(systemName: selectedImageData != nil ? "photo.fill" : "photo.badge.plus")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(selectedImageData != nil ? "Change Photo" : "Select Photo")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color.flockPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.flockPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    }
                    .padding(16)
                }

                // Notes field
                GlassCard(cornerRadius: 16) {
                    VStack(spacing: 10) {
                        Text("NOTES (OPTIONAL)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.flockTextSub)
                            .tracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("e.g. Camera confirmed active, mounted on pole...", text: $note, axis: .vertical)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.flockText)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(Color.flockSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(16)
                }

                // Submit button
                Button {
                    submitVerification()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Submit Verification")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.flockPrimary, Color.flockSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSubmitting)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.flockSafe.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.flockSafe)
            }

            VStack(spacing: 10) {
                Text("Verification Submitted!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.flockText)

                Text("You earned \(pointsEarned) points")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.flockSafe)

                Text("Thank you for helping the community\ndocument surveillance cameras.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.flockSafe)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Not Signed In

    private var notSignedInView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(Color.flockPrimary.opacity(0.7))

            VStack(spacing: 8) {
                Text("Sign In Required")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.flockText)
                Text("You need to sign in to verify\ncameras and earn points.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
            }

            Button("Dismiss") { dismiss() }
                .foregroundStyle(Color.flockPrimary)
                .font(.system(size: 15, weight: .semibold))

            Spacer()
        }
    }

    // MARK: - Submit

    private func submitVerification() {
        guard let profile = authManager.currentProfile else { return }
        isSubmitting = true
        pointsEarned = selectedImageData != nil ? 25 : 10

        let verification = CameraVerification(
            cameraID: camera.id,
            userAppleID: profile.appleUserID,
            userName: profile.displayName,
            photoData: selectedImageData,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(verification)
        try? modelContext.save()

        authManager.recordVerification(photoData: selectedImageData, context: modelContext)

        ReportNotificationService.shared.notifyCameraVerification(
            cameraID: camera.id.uuidString,
            userName: profile.displayName,
            hasPhoto: selectedImageData != nil,
            note: note.isEmpty ? nil : note
        )

        HapticManager.notification(.success)

        withAnimation {
            isSubmitting = false
            submitted = true
        }
    }
}
