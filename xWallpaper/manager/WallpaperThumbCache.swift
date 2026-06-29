import Foundation
import AppKit
import Darwin

class WallpaperThumbCache {
    static let shared = WallpaperThumbCache()

    private let fileManager = FileManager.default
    private let accessQueue = DispatchQueue(label: "wallpaper.cache.queue", attributes: .concurrent)
    private let completionLock = NSLock()
    private var inFlightCompletions: [String: [(URL?) -> Void]] = [:]

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    private lazy var cacheDirectoryURL: URL = {
        let homeCacheURL = realUserHomeDirectory()
            .appendingPathComponent(".xWallpaper", isDirectory: true)
            .appendingPathComponent("HistoryThumb", isDirectory: true)
        if (try? fileManager.createDirectory(at: homeCacheURL, withIntermediateDirectories: true)) != nil {
            return homeCacheURL
        }

        let fallbackBase = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let fallbackURL = fallbackBase.appendingPathComponent("HistoryThumb", isDirectory: true)
        try? fileManager.createDirectory(at: fallbackURL, withIntermediateDirectories: true)
        return fallbackURL
    }()

    private func realUserHomeDirectory() -> URL {
        if let passwordEntry = getpwuid(getuid()),
           let homePath = String(validatingUTF8: passwordEntry.pointee.pw_dir) {
            return URL(fileURLWithPath: homePath, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
    }

    func cachedThumbnailURL(for wallpaper: Wallpaper) -> URL? {
        if let localThumbUrl = wallpaper.localThumbUrl,
           let localURL = URL(string: localThumbUrl),
           localURL.isFileURL,
           fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }

        let targetURL = thumbnailFileURL(for: wallpaper)
        return fileManager.fileExists(atPath: targetURL.path) ? targetURL : nil
    }

    func cachedThumbnailPath(for wallpaper: Wallpaper) -> String? {
        cachedThumbnailURL(for: wallpaper)?.absoluteString
    }

    func removeThumbnail(for wallpaper: Wallpaper) {
        var urlsToRemove = [thumbnailFileURL(for: wallpaper)]

        if let localThumbUrl = wallpaper.localThumbUrl,
           let localURL = URL(string: localThumbUrl),
           localURL.isFileURL {
            urlsToRemove.append(localURL)
        }

        for url in Set(urlsToRemove.map(\.standardizedFileURL)) {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    func loadThumbnail(for wallpaper: Wallpaper, completion: @escaping (URL?) -> Void) {
        if let existingURL = cachedThumbnailURL(for: wallpaper) {
            completion(existingURL)
            return
        }

        guard let remoteURL = URL(string: wallpaper.thumbUrl) else {
            completion(nil)
            return
        }

        // 检查是否已有相同请求在进行中
        var shouldFetch = false
        completionLock.lock()
        defer { completionLock.unlock() }
        
        if self.inFlightCompletions[wallpaper.id] != nil {
            self.inFlightCompletions[wallpaper.id]?.append(completion)
        } else {
            self.inFlightCompletions[wallpaper.id] = [completion]
            shouldFetch = true
        }

        guard shouldFetch else { return }

        accessQueue.async { [weak self] in
            guard let self else { return }
            
            self.urlSession.dataTask(with: remoteURL) { data, response, error in
                var savedURL: URL?

                defer {
                    self.completionLock.lock()
                    let callbacks = self.inFlightCompletions.removeValue(forKey: wallpaper.id) ?? []
                    self.completionLock.unlock()
                    DispatchQueue.main.async {
                        callbacks.forEach { $0(savedURL) }
                    }
                }

                if let error {
                    print("[WallpaperThumCache] ❌ Download failed: \(error.localizedDescription)")
                    return
                }

                guard
                    let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode),
                    let data,
                    NSImage(data: data) != nil
                else {
                    print("[WallpaperThumCache] ❌ Invalid response or image data")
                    return
                }

                let targetURL = self.thumbnailFileURL(for: wallpaper)
                do {
                    try data.write(to: targetURL, options: .atomic)
                    savedURL = targetURL
                    print("[WallpaperThumCache] ✅ Cached wallpaper thumbnail '\(wallpaper.id)'")
                    print("    Path: \(targetURL.path)")
                    print("    Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                } catch {
                    print("[WallpaperThumCache] ❌ Cache failed for '\(wallpaper.id)': \(error.localizedDescription)")
                    print("    Path: \(targetURL.path)")
                }
            }.resume()
        }
    }

    private func thumbnailFileURL(for wallpaper: Wallpaper) -> URL {
        cacheDirectoryURL.appendingPathComponent("\(wallpaper.id).jpg")
    }
}
