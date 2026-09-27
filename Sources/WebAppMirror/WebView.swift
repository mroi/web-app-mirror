import SwiftUI
import WebKit

struct WebContentView: View {
	@Environment(AppState.self) var appState
	@State private var isProxyReady = false

	var body: some View {
		Group {
			if isProxyReady {
				WebView(url: startingURL)
					.ignoresSafeArea()
			} else {
				ProgressView("Starting...")
			}
		}
		.windowFullScreenBehavior(.enabled)
		.task {
			appState.startProxy()
			isProxyReady = true
		}
		.onDisappear {
			appState.stopProxy()
		}
	}
}
