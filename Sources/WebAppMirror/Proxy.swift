import Foundation
import HTTPTypes
import Hummingbird
import NIOCore

struct ProxyHandler: Sendable {
	let cache: FileCache
	private let allowedMethods = "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS"

	func handle(_ request: Request, context: BasicRequestContext) async throws -> Response {
		if request.method.rawValue == "OPTIONS" {
			return Response(
				status: .init(code: 204),
				headers: makeHeaders(corsHeaders(for: request, preflight: true))
			)
		}

		let upstreamBaseURL: URL
		if let requestedOrigin = request.headers.first(where: {
			$0.name.rawName.lowercased() == "x-proxy-origin"
		})?.value {
			guard let configuredOrigin = proxyOrigins.first(where: { origin(of: $0) == requestedOrigin }) else {
				return makeEmptyResponse(statusCode: 400, request: request)
			}
			upstreamBaseURL = configuredOrigin
		} else if let defaultOrigin = proxyOrigins.first {
			upstreamBaseURL = defaultOrigin
		} else {
			return makeEmptyResponse(statusCode: 500, request: request)
		}

		var components = URLComponents(url: upstreamBaseURL, resolvingAgainstBaseURL: true)!
		components.path = request.uri.path.isEmpty ? "/" : request.uri.path
		if let query = request.uri.query {
			components.query = query
		}
		guard let target = components.url else {
			return makeEmptyResponse(statusCode: 400, request: request)
		}

		if shouldCache(url: target), !alwaysRefetchCache, let entry = await cache.read(target) {
			var headers = await cache.generateHeaders(for: target)
			headers.merge(corsHeaders(for: request)) { _, corsValue in corsValue }
			return makeResponse(body: entry.body, statusCode: entry.statusCode, headers: headers)
		}

		guard let (data, statusCode, contentType) = try? await fetch(target, request: request) else {
			return makeEmptyResponse(statusCode: 500, request: request)
		}

		return makeResponse(
			body: data,
			statusCode: statusCode,
			headers: corsHeaders(for: request),
			contentType: contentType
		)
	}

	private func corsHeaders(for request: Request, preflight: Bool = false) -> [String: String] {
		guard let origin = request.headers.first(where: { $0.name.rawName.lowercased() == "origin" })?.value,
			corsAllowedOrigins.contains(origin)
		else {
			return [:]
		}

		var headers = [
			"Access-Control-Allow-Origin": origin,
			"Access-Control-Allow-Credentials": "true",
			"Vary": "Origin",
		]

		if preflight {
			headers["Access-Control-Allow-Methods"] = allowedMethods
			headers["Access-Control-Allow-Headers"] = request.headers.first {
				$0.name.rawName.lowercased() == "access-control-request-headers"
			}?.value ?? "Content-Type, Authorization"
			headers["Access-Control-Max-Age"] = "86400"
			if request.headers.first(where: {
				$0.name.rawName.lowercased() == "access-control-request-private-network"
			})?.value.lowercased() == "true" {
				headers["Access-Control-Allow-Private-Network"] = "true"
			}
		}

		return headers
	}

	private func origin(of url: URL) -> String? {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			let scheme = components.scheme,
			let host = components.host
		else {
			return nil
		}

		let formattedHost = host.contains(":") ? "[\(host)]" : host
		let port = components.port.map { ":\($0)" } ?? ""
		return "\(scheme)://\(formattedHost)\(port)"
	}

	private func makeHeaders(_ values: [String: String]) -> HTTPFields {
		var headers = HTTPFields()
		for (key, value) in values {
			if let name = HTTPField.Name(key) {
				headers.append(HTTPField(name: name, value: value))
			}
		}
		return headers
	}

	private func makeEmptyResponse(statusCode: Int, request: Request) -> Response {
		Response(
			status: .init(code: statusCode),
			headers: makeHeaders(corsHeaders(for: request))
		)
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
			status: .init(code: statusCode),
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
			status: .init(code: statusCode),
			headers: hbHeaders,
			body: .init(byteBuffer: buffer)
		)
	}

	private func fetch(_ url: URL, request: Request) async throws -> (Data, Int, String?) {
		var req = URLRequest(url: url)
		req.httpMethod = request.method.rawValue
		req.timeoutInterval = 30

		let skipHeaders: Set<String> = ["host", "connection", "transfer-encoding", "x-proxy-origin"]
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
