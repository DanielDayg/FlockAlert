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
                    onToggleStyle: { viewModel.cycleMapStyle() }
                )
                .padding(.top, 56)
                .padding(.horizontal, 16)

                Spacer()
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

    private var countLabel: String {
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
            GlassCard {
                HStack(spacing: 6) {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                        .foregroundStyle(Color.flockPrimary)
                        .font(.system(size: 14, weight: .semibold))
                    Text("FLOCK ALERT")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.flockPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Spacer()

            GlassCard {
                HStack(spacing: 5) {
                    Circle()
                        .fill(syncState == .syncing ? Color.flockCaution : Color.flockSafe)
                        .frame(width: 6, height: 6)
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
