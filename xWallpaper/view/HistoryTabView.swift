import SwiftUI

struct HistoryTabView: View {
    let wallpapers: [Wallpaper]
    @Binding var selectedWallpaper: Wallpaper?
    let onSelectWallpaper: (Wallpaper) -> Void
    let onDeleteWallpaper: (Wallpaper) -> Void

    var body: some View {
        WallpaperGridView(
            wallpapers: wallpapers,
            selectedWallpaper: $selectedWallpaper,
            onSelect: onSelectWallpaper,
            onDelete: onDeleteWallpaper,
            fillsAvailableHeight: true,
            showsPlaceholdersWhenEmpty: true
        )
        .padding(.top, 8)
    }
}

#Preview("History Tab") {
    HistoryPreviewHost()
        .frame(width: 380, height: 320)
}
