import Foundation

struct Wallpaper: Identifiable, Codable {
    let id: String
    let url: String
    let thumbUrl: String
    let localThumbUrl: String?
    let author: String
    let location: String?
}
