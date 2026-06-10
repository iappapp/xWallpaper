import SwiftUI

enum PreviewData {
    static let categories: [Category] = [
        Category(id: "nature", name: "Nature", query: "nature"),
        Category(id: "space", name: "Space", query: "space"),
        Category(id: "minimal", name: "Minimal", query: "minimal"),
        Category(id: "architecture", name: "Architecture", query: "architecture"),
        Category(id: "mountains", name: "Mountains", query: "mountains"),
        Category(id: "ocean", name: "Ocean", query: "ocean")
    ]

    static let wallpapers: [Wallpaper] = [
        Wallpaper(
            id: "wall-001",
            url: "https://images.unsplash.com/photo-1469474968028-56623f02e42e",
            thumbUrl: "https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800",
            localThumbUrl: nil,
            author: "Alex Green",
            location: "Iceland"
        ),
        Wallpaper(
            id: "wall-002",
            url: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee",
            thumbUrl: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800",
            localThumbUrl: nil,
            author: "Jane Doe",
            location: "Yosemite"
        ),
        Wallpaper(
            id: "wall-003",
            url: "https://images.unsplash.com/photo-1470770903676-69b98201ea1c",
            thumbUrl: "https://images.unsplash.com/photo-1470770903676-69b98201ea1c?w=800",
            localThumbUrl: nil,
            author: "Mark Blue",
            location: "Dolomites"
        ),
        Wallpaper(
            id: "wall-004",
            url: "https://images.unsplash.com/photo-1482192596544-9eb780fc7f66",
            thumbUrl: "https://images.unsplash.com/photo-1482192596544-9eb780fc7f66?w=800",
            localThumbUrl: nil,
            author: "Chris North",
            location: "Alps"
        ),
        Wallpaper(
            id: "wall-005",
            url: "https://images.unsplash.com/photo-1493244040629-496f6d136cc3",
            thumbUrl: "https://images.unsplash.com/photo-1493244040629-496f6d136cc3?w=800",
            localThumbUrl: nil,
            author: "Mia Lake",
            location: "Norway"
        ),
        Wallpaper(
            id: "wall-006",
            url: "https://images.unsplash.com/photo-1506744038136-46273834b3fb",
            thumbUrl: "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800",
            localThumbUrl: nil,
            author: "Noah West",
            location: "Canada"
        )
    ]

    static let randomWallpaper: Wallpaper = wallpapers[0]
}

struct WallpaperSelectionPreviewHost: View {
    @State private var selectedWallpaper: Wallpaper?

    private let wallpapers: [Wallpaper]
    private let fillsAvailableHeight: Bool
    private let showsPlaceholdersWhenEmpty: Bool

    init(wallpapers: [Wallpaper], fillsAvailableHeight: Bool = false, showsPlaceholdersWhenEmpty: Bool = false) {
        self.wallpapers = wallpapers
        self.fillsAvailableHeight = fillsAvailableHeight
        self.showsPlaceholdersWhenEmpty = showsPlaceholdersWhenEmpty
    }

    var body: some View {
        WallpaperGridView(
            wallpapers: wallpapers,
            selectedWallpaper: $selectedWallpaper,
            onSelect: nil,
            fillsAvailableHeight: fillsAvailableHeight,
            showsPlaceholdersWhenEmpty: showsPlaceholdersWhenEmpty
        )
    }
}

struct HistoryPreviewHost: View {
    @State private var selectedWallpaper: Wallpaper?

    var body: some View {
        HistoryTabView(
            wallpapers: PreviewData.wallpapers,
            selectedWallpaper: $selectedWallpaper,
            onSelectWallpaper: { _ in }
        )
    }
}

struct HeaderPreviewHost: View {
    @State private var currentPage: MainMenuPage = .random

    var body: some View {
        HeaderBarView(currentPage: $currentPage, headerHeight: 50)
    }
}

struct CategoryPreviewHost: View {
    @State private var selectedCategoryIds: Set<String> = ["nature"]

    var body: some View {
        CategoryView(
            categories: PreviewData.categories,
            onSelectChange: { _ in }
        )
    }
}
