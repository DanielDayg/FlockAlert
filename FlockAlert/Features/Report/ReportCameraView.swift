import SwiftUI
import CoreLocation
import PhotosUI
import MapKit
import SwiftData

// MARK: - Main Report View

struct ReportCameraView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    // Location
    @State private var pinnedCoord: CLLocationCoordinate2D?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    @State private var locationSnapped = false
    @State private var showMapPicker = false
    @State private var locationError: String?
    @State private var isGettingLocation = false

    // Details
    @State private var selectedOwner: OwnerType = .unknown
    @State private var notes = ""

    // Photo
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []

    // Submit
    @State private var isSubmitting = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Section 1: Location ──────────────────────────
                        ReportSectionCard(
                            number: "1",
                            title: "Where is the camera?",
                            icon: "mappin.circle.fill",
                            isComplete: pinnedCoord != nil
                        ) {
                            VStack(spacing: 12) {
                                // Use current location button
                                Button {
                                    snapToCurrentLocation()
                                } label: {
                                    HStack(spacing: 10) {
                                        if isGettingLocation {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(Color.flockPrimary)
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: locationSnapped ? "checkmark.circle.fill" : "location.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(locationSnapped ? Color.flockSafe : Color.flockPrimary)
                                        }
                                        Text(isGettingLocation ? "Getting your location..." :
                                             locationSnapped ? "Using your current location" : "Use My Current Location")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(locationSnapped ? Color.flockSafe : Color.flockPrimary)
                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(
                                        locationSnapped
                                            ? Color.flockSafe.opacity(0.12)
                                            : Color.flockPrimary.opacity(0.12)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isGettingLocation || locationSnapped)

                                if let err = locationError {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(Color.flockCaution)
                                            .font(.system(size: 12))
                                        Text(err)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.flockCaution)
                                        Spacer()
                                        Button("Open Settings") {
                                            appState.locationManager.openSettings()
                                        }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.flockPrimary)
                                    }
                                    .padding(.horizontal, 4)
                                }

                                // Divider with OR
                                HStack(spacing: 10) {
                                    Rectangle().fill(Color.flockSurface2).frame(height: 1)
                                    Text("OR")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.flockTextSub)
                                    Rectangle().fill(Color.flockSurface2).frame(height: 1)
                                }

                                // Pin on map button
                                Button {
                                    showMapPicker = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color.flockTextSub)
                                        Text(pinnedCoord != nil && !locationSnapped
                                             ? "Location pinned on map ✓"
                                             : "Drop a Pin on the Map")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(
                                                pinnedCoord != nil && !locationSnapped
                                                    ? Color.flockSafe
                                                    : Color.flockTextSub
                                            )
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.flockTextSub)
                                    }
                                    .padding(14)
                                    .background(Color.flockSurface2)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                // Mini map preview when location is set
                                if let coord = pinnedCoord {
                                    MiniMapPreview(coordinate: coord)
                                        .frame(height: 130)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .onTapGesture { showMapPicker = true }
                                }
                            }
                        }

                        // ── Section 2: Quick Details ─────────────────────
                        ReportSectionCard(
                            number: "2",
                            title: "Who owns it?",
                            icon: "building.2.fill",
                            isComplete: false,
                            isOptional: true
                        ) {
                            OwnerTypeGrid(selected: $selectedOwner)
                        }

                        // ── Section 3: Photo ─────────────────────────────
                        ReportSectionCard(
                            number: "3",
                            title: "Add a photo",
                            icon: "camera.fill",
                            isComplete: !photoImages.isEmpty,
                            isOptional: true
                        ) {
                            VStack(spacing: 10) {
                                PhotosPicker(
                                    selection: $selectedPhotos,
                                    maxSelectionCount: 3,
                                    matching: .images
                                ) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 20))
                                        Text(photoImages.isEmpty ? "Take or Choose Photo" : "\(photoImages.count) photo\(photoImages.count > 1 ? "s" : "") added")
                                            .font(.system(size: 15, weight: .semibold))
                                        Spacer()
                                        if !photoImages.isEmpty {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.flockSafe)
                                        }
                                    }
                                    .foregroundStyle(photoImages.isEmpty ? Color.flockPrimary : Color.flockSafe)
                                    .padding(14)
                                    .background(
                                        photoImages.isEmpty
                                            ? Color.flockPrimary.opacity(0.10)
                                            : Color.flockSafe.opacity(0.10)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .onChange(of: selectedPhotos) { _, items in loadPhotos(items) }

                                if !photoImages.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(photoImages.indices, id: \.self) { i in
                                                ZStack(alignment: .topTrailing) {
                                                    Image(uiImage: photoImages[i])
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 90, height: 90)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    Button {
                                                        photoImages.remove(at: i)
                                                        selectedPhotos.remove(at: i)
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundStyle(.white)
                                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                                    }
                                                    .padding(4)
                                                }
                                            }
                                        }
                                    }
                                }

                                Text("Helps moderators verify the camera location")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.flockTextSub)
                            }
                        }

                        // ── Notes (optional, inline) ─────────────────────
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.flockTextSub)
                                    Text("NOTES (OPTIONAL)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.flockTextSub)
                                        .tracking(1.5)
                                }
                                TextField("Anything else to add? e.g. \"faces traffic, active at night\"", text: $notes, axis: .vertical)
                                    .lineLimit(3...5)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.flockText)
                            }
                            .padding(14)
                        }

                        // ── Submit ──────────────────────────────────────
                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if isSubmitting {
                                    ProgressView().progressViewStyle(.circular).tint(.white)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 20))
                                }
                                Text(isSubmitting ? "Submitting..." : "Submit Report")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                pinnedCoord != nil
                                    ? Color.flockPrimary
                                    : Color.flockSurface2
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(pinnedCoord == nil || isSubmitting)
                        .animation(.spring(duration: 0.3), value: pinnedCoord != nil)

                        if pinnedCoord == nil {
                            Text("Add a location to submit")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.flockTextSub)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Report Camera")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showMapPicker) {
                MapPinPickerView(coordinate: $pinnedCoord, initialRegion: mapRegion)
                    .onDisappear {
                        if pinnedCoord != nil { locationSnapped = false }
                    }
            }
            .alert("Report Submitted! 🎉", isPresented: $showSuccess) {
                Button("Done", role: .cancel) { resetForm() }
            } message: {
                Text("Thanks for helping map surveillance cameras. Your report will be reviewed before going live.")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Pre-warm the map to user's location
            if let loc = appState.userLocation {
                mapRegion.center = loc.coordinate
            }
            // Ensure location is actively updating
            appState.locationManager.startUpdating()
        }
    }

    // MARK: - Actions

    private func snapToCurrentLocation() {
        locationError = nil

        // If we already have a fresh location, use it immediately
        if let loc = appState.userLocation, loc.timestamp.timeIntervalSinceNow > -30 {
            pinnedCoord = loc.coordinate
            locationSnapped = true
            mapRegion.center = loc.coordinate
            HapticManager.impact(.medium)
            return
        }

        // Check authorization first
        let status = appState.locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            locationError = "Location access is blocked. Enable it in Settings to use this feature."
            return
        }
        if status == .notDetermined {
            appState.locationManager.requestAlwaysAuthorization()
            locationError = "Please allow location access when prompted, then try again."
            return
        }

        // Location authorized but not yet received — wait up to 5s
        isGettingLocation = true
        appState.locationManager.startUpdating()

        Task {
            for _ in 0..<25 {  // poll up to 5 seconds
                try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2s
                if let loc = appState.userLocation {
                    await MainActor.run {
                        pinnedCoord = loc.coordinate
                        locationSnapped = true
                        mapRegion.center = loc.coordinate
                        isGettingLocation = false
                        HapticManager.impact(.medium)
                    }
                    return
                }
            }
            await MainActor.run {
                isGettingLocation = false
                locationError = "Couldn't get your location. Try \"Drop a Pin\" instead."
            }
        }
    }

    private func submit() {
        guard let coord = pinnedCoord else { return }
        isSubmitting = true
        HapticManager.impact(.medium)

        let photoData = photoImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        let report = CameraReport(
            latitude: coord.latitude,
            longitude: coord.longitude,
            reportType: .newCamera,
            ownerType: selectedOwner,
            mountType: .unknown,
            notes: notes.isEmpty ? nil : notes,
            photoData: photoData
        )
        modelContext.insert(report)
        try? modelContext.save()

        ReportNotificationService.shared.notifyCameraReport(
            latitude: coord.latitude,
            longitude: coord.longitude,
            ownerType: selectedOwner.rawValue,
            notes: notes.isEmpty ? nil : notes,
            photoCount: photoImages.count
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isSubmitting = false
            showSuccess = true
        }
    }

    private func resetForm() {
        pinnedCoord = nil
        locationSnapped = false
        selectedOwner = .unknown
        notes = ""
        selectedPhotos = []
        photoImages = []
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        photoImages = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let d = data,
                   let img = UIImage(data: d) {
                    DispatchQueue.main.async { self.photoImages.append(img) }
                }
            }
        }
    }
}

// MARK: - Section Card

struct ReportSectionCard<Content: View>: View {
    let number: String
    let title: String
    let icon: String
    let isComplete: Bool
    var isOptional: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isComplete ? Color.flockSafe : Color.flockPrimary)
                            .frame(width: 28, height: 28)
                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text(number)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .animation(.spring(duration: 0.3), value: isComplete)

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.flockText)

                    Spacer()

                    if isOptional {
                        Text("optional")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.flockTextSub)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.flockSurface2)
                            .clipShape(Capsule())
                    }
                }

                content
            }
            .padding(16)
        }
    }
}

// MARK: - Owner Type Grid

struct OwnerTypeGrid: View {
    @Binding var selected: OwnerType

    private let options: [(OwnerType, String, String)] = [
        (.municipalPolice,  "🚔", "Police"),
        (.federalAgency,    "🏛️", "Federal"),
        (.privateBusiness,  "🏪", "Business"),
        (.school,           "🎓", "School"),
        (.hoa,              "🏘️", "HOA"),
        (.unknown,          "❓", "Unknown"),
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(options, id: \.0) { option in
                Button {
                    selected = option.0
                    HapticManager.impact(.light)
                } label: {
                    VStack(spacing: 6) {
                        Text(option.1)
                            .font(.system(size: 26))
                        Text(option.2)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(selected == option.0 ? Color.flockPrimary : Color.flockTextSub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selected == option.0
                            ? Color.flockPrimary.opacity(0.18)
                            : Color.flockSurface2
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected == option.0 ? Color.flockPrimary : Color.clear, lineWidth: 1.5)
                    )
                }
                .animation(.spring(duration: 0.2), value: selected)
            }
        }
    }
}

// MARK: - Mini Map Preview

struct MiniMapPreview: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        ))) {
            Annotation("Camera", coordinate: coordinate) {
                ZStack {
                    Circle().fill(Color.flockPrimary).frame(width: 24, height: 24)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(true)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.flockPrimary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Map Pin Picker

struct MapPinPickerView: View {
    @Binding var coordinate: CLLocationCoordinate2D?
    let initialRegion: MKCoordinateRegion
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition
    @State private var pinCoord: CLLocationCoordinate2D

    init(coordinate: Binding<CLLocationCoordinate2D?>, initialRegion: MKCoordinateRegion) {
        self._coordinate = coordinate
        self.initialRegion = initialRegion
        let center = coordinate.wrappedValue ?? initialRegion.center
        self._pinCoord = State(initialValue: center)
        self._position = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Map fills screen
                MapReader { proxy in
                    Map(position: $position) {
                        Annotation("", coordinate: pinCoord) {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(Color.flockPrimary)
                                        .frame(width: 36, height: 36)
                                        .shadow(color: Color.flockPrimary.opacity(0.5), radius: 8)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                }
                                // Pin tail
                                Triangle()
                                    .fill(Color.flockPrimary)
                                    .frame(width: 14, height: 8)
                            }
                        }
                    }
                    .onTapGesture { point in
                        if let coord = proxy.convert(point, from: .local) {
                            pinCoord = coord
                            HapticManager.impact(.light)
                        }
                    }
                }

                // Instruction pill
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundStyle(Color.flockPrimary)
                        Text("Tap the map to place the camera pin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.flockText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 12)

                    Spacer()

                    // Confirm button
                    Button {
                        coordinate = pinCoord
                        HapticManager.impact(.medium)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Location")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.flockPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Pin Camera Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.flockPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - FormSection (kept for other uses)

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
