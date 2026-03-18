import Foundation

protocol WallpaperRandomProviding {
    func fetchRandomWallpaper(selectedCategories: [Category], completion: @escaping (Wallpaper?) -> Void)
}

protocol WallpaperApplying {
    func setWallpaper(wallpaper: Wallpaper, completion: @escaping (Result<Void, WallpaperError>) -> Void)
}

extension UnsplashAPI: WallpaperRandomProviding {}
extension WallpaperManager: WallpaperApplying {}

final class WallpaperRefreshScheduler {
    static let shared = WallpaperRefreshScheduler()

    private let updateFrequencyKey = "updateFrequency"
    private let selectedCategoryIdsKey = "selectedCategoryIds"

    private let userDefaults: UserDefaults
    private let categoryManager: CategoryManager
    private let api: WallpaperRandomProviding
    private let wallpaperApplier: WallpaperApplying
    private let historyStore: WallpaperHistoryStore

    private var timer: Timer?
    private var defaultsObserver: NSObjectProtocol?
    private var currentInterval: TimeInterval?
    private var currentCategoryIdsValue: String = ""

    private let inFlightLock = NSLock()
    private var inFlight = false

    init(
        userDefaults: UserDefaults = .standard,
        categoryManager: CategoryManager = .shared,
        api: WallpaperRandomProviding = UnsplashAPI.shared,
        wallpaperApplier: WallpaperApplying = WallpaperManager.shared,
        historyStore: WallpaperHistoryStore? = nil
    ) {
        self.userDefaults = userDefaults
        self.categoryManager = categoryManager
        self.api = api
        self.wallpaperApplier = wallpaperApplier
        self.historyStore = historyStore ?? WallpaperHistoryStore(userDefaults: userDefaults)
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        timer?.invalidate()
    }

    func start() {
        observeConfigChangesIfNeeded()
        scheduleFromConfig(force: true)
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
    }

    private func observeConfigChangesIfNeeded() {
        guard defaultsObserver == nil else { return }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleFromConfig(force: false)
        }
    }

    private func scheduleFromConfig(force: Bool) {
        let frequencyValue = userDefaults.string(forKey: updateFrequencyKey) ?? "Daily"
        let selectedCategoryIdsValue = userDefaults.string(forKey: selectedCategoryIdsKey) ?? "nature"
        let interval = Self.interval(for: frequencyValue)

        let shouldReschedule =
            force ||
            currentInterval != interval ||
            currentCategoryIdsValue != selectedCategoryIdsValue

        guard shouldReschedule else { return }

        currentInterval = interval
        currentCategoryIdsValue = selectedCategoryIdsValue

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshWallpaperIfNeeded()
        }
        timer?.tolerance = min(interval * 0.1, 60)

        refreshWallpaperIfNeeded()
        print("[WallpaperRefreshScheduler] Auto refresh scheduled every \(Int(interval))s")
    }

    private func refreshWallpaperIfNeeded() {
        guard beginRefreshing() else { return }

        let categories = selectedCategoriesFromConfig()

        api.fetchRandomWallpaper(selectedCategories: categories) { [weak self] wallpaper in
            guard let self else { return }
            guard let wallpaper else {
                self.endRefreshing()
                print("[WallpaperRefreshScheduler] Skip: no wallpaper fetched")
                return
            }

            self.wallpaperApplier.setWallpaper(wallpaper: wallpaper) { result in
                self.endRefreshing()
                switch result {
                case .success:
                    _ = self.historyStore.add(wallpaper)
                    print("[WallpaperRefreshScheduler] Wallpaper refreshed: \(wallpaper.id)")
                case .failure(let error):
                    print("[WallpaperRefreshScheduler] Refresh failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func selectedCategoriesFromConfig() -> [Category] {
        let idsValue = userDefaults.string(forKey: selectedCategoryIdsKey) ?? ""
        let selectedIds = Set(
            idsValue
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        guard !selectedIds.isEmpty else { return [] }

        let categories = categoryManager.loadCategories()
        return categories.filter { selectedIds.contains($0.id) }
    }

    private func beginRefreshing() -> Bool {
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    private func endRefreshing() {
        inFlightLock.lock()
        inFlight = false
        inFlightLock.unlock()
    }

    private static func interval(for frequency: String) -> TimeInterval {
        switch frequency.lowercased() {
        case "daily":
            return 60 * 60 * 24
        case "hourly":
            return 60 * 60
        case "30  minutes":
            return 30 * 60
        case "15 minutes":
            return 15 * 60
        case "1 minute":
            return 1 * 60
        default:
            return 60 * 60
        }
    }
}
