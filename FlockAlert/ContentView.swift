import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                MapView()
                    .tag(Tab.map)
                    .ignoresSafeArea()

                AlertsView()
                    .tag(Tab.alerts)

                ReportCameraView()
                    .tag(Tab.report)

                LearnView()
                    .tag(Tab.learn)

                SettingsView()
                    .tag(Tab.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Proximity banner — floats above tab bar
                if let camera = appState.nearestCamera,
                   let dist = appState.distanceToNearest {
                    ProximityBannerView(camera: camera, distance: dist, visibility: appState.visibilityStatus)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                FlockTabBar(selectedTab: $appState.selectedTab, alertBadge: appState.unreadAlertCount)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.nearestCamera?.id)
        }
    }
}
