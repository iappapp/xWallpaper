import Foundation

extension Notification.Name {
    static let wallpaperHistoryDidChange = Notification.Name("wallpaper.history.didChange")
}

final class WallpaperHistoryStore {
    static let shared = WallpaperHistoryStore()

    private let historyKey = "wallpaper.history.items"
    private let maxHistoryCount = 60
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> [Wallpaper] {
        guard
            let data = userDefaults.data(forKey: historyKey),
            let decoded = try? JSONDecoder().decode([Wallpaper].self, from: data)
        else {
            return []
        }

        return decoded
    }

    @discardableResult
    func remove(_ wallpaper: Wallpaper) -> [Wallpaper] {
        remove(id: wallpaper.id)
    }

    @discardableResult
    func remove(id: String) -> [Wallpaper] {
        var history = load()
        history.removeAll { $0.id == id }
        save(history)
        return history
    }

    @discardableResult
    func remove(matchingStoredFileName fileName: String) -> [Wallpaper] {
        var history = load()
        history.removeAll { wallpaper in
            let sanitizedID = wallpaper.id.replacingOccurrences(of: "/", with: "_")
            return sanitizedID == fileName || wallpaper.id == fileName
        }
        save(history)
        return history
    }

    @discardableResult
    func add(_ wallpaper: Wallpaper) -> [Wallpaper] {
        var history = load()
        history.removeAll { $0.id == wallpaper.id }
        history.insert(wallpaper, at: 0)

        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        save(history)
        return history
    }

    func save(_ wallpapers: [Wallpaper]) {
        guard let data = try? JSONEncoder().encode(wallpapers) else { return }
        userDefaults.set(data, forKey: historyKey)

        let postChange = {
            NotificationCenter.default.post(name: .wallpaperHistoryDidChange, object: nil)
        }

        if Thread.isMainThread {
            postChange()
        } else {
            DispatchQueue.main.async(execute: postChange)
        }
    }
}
