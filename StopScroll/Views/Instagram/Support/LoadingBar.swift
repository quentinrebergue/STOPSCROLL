import SwiftUI

struct LoadingBar: View {
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
