import SwiftUI
import WebKit

struct WebContentView: View {
	@Environment(AppState.self) var appState
	@State private var isProxyReady = false

	var body: some View {
		Group {
			if isProxyReady {
				WebView(url: URL(string: "http://127.0.0.1:8080/")!)
					.ignoresSafeArea()
			} else {
				ProgressView("Starting...")
			}
		}
		.task {
			appState.startProxy()
			isProxyReady = true
		}
		.onDisappear {
			appState.stopProxy()
		}
	}
}
