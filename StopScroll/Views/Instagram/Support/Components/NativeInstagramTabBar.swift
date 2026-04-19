import SwiftUI

struct NativeInstagramTabBar: View {
    let selectedTab: String
    let messageBadgeCount: Int
    let onSelectTab: (String) -> Void
    @ObservedObject private var settings = AppSettings.shared
    private var palette: AppSettings.AdaptivePalette { settings.adaptivePalette }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(NativeTabLayout.items, id: \.id) { item in
                tabButton(id: item.id, icon: item.icon, badge: item.id == "messages" ? messageBadgeCount : 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func tabButton(id: String, icon: String, badge: Int = 0) -> some View {
        Button {
            onSelectTab(id)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selectedTab == id ? palette.primaryText : palette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                if badge > 0 {
                    Text(badgeLabel(for: badge))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func badgeLabel(for count: Int) -> String {
        if count > 99 { return "99+" }
        return "\(count)"
    }
}

// MARK: - Instagram-style loading bar
