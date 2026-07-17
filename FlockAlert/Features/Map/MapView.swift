import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext

    // ViewModel is created lazily in onAppear so we can pass the real appState
    @StateObject private var viewModel = MapViewModel()

    @State private var selectedCamera: Camera?
    @State private var showFilters = false
    @State private var showZoomHint = true
    @State private var showDonation = false

    var body: some View {
        ZStack {
            mapLayer
                .ignoresSafeArea()

            // ── Overlay UI ──────────────────────────────────────────
            VStack(spacing: 0) {
                MapHeaderBar(
                    cameraCount: viewModel.visibleCameras.count,
                    totalCount: viewModel.totalCameraCount,
                    visibleInRegion: viewModel.visibleCount,
                    isClusterMode: viewModel.isClusterMode,
                    syncState: viewModel.syncState,
                    onFilter: { showFilters = true },
                    onToggleStyle: { viewModel.cycleMapStyle() },
                    onSupport: { showDonation = true }
                )
                .padding(.top, 56)
                .padding(.horizontal, 16)

                Spacer()
            }

            // ── Zoom hint ──────────────────────────────────────────────
            if viewModel.isClusterMode && showZoomHint {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Zoom in to see individual cameras")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 100)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(.easeOut(duration: 0.5)) { showZoomHint = false }
                    }
                }
            }

            // ── Detail Sheet ──────────────────────────────────────────
            if let camera = selectedCamera {
                VStack {
                    Spacer()
                    CameraDetailSheet(camera: camera) {
                        withAnimation(.spring()) { selectedCamera = nil }
                    } onReport: {
                        appState.selectedTab = .report
                        withAnimation { selectedCamera = nil }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterView(filters: $viewModel.activeFilters) { viewModel.applyFilters() }
        }
        .sheet(isPresented: $showDonation) {
            DonationView().environmentObject(SubscriptionManager.shared)
        }
        .onAppear {
            viewModel.setup(appState: appState, modelContext: modelContext)
        }
        // Re-center map whenever user location first becomes available
        .onChange(of: appState.userLocation) { _, loc in
            guard let loc else { return }
            viewModel.centerOnUserIfNeeded(loc)
        }
    }

    // MARK: - Map content (extracted to avoid type-checker timeouts)

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $viewModel.cameraPosition) {
            UserAnnotation()

            if viewModel.isClusterMode {
                // ── City cluster bubbles (zoomed out) ──────────────────
                ForEach(viewModel.cityClusters) { cluster in
                    Annotation("", coordinate: cluster.coordinate, anchor: .bottom) {
                        CityClusterPin(cluster: cluster)
                    }
                }
            } else {
                // ── Individual camera pins (zoomed in) ─────────────────
                ForEach(viewModel.visibleCameras) { camera in
                    Annotation("", coordinate: camera.coordinate, anchor: .center) {
                        CameraPin(
                            camera: camera,
                            isSelected: selectedCamera?.id == camera.id,
                            isActive: appState.activeAlertCameraIDs.contains(camera.id)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedCamera = (selectedCamera?.id == camera.id) ? nil : camera
                            }
                            HapticManager.impact(.light)
                        }
                    }
                }
            }

            if let cam = selectedCamera {
                let pts = viewModel.fovPolygon(for: cam)
                if pts.count > 2 {
                    MapPolygon(coordinates: pts)
                        .foregroundStyle(Color.flockPrimary.opacity(0.12))
                        .stroke(Color.flockPrimary.opacity(0.5), lineWidth: 1.5)
                }
            }

            if let loc = appState.userLocation {
                MapCircle(center: loc.coordinate, radius: appState.alertRadiusMetres)
                    .foregroundStyle(Color.flockAccent.opacity(0.04))
                    .stroke(Color.flockAccent.opacity(0.25), lineWidth: 1)
            }
        }
        .mapStyle(viewModel.mapStyle)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { ctx in
            viewModel.refreshForRegion(ctx.region)
            if !viewModel.isClusterMode {
                withAnimation(.easeOut(duration: 0.3)) { showZoomHint = false }
            }
        }
    }
}

// MARK: - Map Header Bar

struct MapHeaderBar: View {
    let cameraCount: Int
    let totalCount: Int
    let visibleInRegion: Int
    let isClusterMode: Bool
    let syncState: SyncState
    let onFilter: () -> Void
    let onToggleStyle: () -> Void
    let onSupport: () -> Void

    private var countLabel: String {
        if case .syncing = syncState {
            return "loading cameras"
        }
        if isClusterMode {
            return "zoom to load"
        }
        if visibleInRegion > cameraCount && cameraCount > 0 {
            return "\(cameraCount) of \(visibleInRegion)"
        }
        return "\(cameraCount) shown"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSupport) {
                GlassCard {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color.flockPrimary)
                            .font(.system(size: 12, weight: .bold))
                        Text("Keep Flock Alert Free!")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.flockPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .buttonStyle(.plain)
            .layoutPriority(1)

            Spacer(minLength: 6)

            GlassCard {
                HStack(spacing: 5) {
                    if case .syncing = syncState {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Circle()
                            .fill(Color.flockSafe)
                            .frame(width: 6, height: 6)
                    }
                    Text(countLabel)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.flockText)
                        .animation(.none, value: countLabel)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            GlassCard {
                Button(action: onFilter) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.flockText)
                        .frame(width: 36, height: 30)
                }
            }

            GlassCard {
                Button(action: onToggleStyle) {
                    Image(systemName: "map")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.flockText)
                        .frame(width: 36, height: 30)
                }
            }
        }
    }
}
