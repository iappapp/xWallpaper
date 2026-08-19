import SwiftUI

struct WallpaperGridView: View {
    let wallpapers: [Wallpaper]
    @Binding var selectedWallpaper: Wallpaper?
    var onSelect: ((Wallpaper) -> Void)? = nil
    var onDelete: ((Wallpaper) -> Void)? = nil
    var fillsAvailableHeight: Bool = false
    var showsPlaceholdersWhenEmpty: Bool = false
    private let placeholderCount = 12

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private var gridSpacing: CGFloat {
        8
    }

    private var tileHeight: CGFloat {
        80
    }

    private var horizontalPadding: CGFloat {
        10
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                if wallpapers.isEmpty && showsPlaceholdersWhenEmpty {
                    ForEach(0..<placeholderCount, id: \.self) { _ in
                        placeholderTile
                    }
                } else {
                    ForEach(wallpapers) { wallpaper in
                        wallpaperTile(wallpaper)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: fillsAvailableHeight ? .infinity : 190)
    }

    @ViewBuilder
    private func wallpaperTile(_ wallpaper: Wallpaper) -> some View {
        let isSelected = selectedWallpaper?.id == wallpaper.id
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)

        ZStack {
            Color.gray.opacity(0.22)

            WallpaperThumbnailImageView(wallpaper: wallpaper)
        }
        .frame(maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight)
        .clipShape(shape)
        .overlay(shape.stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        .shadow(color: isSelected ? Color.black.opacity(0.12) : Color.clear, radius: 3, x: 0, y: 1)
        .contentShape(shape)
        .onTapGesture {
            selectedWallpaper = wallpaper
            onSelect?(wallpaper)
        }
        .contextMenu {
            if let onDelete {
                Button("Delete", role: .destructive) {
                    onDelete(wallpaper)
                }
            }
        }
    }

    private var placeholderTile: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)

        return ZStack {
            Color.gray.opacity(0.14)
            Image(systemName: "photo")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary.opacity(0.65))
        }
        .frame(maxWidth: .infinity, minHeight: tileHeight, maxHeight: tileHeight)
        .clipShape(shape)
    }
}

private struct WallpaperThumbnailImageView: View {
    let wallpaper: Wallpaper

    @State private var localImage: NSImage?

    var body: some View {
        Color.gray.opacity(0.18)
            .overlay(
                Group {
                    if let localImage {
                        Image(nsImage: localImage)
                            .resizable()
                            .scaledToFill()
                    }
                }
            )
            .clipped()
            .task(id: wallpaper.id) {
                if let cached = WallpaperThumbCache.shared.cachedThumbnailURL(for: wallpaper) {
                    localImage = NSImage(contentsOf: cached)
                    return
                }

                WallpaperThumbCache.shared.loadThumbnail(for: wallpaper) { url in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        localImage = NSImage(contentsOf: url)
                    }
                }
            }
    }
}

#Preview("Wallpaper Grid") {
    WallpaperSelectionPreviewHost(wallpapers: PreviewData.wallpapers)
        .frame(width: 380, height: 380)
}

#Preview("Wallpaper Grid - Empty") {
    WallpaperSelectionPreviewHost(
        wallpapers: [],
        fillsAvailableHeight: true,
        showsPlaceholdersWhenEmpty: true
    )
    .frame(width: 380, height: 380)
}
