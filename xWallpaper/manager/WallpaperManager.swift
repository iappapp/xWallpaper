import AppKit
import Darwin
import Foundation

class WallpaperManager {
    static let shared = WallpaperManager()
    private let wallpaperDirectoryBookmarkKey = "wallpaper.directory.bookmark"
    private let defaultWallpaperDirectoryName = ".xWallpaper"

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

    private func realUserHomeDirectory() -> URL {
        if let passwordEntry = getpwuid(getuid()),
           let homePath = String(validatingUTF8: passwordEntry.pointee.pw_dir) {
            return URL(fileURLWithPath: homePath, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func defaultWallpaperDirectoryURL() -> URL {
        return realUserHomeDirectory().appendingPathComponent(defaultWallpaperDirectoryName, isDirectory: true)
    }

    func authorizeWallpaperDirectory(_ directoryURL: URL) -> Bool {
        do {
            let bookmarkData = try directoryURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: wallpaperDirectoryBookmarkKey)
            return true
        } catch {
            let nsError = error as NSError
            print("[WallpaperManager] Save bookmark failed: \(nsError.domain) \(nsError.code) - \(nsError.localizedDescription)")
            return false
        }
    }

    private func resolveAuthorizedWallpaperDirectory() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: wallpaperDirectoryBookmarkKey) else {
            return nil
        }

        var isStale = false
        do {
            let directoryURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                _ = authorizeWallpaperDirectory(directoryURL)
            }

            return directoryURL
        } catch {
            let nsError = error as NSError
            print("[WallpaperManager] Resolve bookmark failed: \(nsError.domain) \(nsError.code) - \(nsError.localizedDescription)")
            return nil
        }
    }

    func setWallpaper(wallpaper: Wallpaper, completion: @escaping (Result<Void, WallpaperError>) -> Void = { _ in }) {
        guard let url = URL(string: wallpaper.url) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }

        urlSession.dataTask(with: url) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(.network(error)))
                }
                return
            }

            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let data
            else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            guard NSImage(data: data) != nil else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidImageData))
                }
                return
            }

            self.saveWallpaperData(data, wallpaper: wallpaper) { result in
                switch result {
                case .success(let destination):
                    DispatchQueue.main.async {
                        self.applyWallpaper(at: destination, completion: completion)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }

    func downloadWallpaper(_ wallpaper: Wallpaper, completion: @escaping (Result<URL, WallpaperError>) -> Void) {
        guard let url = URL(string: wallpaper.url) else {
            DispatchQueue.main.async {
                completion(.failure(.invalidResponse))
            }
            return
        }

        urlSession.dataTask(with: url) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(.network(error)))
                }
                return
            }

            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let data
            else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidResponse))
                }
                return
            }

            guard NSImage(data: data) != nil else {
                DispatchQueue.main.async {
                    completion(.failure(.invalidImageData))
                }
                return
            }

            self.saveWallpaperData(data, wallpaper: wallpaper) { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }.resume()
    }

    private func saveWallpaperData(_ data: Data, wallpaper: Wallpaper, completion: @escaping (Result<URL, WallpaperError>) -> Void) {
        let fileManager = FileManager.default
        let wallpaperDirectory = self.resolveAuthorizedWallpaperDirectory() ?? self.defaultWallpaperDirectoryURL()
        let sanitizedID = wallpaper.id.replacingOccurrences(of: "/", with: "_")
        let fileName = sanitizedID.isEmpty ? UUID().uuidString : sanitizedID
        let destination = wallpaperDirectory.appendingPathComponent(fileName + ".jpg")
        let accessStarted = wallpaperDirectory.startAccessingSecurityScopedResource()

        defer {
            if accessStarted {
                wallpaperDirectory.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try fileManager.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
            print("[WallpaperManager] ✅ Wallpaper saved successfully")
            print("    Directory: \(wallpaperDirectory.path)")
            print("    File: \(destination.lastPathComponent)")
            print("    Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            completion(.success(destination))
        } catch {
            print("[WallpaperManager] ❌ Write failed")
            print("    Directory: \(wallpaperDirectory.path)")
            print("    File: \(destination.path)")
            completion(.failure(.writeFailed))
        }
    }

    private func applyWallpaper(at destination: URL, completion: @escaping (Result<Void, WallpaperError>) -> Void) {
        guard let screen = NSScreen.main else {
            completion(.failure(.noMainScreen))
            return
        }

        do {
            try NSWorkspace.shared.setDesktopImageURL(destination, for: screen, options: [:])
            completion(.success(()))
        } catch {
            completion(.failure(.applyFailed(error)))
        }
    }
}
