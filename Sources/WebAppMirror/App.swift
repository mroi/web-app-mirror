import SwiftUI
import Foundation

@main
struct WebAppMirror: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            WebContentView()
                .environment(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@Observable
@MainActor
class AppState {
    private var server: ProxyServer?

    func startProxy() {
        let cacheDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Mirror")
        let logDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .deletingLastPathComponent()
            .appendingPathComponent("Logs")
        let server = ProxyServer(port: 8080)
        self.server = server
        server.start(cacheDirectory: cacheDir, logDirectory: logDir)
    }

    func stopProxy() {
        server?.stop()
        server = nil
    }
}
