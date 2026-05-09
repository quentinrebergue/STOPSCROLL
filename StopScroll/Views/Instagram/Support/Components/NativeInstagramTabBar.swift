import SwiftUI

struct NativeInstagramTabBar: View {
    enum ProfileMode {
        case stopScroll
        case instagram
    }

    let selectedTab: String
    let messageBadgeCount: Int
    let isLocked: Bool
    let onSelectTab: (String) -> Void
    let onSelectInstagramProfile: () -> Void
    let onSelectStopScrollProfile: () -> Void
    let profileMode: ProfileMode
    
    @ObservedObject private var settings = AppSettings.shared
    
    private var palette: AppSettings.AdaptivePalette { settings.adaptivePalette }

    private var showsProfileSelector: Bool {
        selectedTab == "profile"
    }

    private var profileModeSelection: Binding<ProfileMode> {
        Binding(
            get: {
                profileMode
            },
            set: { newMode in
                switch newMode {
                case .stopScroll:
                    guard profileMode != .stopScroll else { return }
                    onSelectStopScrollProfile()
                case .instagram:
                    guard profileMode != .instagram else { return }
                    onSelectInstagramProfile()
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Profile mode selector (only visible when on profile tab)
            if showsProfileSelector {
                VStack(spacing: 4) {
                    Picker("Profile Mode", selection: profileModeSelection) {
                        Text("Dashboard").tag(ProfileMode.stopScroll)
                        Text("Insta Profile").tag(ProfileMode.instagram)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 10)
                }
                .padding(.top, 6)
                .padding(.horizontal, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Tab bar
            HStack(spacing: 1) {
                ForEach(isLocked ? NativeTabLayout.lockedItems : NativeTabLayout.items, id: \.id) { item in
                    tabButton(id: item.id, icon: item.icon, badge: item.id == "messages" ? messageBadgeCount : 0)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, showsProfileSelector ? 4 : 8)
            .padding(.bottom, 0)
            .accessibilityIdentifier("native.tabbar")
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            palette.border
                .frame(height: 1)
        }
    }

    private func tabButton(id: String, icon: String, badge: Int = 0) -> some View {
        Button {
            onSelectTab(id)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(selectedTab == id ? palette.primaryText : palette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)

                if badge > 0 {
                    Text(badgeLabel(for: badge))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 0)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("native.tab.\(id)")
        .accessibilityLabel("native-tab-\(id)")
    }

    private func badgeLabel(for count: Int) -> String {
        if count > 99 { return "99+" }
        return "\(count)"
    }
}
