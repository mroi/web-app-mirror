import Foundation
import UniformTypeIdentifiers

struct CacheEntry: Sendable {
    let body: Data
    let statusCode: Int
}

actor FileCache {
    private let directory: URL
    private var logFileHandle: FileHandle?

    init(directory: URL, logDirectory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let logFile = logDirectory.appendingPathComponent("WebAppMirror.log")
        try? Data().write(to: logFile, options: .withoutOverwriting)
        if let handle = try? FileHandle(forUpdating: logFile) {
            _ = try? handle.seekToEnd()
            logFileHandle = handle
        }
    }

    func read(_ url: URL) -> CacheEntry? {
        let file = cacheFile(url)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return CacheEntry(body: data, statusCode: 200)
    }

    func write(_ url: URL, body: Data, statusCode: Int) {
        let file = cacheFile(url)
        let dir = file.deletingLastPathComponent().path()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? body.write(to: file, options: .atomic)
    }

    func updateCache(_ url: URL, body: Data, statusCode: Int) {
        let cached = read(url)
        let updated = cached.map { $0.body != body } ?? true
        write(url, body: body, statusCode: statusCode)
        if cached != nil, updated {
            log("Cache updated: \(url.absoluteString)")
        }
    }

    func generateHeaders(for url: URL) -> [String: String] {
        var headers: [String: String] = [:]
        let file = cacheFile(url)

        if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path()) {
            headers["Content-Length"] = "\(attributes[.size] as? UInt64 ?? 0)"
            if let modificationDate = attributes[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                headers["Last-Modified"] = formatter.string(from: modificationDate)
            }
        }

        if let mimeType = mimeType(for: file.pathExtension) {
            headers["Content-Type"] = mimeType
        }

        return headers
    }

    private func cacheFile(_ url: URL) -> URL {
        let path = url.path.isEmpty ? "/" : url.path
        return directory.appendingPathComponent(path, isDirectory: false)
    }

    private func mimeType(for extension: String) -> String? {
        guard !`extension`.isEmpty else { return nil }
        if let type = UTType(filenameExtension: `extension`) {
            return type.preferredMIMEType
        }
        return nil
    }

    private func log(_ message: String) {
        guard let handle = logFileHandle else { return }
        let msg = "\(Date()) \(message)\n"
        handle.write(msg.data(using: .utf8) ?? Data())
    }
}
