import SwiftUI
import WebKit

struct WebContentView: View {
	@Environment(AppState.self) var appState
	@State private var isProxyReady = false
	@State private var page = makeConfiguredWebPage()

	var body: some View {
		Group {
			if isProxyReady {
				WebView(page)
					.ignoresSafeArea()
			} else {
				ProgressView("Starting...")
			}
		}
		.windowFullScreenBehavior(.enabled)
		.task {
			appState.startProxy()
			_ = page.load(startingURL)
			isProxyReady = true
		}
		.onDisappear {
			appState.stopProxy()
		}
	}
}

@MainActor
private func makeConfiguredWebPage() -> WebPage {
	let configuration = WebPage.Configuration()
	if !userCSS.isEmpty {
		let cssLiteral = (try? String(data: JSONEncoder().encode(userCSS), encoding: .utf8)) ?? "\"\""
		let script = """
		(() => {
			const style = document.createElement("style");
			style.textContent = \(cssLiteral);
			(document.head ?? document.documentElement).append(style);
		})();
		"""
		configuration.userContentController.addUserScript(
			WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
		)
	}
	if !userJavaScript.isEmpty {
		configuration.userContentController.addUserScript(
			WKUserScript(source: userJavaScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		)
	}
	return WebPage(configuration: configuration)
}
