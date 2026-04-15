import SwiftUI

struct InstagramView: View {
    @State private var isLoading = true
    @State private var showingReader = false
    @State private var reloadToken = 0
    @State private var showingSettings = false
    /// Incremented when the user closes Settings so the WebView re-injects the updated label list.
    @State private var labelsToken = 0

    var body: some View {
        ZStack {
            InstagramWebView(
                isLoading: $isLoading,
                showingReader: $showingReader,
                showingSettings: $showingSettings,
                reloadToken: $reloadToken,
                labelsToken: $labelsToken
            )
            .ignoresSafeArea(edges: .bottom)

            BookReaderView(onDismiss: { showingReader = false })
                .opacity(showingReader ? 1 : 0)
                .allowsHitTesting(showingReader)
                .ignoresSafeArea(edges: .bottom)

            if isLoading {
                VStack(spacing: 0) {
                    LoadingBar()
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onDismiss: {
                showingSettings = false
                labelsToken += 1  // triggers label re-injection into the live WebView
            })
        }
    }
}

// MARK: - Instagram-style loading bar

private struct LoadingBar: View {
    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.58, blue: 0.20),
                    Color(red: 0.86, green: 0.15, blue: 0.26),
                    Color(red: 0.74, green: 0.09, blue: 0.53),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.35)
            .offset(x: animating ? geo.size.width * 0.65 : 0)
        }
        .frame(height: 2)
        .clipped()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
    }
}
