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

        let pickedCategory = selectedCategories.randomElement()
        let pickedQuery = pickedCategory?.query.trimmingCharacters(in: .whitespacesAndNewlines)

        var components = URLComponents(string: "https://api.unsplash.com/photos/random")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "orientation", value: "landscape"),
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
            guard let data = data else {
                completion(nil)
                return
            }

            let photo = try? JSONDecoder().decode(UnsplashPhoto.self, from: data)
            completion(photo.map(Self.mapRandomPhoto))
        }.resume()
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
