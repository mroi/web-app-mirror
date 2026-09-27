import Foundation
import Hummingbird

struct ProxyResponder: HTTPResponder {
    let handler: ProxyHandler

    func respond(to request: Request, context: BasicRequestContext) async throws -> Response {
        try await handler.handle(request, context: context)
    }
}

final class ProxyServer {
    private var task: Task<Void, Never>?

    let port: Int

    init(port: Int) {
        self.port = port
    }

    @MainActor func start(cacheDirectory: URL, logDirectory: URL) {
        task = Task.detached {
            let cache = FileCache(directory: cacheDirectory, logDirectory: logDirectory)
            let handler = ProxyHandler(cache: cache)
            let app = Application(responder: ProxyResponder(handler: handler))
            do {
                try await app.run()
            } catch {
                print("Proxy server error: \(error)")
            }
        }
    }

    @MainActor func stop() {
        task?.cancel()
        task = nil
    }
}
