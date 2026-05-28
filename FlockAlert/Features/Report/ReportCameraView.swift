import SwiftUI
import CoreLocation
import PhotosUI
import SwiftData

struct ReportCameraView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var reportType: CameraReport.ReportType = .newCamera
    @State private var ownerType: OwnerType = .unknown
    @State private var ownerName = ""
    @State private var mountType: MountType = .utilityPole
    @State private var facingDirection: Double = 0
    @State private var hasFacing = false
    @State private var notes = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var locationPinned = false
    @State private var pinnedCoord: CLLocationCoordinate2D?
    @State private var showConfirmation = false
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // ── Header callout ──────────────────────────
                        GlassCard {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.badge.plus")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.flockPrimary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Report a Camera")
                                        .font(.flockHeadline)
                                        .foregroundStyle(Color.flockText)
                                    Text("Community reports are reviewed before going live.")
                                        .font(.flockCaption)
                                        .foregroundStyle(Color.flockTextSub)
                                }
                            }
                            .padding(16)
                        }

                        // ── Report Type ──────────────────────────────
                        FormSection(title: "REPORT TYPE") {
                            Picker("Type", selection: $reportType) {
                                ForEach(CameraReport.ReportType.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // ── Location ──────────────────────────────────
                        FormSection(title: "LOCATION") {
                            if let coord = pinnedCoord ?? appState.userLocation?.coordinate {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(Color.flockSafe)
                                    Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color.flockText)
                                    Spacer()
                                    Button("Use Current") {
                                        pinnedCoord = appState.userLocation?.coordinate
                                        HapticManager.impact(.medium)
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.flockPrimary)
                                }
                                .padding(12)
                                .background(Color.flockSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Text("Enable location to auto-fill coordinates")
                                    .font(.flockCaption)
                                    .foregroundStyle(Color.flockTextSub)
                                    .padding(12)
                            }
                        }

                        // ── Camera Details ──────────────────────────────
                        FormSection(title: "CAMERA DETAILS") {
                            VStack(spacing: 10) {
                                // Owner type
                                Picker("Owner Type", selection: $ownerType) {
                                    ForEach(OwnerType.allCases, id: \.self) {
                                        Text($0.rawValue).tag($0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.flockPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.flockSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                // Owner name
                                TextField("Owner name (optional)", text: $ownerName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.flockText)
                                    .padding(12)
                                    .background(Color.flockSurface2)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                // Mount type
                                Picker("Mount Type", selection: $mountType) {
                                    ForEach(MountType.allCases, id: \.self) {
                                        Text($0.rawValue).tag($0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.flockPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.flockSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        // ── Facing Direction ──────────────────────────────
                        FormSection(title: "FACING DIRECTION (OPTIONAL)") {
                            VStack(spacing: 10) {
                                Toggle("I know which way it faces", isOn: $hasFacing)
                                    .tint(Color.flockPrimary)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.flockText)

                                if hasFacing {
                                    VStack(spacing: 6) {
                                        HStack {
                                            Text("Direction:")
                                                .font(.flockCaption)
                                                .foregroundStyle(Color.flockTextSub)
                                            Spacer()
                                            Text("\(Int(facingDirection))° \(bearingLabel(facingDirection))")
                                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(Color.flockPrimary)
                                        }
                                        Slider(value: $facingDirection, in: 0...359, step: 1)
                                            .tint(Color.flockPrimary)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // ── Photo ──────────────────────────────────────
                        FormSection(title: "PHOTO EVIDENCE") {
                            VStack(spacing: 10) {
                                PhotosPicker(
                                    selection: $selectedPhotos,
                                    maxSelectionCount: 3,
                                    matching: .images
                                ) {
                                    Label("Add Photos (up to 3)", systemImage: "photo.badge.plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.flockPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(12)
                                        .background(Color.flockPrimary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .onChange(of: selectedPhotos) { _, items in
                                    loadPhotos(items)
                                }

                                if !photoData.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(photoData.indices, id: \.self) { i in
                                                if let img = UIImage(data: photoData[i]) {
                                                    Image(uiImage: img)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 80, height: 80)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                            }
                                        }
                                    }
                                }

                                Text("Photos help moderators verify camera location and type.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.flockTextSub)
                            }
                        }

                        // ── Notes ──────────────────────────────────────
                        FormSection(title: "NOTES (OPTIONAL)") {
                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.flockText)
                                .scrollContentBackground(.hidden)
                                .background(Color.flockSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(4)
                        }

                        // ── Disclaimer ──────────────────────────────────
                        Text("By submitting, you confirm this information is from your own observation in a public space. Do not include private property or personal information.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.flockTextSub)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // ── Submit ──────────────────────────────────────
                        Button(action: submit) {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                }
                                Text(isSubmitting ? "Submitting..." : "Submit Report")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(canSubmit ? Color.flockPrimary : Color.flockSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSubmit || isSubmitting)
                        .animation(.easeInOut(duration: 0.2), value: canSubmit)

                        Spacer(minLength: 100)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Report Camera")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Report Submitted", isPresented: $showConfirmation) {
                Button("OK", role: .cancel) { resetForm() }
            } message: {
                Text("Thank you! Your report will be reviewed by our moderation team.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSubmit: Bool {
        (pinnedCoord ?? appState.userLocation?.coordinate) != nil
    }

    private func submit() {
        guard let coord = pinnedCoord ?? appState.userLocation?.coordinate else { return }
        isSubmitting = true
        HapticManager.impact(.medium)

        let report = CameraReport(
            latitude: coord.latitude,
            longitude: coord.longitude,
            reportType: reportType,
            ownerType: ownerType,
            ownerName: ownerName.isEmpty ? nil : ownerName,
            mountType: mountType,
            facingDirection: hasFacing ? facingDirection : nil,
            notes: notes.isEmpty ? nil : notes,
            photoData: photoData
        )
        modelContext.insert(report)
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            showConfirmation = true
        }
    }

    private func resetForm() {
        reportType = .newCamera
        ownerType = .unknown
        ownerName = ""
        mountType = .utilityPole
        hasFacing = false
        notes = ""
        selectedPhotos = []
        photoData = []
        pinnedCoord = nil
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        photoData = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let d = data {
                    DispatchQueue.main.async { self.photoData.append(d) }
                }
            }
        }
    }

    private func bearingLabel(_ deg: Double) -> String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        return dirs[Int((deg + 11.25).truncatingRemainder(dividingBy: 360) / 22.5) % 16]
    }
}

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.flockTextSub)
                .tracking(1.5)
            content
        }
    }
}
