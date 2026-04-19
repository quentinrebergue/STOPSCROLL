import SwiftUI
import WebKit

extension InstagramWebView {
    // MARK: - Leak-safe message handler wrapper

    class LeakAvoider: NSObject, WKScriptMessageHandler {
        weak var delegate: WKScriptMessageHandler?
        init(delegate: WKScriptMessageHandler) { self.delegate = delegate; super.init() }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            delegate?.userContentController(controller, didReceive: message)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        struct ArticleOpenDefaults {
            let savedCardIndex: Int
            let savedBookTitle: String
            let currentArticleId: String
            let currentArticleOpenToken: Int
        }

        var parent: InstagramWebView
        weak var webView: WKWebView?
        var lastReloadToken: Int
        var lastLabelsToken: Int
        var lastThemeRefreshToken: Int
        var lastWikipediaTitle: String
        var lastNativeNavCommandToken: Int
        var lastRequestedURLToken: Int
        var lastIsActive: Bool
        var didSendInitialActiveNavCommand: Bool
        private var horizontalPanRecognizer: UIPanGestureRecognizer?
        private var isLockingScrollForHorizontalSwipe = false

        init(_ parent: InstagramWebView) {
            self.parent = parent
            self.lastReloadToken = parent.reloadToken
            self.lastLabelsToken = parent.labelsToken
            self.lastThemeRefreshToken = parent.themeRefreshToken
            self.lastWikipediaTitle = ""
            self.lastNativeNavCommandToken = parent.nativeNavCommandToken
            // Force the first updateUIView pass to process requestedURLString/token.
            // This is important for lazily created secondary surfaces.
            self.lastRequestedURLToken = Int.min
            self.lastIsActive = parent.isActive
            self.didSendInitialActiveNavCommand = false
        }

        func installHorizontalPanRecognizer(on webView: WKWebView) {
            guard horizontalPanRecognizer == nil else { return }
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleHorizontalPan(_:)))
            recognizer.delegate = self
            recognizer.maximumNumberOfTouches = 1
            recognizer.cancelsTouchesInView = true
            webView.addGestureRecognizer(recognizer)
            horizontalPanRecognizer = recognizer
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === horizontalPanRecognizer,
                  let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  parent.allowsHorizontalSurfaceSwipe,
                  parent.isActive,
                  !parent.showingReader,
                  !parent.showingDashboard,
                  !parent.showingSettings else {
                return false
            }

            let velocity = pan.velocity(in: pan.view)
            return HorizontalSwipeRecognizerPolicy.shouldBegin(
                velocityX: velocity.x,
                velocityY: velocity.y,
                activeTab: parent.activeSectionTab
            )
        }

        @objc private func handleHorizontalPan(_ recognizer: UIPanGestureRecognizer) {
            guard parent.allowsHorizontalSurfaceSwipe,
                  parent.isActive,
                  !parent.showingReader,
                  !parent.showingDashboard,
                  !parent.showingSettings else {
                return
            }

            let translation = recognizer.translation(in: recognizer.view).x
            let velocity = recognizer.velocity(in: recognizer.view).x

            switch recognizer.state {
            case .began:
                if parent.activeSectionTab == "search" {
                    lockWebViewScrollForHorizontalSwipe(true)
                }
                parent.onHorizontalSurfaceDragChanged?(translation)
            case .changed:
                parent.onHorizontalSurfaceDragChanged?(translation)
            case .ended, .cancelled, .failed:
                lockWebViewScrollForHorizontalSwipe(false)
                parent.onHorizontalSurfaceDragEnded?(translation, velocity)
            default:
                return
            }
        }

        private func lockWebViewScrollForHorizontalSwipe(_ shouldLock: Bool) {
            guard shouldLock != isLockingScrollForHorizontalSwipe else { return }
            isLockingScrollForHorizontalSwipe = shouldLock
            webView?.scrollView.isScrollEnabled = !shouldLock
        }
    }
}
