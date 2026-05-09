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
        var lastGovernorSignature: String
        var didSendInitialActiveNavCommand: Bool
        private var horizontalPanRecognizer: UIPanGestureRecognizer?
        private var isLockingScrollForHorizontalSwipe = false
        private var lastMessagesDiagnosticsPath = ""
        private var isKeyboardVisible = false
        private var keyboardObserversInstalled = false
        private var appDidBecomeActiveObserver: NSObjectProtocol?
        private var thermalStateObserver: NSObjectProtocol?
        private var powerStateObserver: NSObjectProtocol?

        private static func isMessagesThreadPath(_ path: String) -> Bool {
            let normalized = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
            return normalized.hasPrefix("/direct/t/")
        }

        private func currentMessagesPath() -> String {
            if let path = webView?.url?.path, !path.isEmpty {
                return path
            }
            return lastMessagesDiagnosticsPath
        }

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
            self.lastGovernorSignature = ""
            self.didSendInitialActiveNavCommand = false

            super.init()

            self.appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.syncNativeTimerStateToWebView(markExpiredIfNeeded: true)
                self?.applyRuntimeGovernorIfNeeded(force: true)
            }

            self.thermalStateObserver = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyRuntimeGovernorIfNeeded(force: true)
            }

            self.powerStateObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name.NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyRuntimeGovernorIfNeeded(force: true)
            }
        }

        deinit {
            if let appDidBecomeActiveObserver {
                NotificationCenter.default.removeObserver(appDidBecomeActiveObserver)
            }
            if let thermalStateObserver {
                NotificationCenter.default.removeObserver(thermalStateObserver)
            }
            if let powerStateObserver {
                NotificationCenter.default.removeObserver(powerStateObserver)
            }
        }

        func installHorizontalPanRecognizer(on webView: WKWebView) {
            guard horizontalPanRecognizer == nil else { return }
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleHorizontalPan(_:)))
            recognizer.delegate = self
            recognizer.maximumNumberOfTouches = 1
            recognizer.cancelsTouchesInView = false
            webView.addGestureRecognizer(recognizer)
            horizontalPanRecognizer = recognizer
            installKeyboardObserversIfNeeded()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === horizontalPanRecognizer,
                  let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  parent.allowsHorizontalSurfaceSwipe,
                  parent.isActive,
                HorizontalSwipeRecognizerPolicy.shouldAllowSectionSwipe(
                    activeTab: parent.activeSectionTab
                ),
                  !parent.showingReader,
                  !parent.showingDashboard,
                  !parent.showingSettings else {
                return false
            }

            let velocity = pan.velocity(in: pan.view)

            if parent.activeSectionTab == "messages",
               let view = pan.view {
                if isKeyboardVisible {
                    return false
                }

                if Self.isMessagesThreadPath(currentMessagesPath()) {
                    return false
                }

                let location = pan.location(in: view)
                let edgeZone: CGFloat = 24
                let isEdgeSwipe = location.x <= edgeZone || location.x >= (view.bounds.width - edgeZone)
                if !isEdgeSwipe {
                    return false
                }
            }

            let shouldBegin = HorizontalSwipeRecognizerPolicy.shouldBegin(
                velocityX: velocity.x,
                velocityY: velocity.y,
                activeTab: parent.activeSectionTab
            )
            LogManager.shared.log(
                "↔️ Swipe begin? \(shouldBegin) tab=\(parent.activeSectionTab) vx=\(Int(velocity.x)) vy=\(Int(velocity.y))",
                category: "Swipe",
                level: .debug
            )
            return shouldBegin
        }

        @objc private func handleHorizontalPan(_ recognizer: UIPanGestureRecognizer) {
            guard parent.allowsHorizontalSurfaceSwipe,
                  parent.isActive,
                  HorizontalSwipeRecognizerPolicy.shouldAllowSectionSwipe(
                      activeTab: parent.activeSectionTab
                  ),
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
                LogManager.shared.log(
                    "↔️ Swipe began tab=\(parent.activeSectionTab)",
                    category: "Swipe",
                    level: .debug
                )
                parent.onHorizontalSurfaceDragChanged?(translation)
            case .changed:
                parent.onHorizontalSurfaceDragChanged?(translation)
            case .ended, .cancelled, .failed:
                lockWebViewScrollForHorizontalSwipe(false)
                LogManager.shared.log(
                    "↔️ Swipe ended tab=\(parent.activeSectionTab) dx=\(Int(translation)) vx=\(Int(velocity))",
                    category: "Swipe",
                    level: .debug
                )
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

        private func installKeyboardObserversIfNeeded() {
            guard !keyboardObserversInstalled else { return }
            keyboardObserversInstalled = true

            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillShowNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isKeyboardVisible = true
            }

            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isKeyboardVisible = false
            }
        }

        func logMessagesDiagnosticsIfNeeded() {
            guard AppSettings.shared.devMode,
                parent.activeSectionTab == "messages",
                  parent.isActive,
                  let webView else { return }

            webView.evaluateJavaScript("window.location && window.location.pathname") { value, _ in
                let path = (value as? String) ?? ""
                guard !path.isEmpty, path != self.lastMessagesDiagnosticsPath else { return }
                self.lastMessagesDiagnosticsPath = path

                webView.evaluateJavaScript(InstagramWebView.messagesDiagnosticsScript())
            }
        }
    }
}
