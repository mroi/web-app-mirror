import Foundation

// The URL the WebView opens through the local proxy.
let startingURL = URL(string: "http://127.0.0.1:8080/")!

// Upstream base URLs accepted for proxy routing. The first URL is the default origin.
let proxyOrigins = [
	URL(string: "https://example.com/")!
]

// Optional Common Name of the Keychain identity used to serve the proxy via HTTPS.
let proxyCertificateCommonName: String? = nil

// Origins allowed to access proxied resources through CORS.
let corsAllowedOrigins: Set<String>()

// Custom CSS and JavaScript files in Sources/WebAppMirror/Resources to inject.
let userCSSFiles = Array<String>()
let userJavaScriptFiles = Array<String>()

// URL path prefixes to cache. A URL is cached if its path starts with any of these.
let cachePrefixes = [
	"/static/",
	"/assets/",
]

// If false, cache hits are served from disk. If true, always re-fetch from origin (still updates cache).
let alwaysRefetchCache = true

func shouldCache(url: URL) -> Bool {
	let path = url.path
	return cachePrefixes.contains { path.hasPrefix($0) }
}
