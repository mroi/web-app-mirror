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
		.focusedSceneValue(\.webPageForReload, page)
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
	for filename in userCSSFiles {
		let css = loadInjectionFile(filename)
		let cssLiteral = (try? String(data: JSONEncoder().encode(css), encoding: .utf8)) ?? "\"\""
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
	for filename in userJavaScriptFiles {
		configuration.userContentController.addUserScript(
			WKUserScript(source: loadInjectionFile(filename), injectionTime: .atDocumentStart, forMainFrameOnly: false)
		)
	}
	let page = WebPage(configuration: configuration)
	page.isInspectable = true
	return page
}

private func loadInjectionFile(_ filename: String) -> String {
	guard let url = Bundle.main.url(forResource: filename, withExtension: nil),
		let contents = try? String(contentsOf: url, encoding: .utf8)
	else {
		fatalError("Missing or unreadable injection resource: \(filename)")
	}
	return contents
}
