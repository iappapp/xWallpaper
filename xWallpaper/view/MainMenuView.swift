import SwiftUI

enum MainMenuPage: String, CaseIterable {
    case random
    case history
    case category
    case settings

    var icon: String {
        switch self {
        case .random: return "photo"
        case .history: return "clock"
        case .category: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}

struct MainMenuView: View {
    private let panelWidth: CGFloat = 380
    private let panelHeight: CGFloat = 370
    private let headerHeight: CGFloat = 40

    @State private var selectedWallpaper: Wallpaper?
    @State private var wallpapers: [Wallpaper] = []
    @State private var historyWallpapers: [Wallpaper] = []
    @State private var categories: [Category] = []
    @AppStorage("mainMenu.currentPage") private var currentPageRawValue: String = MainMenuPage.settings.rawValue
    @AppStorage("selectedCategoryIds") private var selectedCategoryIdsString: String = "nature"
    @State private var isShuffling = false
    @State private var isApplyingWallpaper = false
    @State private var isDownloadingWallpaper = false
    @State private var randomWallpaperCached: Wallpaper?
    @State private var hasInitializedRandomWallpaper = false

    private var selectedCategoryIds: Set<String> {
        Set(selectedCategoryIdsString.split(separator: ",").map(String.init))
    }

    private var firstSelectedCategory: Category? {
        categories.first { selectedCategoryIds.contains($0.id) }
    }

    private var selectedCategories: [Category] {
        categories.filter { selectedCategoryIds.contains($0.id) }
    }

    private var currentPageHeight: CGFloat {
        panelHeight - headerHeight - 1
    }

    private var currentPage: MainMenuPage {
        MainMenuPage(rawValue: currentPageRawValue) ?? .random
    }

    private var currentPageBinding: Binding<MainMenuPage> {
        Binding(
            get: { currentPage },
            set: { currentPageRawValue = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBarView(currentPage: currentPageBinding, headerHeight: headerHeight)

            Divider()

            Group {
                switch currentPage {
                case .settings:
                    SettingsTabView()
                case .category:
                    CategoryTabView(
                        categories: categories,
                        onSelectChange: { _ in
                            refreshWallpapers(selectFirst: true)
                        }
                    )
                case .history:
                    HistoryTabView(
                        wallpapers: historyWallpapers,
                        selectedWallpaper: $selectedWallpaper,
                        onSelectWallpaper: handleHistoryWallpaperTap,
                        onDeleteWallpaper: removeHistory
                    )
                case .random:
                    RandomTabView(
                        wallpaper: randomWallpaperCached,
                        canSetWallpaper: randomWallpaperCached != nil && !isApplyingWallpaper,
                        isShuffling: isShuffling,
                        isDownloadingWallpaper: isDownloadingWallpaper,
                        onShuffle: handleShuffleTap,
                        onApplyWallpaper: applyRandomWallpaper,
                        onDownload: downloadRandomWallpaper
                    )
                }
            }
            .frame(height: currentPageHeight, alignment: .top)
        }
        .frame(width: panelWidth, height: panelHeight)
        .onAppear {
            categories = CategoryManager.shared.loadCategories()
            CategoryManager.shared.preloadCategoryThumbnails(categories)

            loadHistory()
            refreshWallpapers(selectFirst: false)

            if !hasInitializedRandomWallpaper {
                hasInitializedRandomWallpaper = true
                fetchRandomWallpaper()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wallpaperHistoryDidChange)) { _ in
            loadHistory()
        }
    }

    private func refreshWallpapers(selectFirst: Bool) {
        guard let selectedCategory = firstSelectedCategory else { return }
        UnsplashAPI.shared.fetchWallpapers(category: selectedCategory) { result in
            DispatchQueue.main.async {
                wallpapers = attachLocalThumbnailURLs(result)
                if selectFirst || selectedWallpaper == nil {
                    selectedWallpaper = wallpapers.first
                }
            }
        }
    }

    private func fetchRandomWallpaper() {
        UnsplashAPI.shared.fetchRandomWallpaper(selectedCategories: selectedCategories) { result in
            guard let result else { return }
            DispatchQueue.main.async {
                let hydrated = attachLocalThumbnailURL(result)
                randomWallpaperCached = hydrated
            }
        }
    }

    private func handleShuffleTap() {
        guard !isShuffling else { return }
        isShuffling = true

        fetchRandomWallpaperAvoidingDuplicate(previousID: randomWallpaperCached?.id) { result in
            DispatchQueue.main.async {
                defer { isShuffling = false }
                guard let result else { return }
                let hydrated = attachLocalThumbnailURL(result)

                withAnimation(.easeInOut(duration: 0.2)) {
                    randomWallpaperCached = hydrated
                }
            }
        }
    }

    private func fetchRandomWallpaperAvoidingDuplicate(previousID: String?, completion: @escaping (Wallpaper?) -> Void) {
        UnsplashAPI.shared.fetchRandomWallpaper(selectedCategories: selectedCategories) { first in
            guard
                let previousID,
                let first,
                first.id == previousID
            else {
                completion(first)
                return
            }

            UnsplashAPI.shared.fetchRandomWallpaper(selectedCategories: selectedCategories) { second in
                completion(second ?? first)
            }
        }
    }

    private func applyRandomWallpaper(_ wallpaper: Wallpaper) {
        guard !isApplyingWallpaper else { return }
        isApplyingWallpaper = true

        WallpaperManager.shared.setWallpaper(wallpaper: wallpaper) { result in
            isApplyingWallpaper = false

            switch result {
            case .success:
                addHistory(wallpaper)
            case .failure(let error):
                print("Failed to set wallpaper: \(error.localizedDescription)")
            }
        }
    }

    private func downloadRandomWallpaper(_ wallpaper: Wallpaper) {
        guard !isDownloadingWallpaper else { return }
        isDownloadingWallpaper = true

        WallpaperManager.shared.downloadWallpaper(wallpaper) { result in
            isDownloadingWallpaper = false

            switch result {
            case .success(let fileURL):
                print("Downloaded wallpaper to: \(fileURL.path)")
            case .failure(let error):
                print("Failed to download wallpaper: \(error.localizedDescription)")
            }
        }
    }

    private func handleHistoryWallpaperTap(_ wallpaper: Wallpaper) {
        let hydrated = attachLocalThumbnailURL(wallpaper)
        randomWallpaperCached = hydrated
        currentPageRawValue = MainMenuPage.random.rawValue
    }

    private func addHistory(_ wallpaper: Wallpaper) {
        historyWallpapers = WallpaperHistoryStore.shared.add(wallpaper)
    }

    private func removeHistory(_ wallpaper: Wallpaper) {
        historyWallpapers = WallpaperHistoryStore.shared.remove(wallpaper)
        WallpaperThumbCache.shared.removeThumbnail(for: wallpaper)
        WallpaperManager.shared.removeStoredWallpaperFile(for: wallpaper)

        if selectedWallpaper?.id == wallpaper.id {
            selectedWallpaper = historyWallpapers.first
        }

        if randomWallpaperCached?.id == wallpaper.id {
            randomWallpaperCached = nil
        }
    }

    private func loadHistory() {
        historyWallpapers = WallpaperHistoryStore.shared.load()
    }

    private func attachLocalThumbnailURLs(_ wallpapers: [Wallpaper]) -> [Wallpaper] {
        wallpapers.map(attachLocalThumbnailURL)
    }

    private func attachLocalThumbnailURL(_ wallpaper: Wallpaper) -> Wallpaper {
        Wallpaper(
            id: wallpaper.id,
            url: wallpaper.url,
            thumbUrl: wallpaper.thumbUrl,
            localThumbUrl: WallpaperThumbCache.shared.cachedThumbnailPath(for: wallpaper),
            author: wallpaper.author,
            location: wallpaper.location
        )
    }
}
