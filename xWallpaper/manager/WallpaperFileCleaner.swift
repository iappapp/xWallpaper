import Foundation

final class WallpaperFileCleaner {
    static let shared = WallpaperFileCleaner()

    private static let retentionDays: TimeInterval = 3
    private static let cleanupInterval: TimeInterval = 24 * 60 * 60
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp"]
    private static let resourceKeys: Set<URLResourceKey> = [
        .contentModificationDateKey,
        .isDirectoryKey
    ]

    private let fileManager: FileManager
    private let wallpaperManager: WallpaperManager
    private let historyStore: WallpaperHistoryStore
    private let workQueue = DispatchQueue(label: "wallpaper.file.cleaner", qos: .utility)
    private var timer: Timer?

    init(
        fileManager: FileManager = .default,
        wallpaperManager: WallpaperManager = .shared,
        historyStore: WallpaperHistoryStore = .shared
    ) {
        self.fileManager = fileManager
        self.wallpaperManager = wallpaperManager
        self.historyStore = historyStore
    }

    func start() {
        runCleanup()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.cleanupInterval, repeats: true) { [weak self] _ in
            self?.runCleanup()
        }
        timer?.tolerance = 60 * 60
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func runCleanup() {
        workQueue.async { [weak self] in
            self?.removeExpiredWallpaperFiles()
        }
    }

    private func removeExpiredWallpaperFiles() {
        let cutoff = Date().addingTimeInterval(-Self.retentionDays * 24 * 60 * 60)
        var removedCount = 0

        for directory in wallpaperManager.wallpaperStorageDirectoryURLs() {
            removedCount += cleanDirectory(directory, olderThan: cutoff)
        }

        if removedCount > 0 {
            print("[WallpaperFileCleaner] Removed \(removedCount) wallpaper file(s) older than \(Int(Self.retentionDays)) days")
        }
    }

    private func cleanDirectory(_ directory: URL, olderThan cutoff: Date) -> Int {
        guard fileManager.fileExists(atPath: directory.path) else { return 0 }

        let accessStarted = directory.startAccessingSecurityScopedResource()
        defer {
            if accessStarted {
                directory.stopAccessingSecurityScopedResource()
            }
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return 0
        }

        var removedCount = 0

        for fileURL in contents {
            guard Self.imageExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }

            guard
                let values = try? fileURL.resourceValues(forKeys: Self.resourceKeys),
                values.isDirectory != true,
                let modified = values.contentModificationDate,
                modified < cutoff
            else {
                continue
            }

            do {
                try fileManager.removeItem(at: fileURL)
                removedCount += 1
                let storedName = fileURL.deletingPathExtension().lastPathComponent
                _ = historyStore.remove(matchingStoredFileName: storedName)
            } catch {
                print("[WallpaperFileCleaner] Failed to remove '\(fileURL.lastPathComponent)': \(error.localizedDescription)")
            }
        }

        return removedCount
    }
}
