import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @State private var dismissedCameraID: UUID? = nil

    private var shouldShowBanner: Bool {
        guard let camera = appState.nearestCamera else { return false }
        return camera.id != dismissedCameraID
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // The previous paged TabView kept every tab's NavigationStack alive at once,
            // which crashed UIKit with "top item belongs to a different navigation bar"
            // (especially during layout passes, e.g. while cameras load). MapView has no
            // NavigationStack of its own, so it stays mounted to preserve its map/camera
            // state; the other tabs each own a NavigationStack and are mounted ONE AT A TIME.
            ZStack {
                MapView()
                    .ignoresSafeArea()
                    .opacity(appState.selectedTab == .map ? 1 : 0)
                    .allowsHitTesting(appState.selectedTab == .map)

                if appState.selectedTab != .map {
                    Group {
                        switch appState.selectedTab {
                        case .map:     EmptyView()
                        case .alerts:  AlertsView()
                        case .report:  ReportCameraView()
                        case .learn:   LearnView()
                        case .profile: ProfileView()
                        }
                    }
                    .background(Color.flockBG.ignoresSafeArea())
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.18), value: appState.selectedTab)

            VStack(spacing: 0) {
                if let camera = appState.nearestCamera,
                   let dist = appState.distanceToNearest,
                   shouldShowBanner {
                    ProximityBannerView(
                        camera: camera,
                        distance: dist,
                        visibility: appState.visibilityStatus,
                        onDismiss: { dismissedCameraID = camera.id }
                    )
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                FlockTabBar(selectedTab: $appState.selectedTab, alertBadge: appState.unreadAlertCount)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.nearestCamera?.id)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: appState.nearestCamera?.id) { _, newID in
            if newID != dismissedCameraID { dismissedCameraID = nil }
        }
    }
}
