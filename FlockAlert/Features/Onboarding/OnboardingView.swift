import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0
    @State private var animate = false
    @State private var username = ""
    // Shared location manager so the footer Continue can trigger permission on page 2
    @StateObject private var locMgr = LocationManager()

    private let totalPages = 5

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            // Subtle background grid
            GridBackground()
                .ignoresSafeArea()
                .opacity(0.3)

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $page) {
                    WelcomePage().tag(0)
                    HowItWorksPage().tag(1)
                    LocationPage(locMgr: locMgr).tag(2)
                    DisclaimerPage().tag(3)
                    UsernamePage(username: $username).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Navigation footer
                VStack(spacing: 20) {
                    // Page indicators
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages) { i in
                            Capsule()
                                .fill(i == page ? Color.flockPrimary : Color.flockTextSub.opacity(0.3))
                                .frame(width: i == page ? 24 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: page)
                        }
                    }

                    // CTA Button
                    Button(action: nextPage) {
                        HStack(spacing: 8) {
                            Text(page < totalPages - 1 ? "Continue" : "Get Started")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: page < totalPages - 1 ? "arrow.right" : "checkmark")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(Color.flockBG)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [Color.flockPrimary, Color(hex: "0099CC")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.flockPrimary.opacity(0.3), radius: 15, y: 5)
                    }
                    // Skip button removed — Apple guideline 5.1.1(iv) requires the user
                    // to always proceed to the location permission request.
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func nextPage() {
        // On the location page, trigger the system permission dialog before advancing.
        // This satisfies guideline 5.1.1(iv): the user must always reach the permission request.
        if page == 2 {
            locMgr.requestAlwaysAuthorization()
            HapticManager.impact(.medium)
        }
        if page < totalPages - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: "pendingUsername")
        }
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        onComplete()
    }
}

// MARK: - Pages

struct WelcomePage: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.flockPrimary.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .scaleEffect(animate ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animate)

                Circle()
                    .fill(Color.flockPrimary.opacity(0.12))
                    .frame(width: 130, height: 130)

                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(Color.flockPrimary)
            }
            .onAppear { animate = true }

            VStack(spacing: 12) {
                Text("FLOCK ALERT")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.flockPrimary)
                    .tracking(4)

                Text("Public Surveillance\nTransparency")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color.flockText)
                    .multilineTextAlignment(.center)

                Text("Know where automated surveillance cameras are in your community — before you drive past them.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("How It Works")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.flockText)

            VStack(spacing: 16) {
                FeatureRow(
                    icon: "map.fill",
                    color: .flockPrimary,
                    title: "Live Map",
                    description: "See thousands of documented Flock Safety cameras across the US."
                )
                FeatureRow(
                    icon: "bell.badge.fill",
                    color: .flockCaution,
                    title: "Proximity Alerts",
                    description: "Get notified as you approach cameras while driving or walking."
                )
                FeatureRow(
                    icon: "camera.fill",
                    color: .flockSafe,
                    title: "Community Reports",
                    description: "Help keep the map current by reporting new or removed cameras."
                )
                FeatureRow(
                    icon: "book.fill",
                    color: .skyBlue,
                    title: "Privacy Education",
                    description: "Understand your rights and what ALPR systems mean for civil liberties."
                )
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct LocationPage: View {
    // Receives the shared LocationManager from OnboardingView so permission
    // can also be triggered by the footer Continue button.
    @ObservedObject var locMgr: LocationManager

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: locMgr.isAuthorized ? "location.fill" : "location.slash")
                .font(.system(size: 64))
                .foregroundStyle(locMgr.isAuthorized ? Color.flockSafe : Color.flockPrimary)

            VStack(spacing: 12) {
                Text("Location Access")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.flockText)

                Text("Flock Alert needs \"Always\" location access to alert you as you approach cameras — even when the app is in the background.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 10) {
                PrivacyNote(icon: "iphone", text: "Location is processed on-device only")
                PrivacyNote(icon: "server.rack", text: "Your location is never sent to our servers")
                PrivacyNote(icon: "eye.slash", text: "No location history is stored anywhere")
            }

            if !locMgr.isAuthorized {
                // Button label is "Continue" per Apple guideline 5.1.1(iv) —
                // "Enable" is not permitted on pre-permission prompts.
                Button("Continue") {
                    locMgr.requestAlwaysAuthorization()
                    HapticManager.impact(.medium)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.flockBG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.flockPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Label("Location Enabled", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.flockSafe)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

struct DisclaimerPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.flockPrimary)

            Text("A Quick Note")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.flockText)

            VStack(spacing: 10) {
                DisclaimerRow(icon: "xmark.circle.fill", color: .flockAlert, text: "Not a law enforcement evasion tool")
                DisclaimerRow(icon: "xmark.circle.fill", color: .flockAlert, text: "Not anti-police advocacy")
                DisclaimerRow(icon: "xmark.circle.fill", color: .flockAlert, text: "Not for illegal activity of any kind")
                DisclaimerRow(icon: "checkmark.circle.fill", color: .flockSafe, text: "Public transparency and awareness")
                DisclaimerRow(icon: "checkmark.circle.fill", color: .flockSafe, text: "Civil liberties education")
                DisclaimerRow(icon: "checkmark.circle.fill", color: .flockSafe, text: "Open-source public data only")
            }

            Text("By continuing, you agree to use this app for lawful transparency purposes only.")
                .font(.system(size: 12))
                .foregroundStyle(Color.flockTextSub)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Onboarding Components

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.flockText)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.flockTextSub)
                    .lineSpacing(2)
            }
        }
    }
}

struct PrivacyNote: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.flockPrimary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.flockTextSub)
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

struct DisclaimerRow: View {
    let icon: String
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.flockText)
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for col in 0...cols {
                for row in 0...rows {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(Color.flockPrimary.opacity(0.15))
                    )
                }
            }
        }
    }
}

// MARK: - Username Page

struct UsernamePage: View {
    @Binding var username: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "person.text.rectangle.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color.flockPrimary)

            VStack(spacing: 12) {
                Text("Pick Your Handle")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.flockText)

                Text("This is how you appear on The Watchlist.\nYou can always change it later in your profile.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.flockTextSub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 8) {
                TextField("e.g. NightOwl_ATL", text: $username)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.flockText)
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .background(Color.flockSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(username.isEmpty ? Color.white.opacity(0.08) : Color.flockPrimary.opacity(0.4), lineWidth: 1)
                    )

                Text(username.isEmpty ? "Skip to use a default name" : "\(username.trimmingCharacters(in: .whitespacesAndNewlines).count)/24 characters")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.flockTextSub.opacity(0.5))
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
