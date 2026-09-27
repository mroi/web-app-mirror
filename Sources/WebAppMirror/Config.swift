import Foundation

let targetURL = "https://example.com"

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
