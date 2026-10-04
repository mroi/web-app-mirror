import Foundation
import Hummingbird
import NIOTransportServices
import Security

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

	@MainActor
	func start(cacheDirectory: URL, logDirectory: URL) {
		let port = self.port
		let tlsOptions: TSTLSOptions?
		if let commonName = proxyCertificateCommonName {
			guard let identity = findProxyIdentity(commonName: commonName) else {
				fatalError("Could not find a Keychain certificate and matching private key with Common Name '\(commonName)'.")
			}
			guard let options = TSTLSOptions.options(serverIdentity: .secIdentity(identity)) else {
				fatalError("Could not configure TLS with Keychain identity '\(commonName)'.")
			}
			tlsOptions = options
		} else {
			tlsOptions = nil
		}

		task = Task.detached {
			let cache = FileCache(directory: cacheDirectory, logDirectory: logDirectory)
			let handler = ProxyHandler(cache: cache)
			let app: Application<ProxyResponder>
			if let tlsOptions {
				let configuration = ApplicationConfiguration(
					address: .hostname("localhost", port: port),
					tlsOptions: tlsOptions
				)
				app = Application(
					responder: ProxyResponder(handler: handler),
					configuration: configuration,
					eventLoopGroupProvider: .shared(NIOTSEventLoopGroup.singleton)
				)
			} else {
				let configuration = ApplicationConfiguration(address: .hostname("localhost", port: port))
				app = Application(
					responder: ProxyResponder(handler: handler),
					configuration: configuration
				)
			}
			do {
				try await app.run()
			} catch {
				print("Proxy server error: \(error)")
			}
		}
	}

	@MainActor
	func stop() {
		task?.cancel()
		task = nil
	}
}

private func findProxyIdentity(commonName: String) -> SecIdentity? {
	let query: [String: Any] = [
		kSecClass as String: kSecClassCertificate,
		kSecReturnRef as String: true,
		kSecMatchLimit as String: kSecMatchLimitAll,
	]

	var result: CFTypeRef?
	guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
		let certificates = result as? [SecCertificate]
	else {
		return nil
	}

	for certificate in certificates {
		var certificateCommonName: CFString?
		guard SecCertificateCopyCommonName(certificate, &certificateCommonName) == errSecSuccess,
			let certificateCommonName,
			certificateCommonName as String == commonName
		else {
			continue
		}

		var identity: SecIdentity?
		guard SecIdentityCreateWithCertificate(nil, certificate, &identity) == errSecSuccess else {
			continue
		}
		return identity
	}

	return nil
}
