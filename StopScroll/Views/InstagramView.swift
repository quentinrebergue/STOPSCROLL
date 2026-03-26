import SwiftUI

struct InstagramView: View {
    @State private var isLoading = true

    var body: some View {
        ZStack {
            InstagramWebView(isLoading: $isLoading)
                .ignoresSafeArea(edges: .bottom)

            if isLoading {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
            }
        }
    }
}
