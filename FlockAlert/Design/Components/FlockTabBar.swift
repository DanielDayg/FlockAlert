import SwiftUI

struct FlockTabBar: View {
    @Binding var selectedTab: Tab
    let alertBadge: Int

    var body: some View {
        GlassCard(cornerRadius: 22) {
            HStack(spacing: 0) {
                TabBarButton(tab: .map, selectedTab: $selectedTab)
                TabBarButton(tab: .alerts, selectedTab: $selectedTab, badge: alertBadge > 0 ? alertBadge : nil)
                TabBarButton(tab: .report, selectedTab: $selectedTab)
                TabBarButton(tab: .learn, selectedTab: $selectedTab)
                TabBarButton(tab: .profile, selectedTab: $selectedTab)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
    }
}

struct TabBarButton: View {
    let tab: Tab
    @Binding var selectedTab: Tab
    var badge: Int? = nil

    private var isSelected: Bool { selectedTab == tab }

    private var icon: String {
        switch tab {
        case .map:      return isSelected ? "map.fill" : "map"
        case .alerts:   return isSelected ? "bell.badge.fill" : "bell"
        case .report:   return isSelected ? "camera.fill" : "camera"
        case .learn:    return isSelected ? "book.fill" : "book"
        case .profile:  return isSelected ? "person.fill" : "person"
        }
    }

    private var label: String {
        switch tab {
        case .map:      return "Map"
        case .alerts:   return "Alerts"
        case .report:   return "Report"
        case .learn:    return "Learn"
        case .profile:  return "Profile"
        }
    }

    var body: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                selectedTab = tab
            }
            HapticManager.selection()
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.flockPrimary : Color.flockTextSub)
                        .frame(width: 28, height: 24)
                        .scaleEffect(isSelected ? 1.1 : 1.0)

                    if let count = badge {
                        ZStack {
                            Circle()
                                .fill(Color.flockAlert)
                                .frame(width: 16, height: 16)
                            Text(count < 10 ? "\(count)" : "9+")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 6, y: -4)
                    }
                }

                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.flockPrimary : Color.flockTextSub)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
