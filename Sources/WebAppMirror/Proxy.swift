import Foundation
import HTTPTypes
import Hummingbird
import NIOCore

struct ProxyHandler: Sendable {
	let cache: FileCache

	func handle(_ request: Request, context: BasicRequestContext) async throws -> Response {
		var components = URLComponents(url: proxyBaseURL, resolvingAgainstBaseURL: true)!
		components.path = request.uri.path.isEmpty ? "/" : request.uri.path
		if let query = request.uri.query {
			components.query = query
		}
		guard let target = components.url else {
			return Response(status: .badRequest)
		}

		if shouldCache(url: target), !alwaysRefetchCache, let entry = await cache.read(target) {
			let headers = await cache.generateHeaders(for: target)
			return makeResponse(body: entry.body, statusCode: entry.statusCode, headers: headers)
		}

		guard let (data, statusCode, contentType) = try? await fetch(target, request: request) else {
			return Response(status: .internalServerError)
		}

		return makeResponse(body: data, statusCode: statusCode, headers: [:], contentType: contentType)
	}

	private func makeResponse(body: Data, statusCode: Int, headers: [String: String]) -> Response {
		var hbHeaders = HTTPFields()
		for (key, value) in headers {
			let lower = key.lowercased()
			guard lower != "content-encoding" else { continue }
			if let name = HTTPField.Name(key) {
				hbHeaders.append(HTTPField(name: name, value: value))
			}
		}
		let buffer = ByteBuffer(bytes: body)
		return Response(
			status: .init(code: max(200, statusCode)),
			headers: hbHeaders,
			body: .init(byteBuffer: buffer)
		)
	}

	private func makeResponse(body: Data, statusCode: Int, headers: [String: String], contentType: String?) -> Response {
		var hbHeaders = HTTPFields()
		for (key, value) in headers {
			let lower = key.lowercased()
			guard lower != "transfer-encoding", lower != "connection", lower != "content-length", lower != "content-encoding" else { continue }
			if let name = HTTPField.Name(key) {
				hbHeaders.append(HTTPField(name: name, value: value))
			}
		}
		if let ct = contentType {
			hbHeaders[.contentType] = ct
		}
		let buffer = ByteBuffer(bytes: body)
		return Response(
			status: .init(code: max(200, statusCode)),
			headers: hbHeaders,
			body: .init(byteBuffer: buffer)
		)
	}

	private func fetch(_ url: URL, request: Request) async throws -> (Data, Int, String?) {
		var req = URLRequest(url: url)
		req.httpMethod = request.method.rawValue
		req.timeoutInterval = 30

		let skipHeaders: Set<String> = ["host", "connection", "transfer-encoding"]
		for header in request.headers {
			let name = header.name.rawName.lowercased()
			if !skipHeaders.contains(name) {
				req.setValue(header.value, forHTTPHeaderField: header.name.rawName) 
			}
		}

		let (data, response) = try await URLSession.shared.data(for: req)
		let httpResponse = response as? HTTPURLResponse
		let statusCode = httpResponse?.statusCode ?? 200
		let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type")

		if shouldCache(url: url) {
			await cache.updateCache(url, body: data, statusCode: statusCode)
		}
		return (data, statusCode, contentType)
	}
}
