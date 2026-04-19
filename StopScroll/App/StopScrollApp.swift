import SwiftUI

@main
struct StopScrollApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            InstagramView()
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}
