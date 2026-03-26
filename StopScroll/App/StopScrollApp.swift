import SwiftUI

@main
struct StopScrollApp: App {
    var body: some Scene {
        WindowGroup {
            InstagramView()
                .preferredColorScheme(.dark)
        }
    }
}
