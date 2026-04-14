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
                reloadToken: $reloadToken,
                labelsToken: $labelsToken
            )
            .ignoresSafeArea(edges: .bottom)

            VStack {
                HStack {
                    // Fallback reload button (top-left). Hidden by JS once it injects
                    // its own reload button into Instagram's native top nav bar.
                    Button {
                        reloadToken += 1
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 12)
                    .accessibilityLabel("Reload feed")

                    Spacer()

                    // StopScroll settings
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 12)
                    .accessibilityLabel("StopScroll settings")
                }
                .padding(.top, 8)
                Spacer()
            }
            .opacity(showingReader ? 0 : 1)
            .allowsHitTesting(!showingReader)

            BookReaderView(onDismiss: { showingReader = false })
                .opacity(showingReader ? 1 : 0)
                .allowsHitTesting(showingReader)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(onDismiss: {
                showingSettings = false
                labelsToken += 1  // triggers label re-injection into the live WebView
            })
        }
    }
}
