import Foundation

enum WallpaperError: LocalizedError {
    case network(Error)
    case invalidResponse
    case invalidImageData
    case noMainScreen
    case writeFailed
    case applyFailed(Error)

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Server returned an invalid response."
        case .invalidImageData:
            return "Downloaded data is not a valid image."
        case .noMainScreen:
            return "No main screen available."
        case .writeFailed:
            return "Failed to save wallpaper file locally."
        case .applyFailed(let error):
            return "Failed to apply wallpaper: \(error.localizedDescription)"
        }
    }
}
