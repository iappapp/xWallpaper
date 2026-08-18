import Foundation
import AppKit
import Darwin

class CategoryThumbCache {
    static let shared = CategoryThumbCache()

    private let fileManager = FileManager.default
    private let accessQueue = DispatchQueue(label: "category.cache.queue", attributes: .concurrent)
    private let completionLock = NSLock()
    private var inFlightCompletions: [String: [(URL?) -> Void]] = [:]
    private let cacheDirectoryURL: URL

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

    private init() {
        let homeCacheURL = Self.realUserHomeDirectory(fileManager: fileManager)
            .appendingPathComponent(".xWallpaper", isDirectory: true)
            .appendingPathComponent("CategoryThumb", isDirectory: true)
        if (try? fileManager.createDirectory(at: homeCacheURL, withIntermediateDirectories: true)) != nil {
            cacheDirectoryURL = homeCacheURL
            return
        }

        let fallbackBase = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let fallbackURL = fallbackBase.appendingPathComponent("CategoryThumb", isDirectory: true)
        try? fileManager.createDirectory(at: fallbackURL, withIntermediateDirectories: true)
        cacheDirectoryURL = fallbackURL
    }

    private static func realUserHomeDirectory(fileManager: FileManager) -> URL {
        if let passwordEntry = getpwuid(getuid()),
           let homePath = String(validatingUTF8: passwordEntry.pointee.pw_dir) {
            return URL(fileURLWithPath: homePath, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
    }

    func cachedThumbnailURL(for category: Category) -> URL? {
        let targetURL = thumbnailFileURL(for: category)
        return fileManager.fileExists(atPath: targetURL.path) ? targetURL : nil
    }

    func loadThumbnail(for category: Category, completion: @escaping (URL?) -> Void) {
        if let existingURL = cachedThumbnailURL(for: category) {
            completion(existingURL)
            return
        }

        // 检查是否已有相同请求在进行中
        var shouldFetch = false
        completionLock.lock()
        defer { completionLock.unlock() }
        
        if self.inFlightCompletions[category.id] != nil {
            self.inFlightCompletions[category.id]?.append(completion)
        } else {
            self.inFlightCompletions[category.id] = [completion]
            shouldFetch = true
        }

        guard shouldFetch else { return }

        // 在后台队列中执行网络请求
        accessQueue.async { [weak self] in
            guard let self else { return }
            
            // 先从 Unsplash API 获取该类别的第一张图片作为缩略图
            UnsplashAPI.shared.fetchCategoryThumbnail(for: category) { thumbUrl in
                guard let thumbUrlString = thumbUrl else {
                    self.completeRequests(for: category, with: nil)
                    return
                }

                guard let imageURL = URL(string: thumbUrlString) else {
                    self.completeRequests(for: category, with: nil)
                    return
                }

                // 下载并保存到本地缓存
                self.urlSession.dataTask(with: imageURL) { data, response, error in
                    var savedURL: URL?

                    defer {
                        self.completeRequests(for: category, with: savedURL)
                    }

                    if let error {
                        print("[CategoryThumCache] Download failed: \(error.localizedDescription)")
                        return
                    }

                    guard
                        let httpResponse = response as? HTTPURLResponse,
                        (200...299).contains(httpResponse.statusCode),
                        let data,
                        let image = NSImage(data: data)
                    else {
                        print("[CategoryThumCache] Invalid response or image data")
                        return
                    }

                    let targetURL = self.thumbnailFileURL(for: category)
                    do {
                        if let pngData = Self.normalizedPNGData(from: image) {
                            try pngData.write(to: targetURL, options: .atomic)
                        } else {
                            try data.write(to: targetURL, options: .atomic)
                        }
                        savedURL = targetURL
                        print("[CategoryThumCache] Saved thumbnail for category '\(category.name)'")
                        print("Path: \(targetURL.path)")
                        print("Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                    } catch {
                        print("[CategoryThumCache] Save failed for '\(category.name)': \(error.localizedDescription)")
                        print("Path: \(targetURL.path)")
                    }
                }.resume()
            }
        }
    }

    func removeThumbnail(forCategoryId id: String) {
        let url = cacheDirectoryURL.appendingPathComponent("\(id).png")
        try? fileManager.removeItem(at: url)
    }

    private func thumbnailFileURL(for category: Category) -> URL {
        return cacheDirectoryURL.appendingPathComponent("\(category.id).png")
    }

    private func completeRequests(for category: Category, with url: URL?) {
        completionLock.lock()
        let callbacks = inFlightCompletions.removeValue(forKey: category.id) ?? []
        completionLock.unlock()
        DispatchQueue.main.async {
            callbacks.forEach { $0(url) }
        }
    }

    private static func normalizedPNGData(from image: NSImage) -> Data? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
