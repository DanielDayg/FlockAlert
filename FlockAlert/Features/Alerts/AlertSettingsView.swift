import SwiftUI

struct AlertSettingsView: View {
    @EnvironmentObject var appState: AppState

    private let distances: [(metres: Double, label: String, sub: String)] = [
        (30,   "100 ft",   "Steps away"),
        (76,   "250 ft",   "Half a block"),
        (152,  "500 ft",   "Recommended"),
        (305,  "1,000 ft", "~10 seconds driving")
    ]

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Distance picker
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("ALERT DISTANCE")

                        VStack(spacing: 8) {
                            ForEach(distances, id: \.metres) { option in
                                DistanceRow(
                                    label: option.label,
                                    sub: option.sub,
                                    isSelected: appState.alertRadiusMetres == option.metres
                                ) {
                                    appState.alertRadiusMetres = option.metres
                                    HapticManager.selection()
                                }
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Alert mode
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("NOTIFICATION STYLE")

                        VStack(spacing: 8) {
                            ForEach(AlertMode.allCases, id: \.self) { mode in
                                ModeRow(
                                    mode: mode,
                                    isSelected: appState.alertMode == mode
                                ) {
                                    appState.alertMode = mode
                                    HapticManager.selection()
                                }
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Extras
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("ADDITIONAL OPTIONS")

                        SettingsToggle(
                            icon: "speaker.wave.2.fill",
                            title: "Voice Alerts",
                            subtitle: "Speak camera warnings while driving",
                            color: .flockPrimary,
                            isOn: $appState.voiceEnabled
                        )

                        SettingsToggle(
                            icon: "map.fill",
                            title: "Heatmap Overlay",
                            subtitle: "Show surveillance density on map",
                            color: .flockCaution,
                            isOn: $appState.showHeatmap
                        )
                    }

                    // Legal note
                    Text("Flock Alert alerts are for transparency awareness only. This app does not interfere with surveillance systems or encourage illegal activity.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.flockTextSub.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .navigationTitle("Alert Settings")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

struct DistanceRow: View {
    let label: String
    let sub: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.flockPrimary : Color.flockSurface2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.flockBG)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.flockText)
                    Text(sub)
                        .font(.flockCaption)
                        .foregroundStyle(Color.flockTextSub)
                }

                Spacer()
            }
            .padding(14)
            .background(isSelected ? Color.flockPrimary.opacity(0.1) : Color.flockSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.flockPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct ModeRow: View {
    let mode: AlertMode
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch mode {
        case .banner: return "bell.badge.fill"
        case .silent: return "bell.slash.fill"
        case .hapticOnly: return "hand.tap.fill"
        case .voice: return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.flockPrimary : Color.flockTextSub)
                    .frame(width: 24)

                Text(mode.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.flockText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.flockPrimary)
                }
            }
            .padding(14)
            .background(isSelected ? Color.flockPrimary.opacity(0.08) : Color.flockSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

struct SettingsToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.flockText)
                Text(subtitle)
                    .font(.flockCaption)
                    .foregroundStyle(Color.flockTextSub)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(color)
                .labelsHidden()
        }
        .padding(14)
        .background(Color.flockSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
