import SwiftUI

struct AlertSettingsView: View {
    @EnvironmentObject var appState: AppState

    private let presets: [(metres: Double, label: String)] = [
        (30,  "100 ft"),
        (76,  "250 ft"),
        (152, "500 ft"),
        (305, "1,000 ft"),
    ]

    private var distanceFeet: Int { Int(appState.alertRadiusMetres * 3.28084) }

    private var distanceLabel: String {
        let ft = distanceFeet
        if ft >= 5280 { return String(format: "%.1f mi", Double(ft) / 5280) }
        return "\(ft) ft"
    }

    var body: some View {
        ZStack {
            Color.flockBG.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Distance slider
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("ALERT DISTANCE")

                        VStack(spacing: 16) {
                            // Big distance readout
                            VStack(spacing: 4) {
                                Text(distanceLabel)
                                    .font(.system(size: 40, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.flockPrimary)
                                    .contentTransition(.numericText())
                                    .animation(.easeOut(duration: 0.1), value: distanceFeet)
                                Text("from camera")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.flockTextSub)
                                    .tracking(1)
                            }
                            .frame(maxWidth: .infinity)

                            Slider(
                                value: $appState.alertRadiusMetres,
                                in: 30...400,
                                step: 5
                            ) {
                                Text("Distance")
                            } minimumValueLabel: {
                                Text("100 ft").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.flockTextSub)
                            } maximumValueLabel: {
                                Text("1,300 ft").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.flockTextSub)
                            }
                            .tint(Color.flockPrimary)
                            .onChange(of: appState.alertRadiusMetres) { _, _ in
                                HapticManager.selection()
                            }

                            // Quick-pick presets
                            HStack(spacing: 8) {
                                ForEach(presets, id: \.metres) { preset in
                                    let isActive = abs(appState.alertRadiusMetres - preset.metres) < 3
                                    Button {
                                        withAnimation { appState.alertRadiusMetres = preset.metres }
                                        HapticManager.selection()
                                    } label: {
                                        Text(preset.label)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(isActive ? Color.flockBG : Color.flockTextSub)
                                            .padding(.vertical, 7)
                                            .frame(maxWidth: .infinity)
                                            .background(isActive ? Color.flockPrimary : Color.flockSurface)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.easeInOut(duration: 0.15), value: isActive)
                                }
                            }
                        }
                        .padding(18)
                        .background(Color.flockSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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
