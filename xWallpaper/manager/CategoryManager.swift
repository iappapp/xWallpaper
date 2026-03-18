import Foundation

class CategoryManager {
    static let shared = CategoryManager()

    private let cacheKey = "categories.cache"
    private let fileManager = FileManager.default

    private lazy var cacheDirectoryURL: URL = {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let url = base.appendingPathComponent("Categories", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private let defaultCategories: [Category] = [
        Category(id: "nature", name: "Nature", query: "nature"),
        Category(id: "space", name: "Space", query: "space"),
        Category(id: "minimal", name: "Minimal", query: "minimal"),
        Category(id: "architecture", name: "Architecture", query: "architecture"),
        Category(id: "mountains", name: "Mountains", query: "mountains"),
        Category(id: "ocean", name: "Ocean", query: "ocean"),
        Category(id: "forest", name: "Forest", query: "forest"),
        Category(id: "city", name: "City", query: "city skyline"),
        Category(id: "animals", name: "Animals", query: "wildlife"),
        Category(id: "sunset", name: "Sunset", query: "sunset landscape")
    ]

    func loadCategories() -> [Category] {
        if let cached = loadCachedCategories() {
            return cached
        }

        // 首次使用或缓存失效，使用默认类别并保存
        saveCategories(defaultCategories)
        return defaultCategories
    }

    private func loadCachedCategories() -> [Category]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }

        do {
            let categories = try JSONDecoder().decode([Category].self, from: data)
            return categories.isEmpty ? nil : categories
        } catch {
            print("[CategoryManager] Failed to decode cached categories: \(error.localizedDescription)")
            return nil
        }
    }

    private func saveCategories(_ categories: [Category]) {
        do {
            let data = try JSONEncoder().encode(categories)
            UserDefaults.standard.set(data, forKey: cacheKey)
            print("[CategoryManager] Saved \(categories.count) categories to UserDefaults")
            print("Key: \(cacheKey)")
            print("Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        } catch {
            print("[CategoryManager] Failed to save categories: \(error.localizedDescription)")
        }
    }

    func preloadCategoryThumbnails(_ categories: [Category]) {
        for category in categories {
            // 异步预加载缩略图，但不阻塞主线程
            DispatchQueue.global(qos: .background).async {
                if CategoryThumbCache.shared.cachedThumbnailURL(for: category) == nil {
                    CategoryThumbCache.shared.loadThumbnail(for: category) { _ in }
                }
            }
        }
    }
}
