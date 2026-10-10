import SwiftUI
import Foundation
import WebKit

@main
struct WebAppMirror: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	@State private var appState = AppState()

	var body: some Scene {
		WindowGroup {
			WebContentView().environment(appState)
		}
		.defaultSize(width: 960, height: 540 + 32)
		.commands {
			PageCommands()
		}
	}
}

private struct PageCommands: Commands {
	@FocusedValue(\.webPageForReload) private var page

	var body: some Commands {
		CommandGroup(after: .newItem) {
			Button("Reload") {
				_ = page?.reload(fromOrigin: false)
			}
			.disabled(page == nil)
			.keyboardShortcut("r", modifiers: .command)
		}
	}
}

struct WebPageForReloadKey: FocusedValueKey {
	typealias Value = WebPage
}

extension FocusedValues {
	var webPageForReload: WebPage? {
		get { self[WebPageForReloadKey.self] }
		set { self[WebPageForReloadKey.self] = newValue }
	}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@Observable
@MainActor
class AppState {
	private var server: ProxyServer?

	func startProxy() {
		let cacheDir = URL.documentsDirectory.appending(path: "Mirror")
		let logDir = URL.cachesDirectory
			.deletingLastPathComponent()
			.appending(path: "Logs")
		let server = ProxyServer(port: 8080)
		self.server = server
		server.start(cacheDirectory: cacheDir, logDirectory: logDir)
	}

	func stopProxy() {
		server?.stop()
		server = nil
	}
}
