import SwiftUI

struct RandomTabView: View {
    let wallpaper: Wallpaper?
    let canSetWallpaper: Bool
    let isShuffling: Bool
    let onShuffle: () -> Void
    let onApplyWallpaper: (Wallpaper) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let wallpaper {
                    RandomWallpaperPreview(wallpaper: wallpaper)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.16))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 34, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.7))
                        )
                }
            }
            .overlay {
                Button(action: onShuffle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.32))

                        if isShuffling {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.1)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 45, weight: .regular))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 64, height: 64)
                }
                .buttonStyle(.plain)
                .disabled(isShuffling)
            }
            .frame(height: 250)
            .frame(maxWidth: .infinity)
            .clipped()

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.gray.opacity(0.45), lineWidth: 1)

                HStack (spacing: 20){
                    Spacer()
                    Button {
                        guard let wallpaper else { return }
                        onApplyWallpaper(wallpaper)
                    } label: {
                        Text("Set as Wallpaper")
                            .font(.system(size: 42 / 2, weight: .semibold))
                            .foregroundColor(.primary.opacity(canSetWallpaper ? 0.78 : 0.45))
                            .frame(maxWidth: .infinity, minHeight: 20)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSetWallpaper || wallpaper == nil)
                    Spacer()
                }
                
            }
            .frame(maxWidth: .infinity, minHeight:20)
            .padding(.horizontal, 1)
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct RandomWallpaperPreview: View {
    let wallpaper: Wallpaper
    @State private var localImage: NSImage?

    var body: some View {
        Group {
            if let localImage {
                Image(nsImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.gray.opacity(0.16))
            }
        }
        .task(id: "\(wallpaper.id)-\(wallpaper.thumbUrl)") {
            localImage = nil

            if let cached = WallpaperThumbCache.shared.cachedThumbnailURL(for: wallpaper) {
                localImage = NSImage(contentsOf: cached)
                return
            }

            WallpaperThumbCache.shared.loadThumbnail(for: wallpaper) { url in
                DispatchQueue.main.async {
                    guard let url else {
                        localImage = nil
                        return
                    }
                    localImage = NSImage(contentsOf: url)
                }
            }
        }
    }
}

#Preview("Random Tab - Ready") {
    RandomTabView(
        wallpaper: PreviewData.randomWallpaper,
        canSetWallpaper: true,
        isShuffling: false,
        onShuffle: {},
        onApplyWallpaper: { _ in }
    )
    .frame(width: 380, height: 320)
}

#Preview("Random Tab - Loading") {
    RandomTabView(
        wallpaper: nil,
        canSetWallpaper: false,
        isShuffling: true,
        onShuffle: {},
        onApplyWallpaper: { _ in }
    )
    .frame(width: 380, height: 320)
}
