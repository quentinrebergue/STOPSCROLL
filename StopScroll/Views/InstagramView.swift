import SwiftUI

struct InstagramView: View {
    @State private var isLoading = true
    @State private var showingReader = false

    var body: some View {
        ZStack {
            InstagramWebView(isLoading: $isLoading, showingReader: $showingReader)
                .ignoresSafeArea(edges: .bottom)

            if showingReader {
                BookReaderView(onDismiss: { showingReader = false })
                    .transition(.opacity)
                    .ignoresSafeArea(edges: .bottom)
            }

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
