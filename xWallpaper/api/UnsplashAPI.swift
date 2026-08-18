import Foundation

class UnsplashAPI {
    static let shared = UnsplashAPI()
    private var accessKey: String {
        UserDefaults.standard
            .string(forKey: "unsplashAccessKey")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

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

    // Random wallpaper batch cache: fetch count=10 once, serve one at a time,
    // refill only when the batch is exhausted. Reduces API calls / rate limiting.
    private let batchLock = NSLock()
    private var randomBatch: [Wallpaper] = []
    private var batchCategoryKey: String = ""
    private var batchInFlight = false
    private var pendingBatchCompletions: [(Wallpaper?) -> Void] = []

    func fetchWallpapers(category: Category, completion: @escaping ([Wallpaper]) -> Void) {
        guard !accessKey.isEmpty else {
            completion([])
            return
        }

        var components = URLComponents(string: "https://api.unsplash.com/search/photos")
        components?.queryItems = [
            URLQueryItem(name: "query", value: category.query),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "per_page", value: "12"),
            URLQueryItem(name: "client_id", value: accessKey)
        ]

        guard let url = components?.url else { completion([]); return }

        urlSession.dataTask(with: url) { data, _, _ in
            guard let data = data else { completion([]); return }
            let result = try? JSONDecoder().decode(UnsplashResult.self, from: data)
            completion(result?.results.map(Self.mapPhoto) ?? [])
        }.resume()
    }

    func fetchRandomWallpaper(completion: @escaping (Wallpaper?) -> Void) {
        fetchRandomWallpaper(selectedCategories: [], completion: completion)
    }

    func fetchRandomWallpaper(selectedCategories: [Category], completion: @escaping (Wallpaper?) -> Void) {
        guard !accessKey.isEmpty else {
            completion(nil)
            return
        }

        let categoryKey = Self.categoryKey(for: selectedCategories)

        batchLock.lock()
        // Invalidate cached batch when the selected categories change.
        if batchCategoryKey != categoryKey {
            randomBatch.removeAll()
            batchCategoryKey = categoryKey
        }

        if let cached = randomBatch.popLast() {
            batchLock.unlock()
            completion(cached)
            return
        }

        // Batch exhausted — queue this request and fetch a fresh batch (once).
        pendingBatchCompletions.append(completion)
        let shouldFetch = !batchInFlight
        batchInFlight = true
        batchLock.unlock()

        guard shouldFetch else { return }

        fetchRandomBatch(selectedCategories: selectedCategories) { [weak self] batch in
            guard let self else { return }

            self.batchLock.lock()
            self.randomBatch = batch ?? []
            self.batchInFlight = false
            let completions = self.pendingBatchCompletions
            self.pendingBatchCompletions.removeAll()
            self.batchLock.unlock()

            // Serve every waiting caller one wallpaper from the freshly fetched batch.
            for callback in completions {
                self.batchLock.lock()
                let wp = self.randomBatch.popLast()
                self.batchLock.unlock()
                callback(wp)
            }
        }
    }

    private func fetchRandomBatch(selectedCategories: [Category], completion: @escaping ([Wallpaper]?) -> Void) {
        let pickedCategory = selectedCategories.randomElement()
        let pickedQuery = pickedCategory?.query.trimmingCharacters(in: .whitespacesAndNewlines)

        var components = URLComponents(string: "https://api.unsplash.com/photos/random")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "count", value: "10"),
            URLQueryItem(name: "client_id", value: accessKey)
        ]

        if let query = pickedQuery, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion(nil)
            return
        }

        urlSession.dataTask(with: url) { data, _, _ in
            guard let data else {
                completion(nil)
                return
            }

            // With count>1 the response is a JSON array of photos.
            let photos = try? JSONDecoder().decode([UnsplashPhoto].self, from: data)
            completion(photos?.map(Self.mapRandomPhoto))
        }.resume()
    }

    private static func categoryKey(for categories: [Category]) -> String {
        categories.map { $0.id }.sorted().joined(separator: ",")
    }

    func fetchCategoryThumbnail(for category: Category, completion: @escaping (String?) -> Void) {
        guard !accessKey.isEmpty else {
            completion(nil)
            return
        }

        var components = URLComponents(string: "https://api.unsplash.com/search/photos")
        components?.queryItems = [
            URLQueryItem(name: "query", value: category.query),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "per_page", value: "1"),
            URLQueryItem(name: "client_id", value: accessKey)
        ]

        guard let url = components?.url else { completion(nil); return }

        urlSession.dataTask(with: url) { data, _, _ in
            guard let data = data else { completion(nil); return }
            let result = try? JSONDecoder().decode(UnsplashResult.self, from: data)
            let thumbUrl = result?.results.first?.urls.thumb
            completion(thumbUrl)
        }.resume()
    }

    private static func mapPhoto(_ photo: UnsplashPhoto) -> Wallpaper {
        Wallpaper(
            id: photo.id,
            url: photo.urls.full,
            thumbUrl: photo.urls.thumb,
            localThumbUrl: nil,
            author: photo.user.name,
            location: photo.location?.name
        )
    }

    private static func mapRandomPhoto(_ photo: UnsplashPhoto) -> Wallpaper {
        Wallpaper(
            id: photo.id,
            url: photo.urls.full,
            thumbUrl: photo.urls.regular ?? photo.urls.small ?? photo.urls.thumb,
            localThumbUrl: nil,
            author: photo.user.name,
            location: photo.location?.name
        )
    }
}

struct UnsplashResult: Codable {
    let results: [UnsplashPhoto]
}

struct UnsplashPhoto: Codable {
    let id: String
    let urls: UnsplashURLs
    let user: UnsplashUser
    let location: UnsplashLocation?
}

struct UnsplashURLs: Codable {
    let full: String
    let regular: String?
    let small: String?
    let thumb: String
}
struct UnsplashUser: Codable {
    let name: String
}
struct UnsplashLocation: Codable {
    let name: String?
}
