import SwiftUI

struct RandomTabView: View {
    let wallpaper: Wallpaper?
    let canSetWallpaper: Bool
    let isShuffling: Bool
    let isDownloadingWallpaper: Bool
    let onShuffle: () -> Void
    let onApplyWallpaper: (Wallpaper) -> Void
    let onDownload: (Wallpaper) -> Void

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
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .clipped()

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.gray.opacity(0.45), lineWidth: 1)

                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        
                        Button {
                            guard let wallpaper else { return }
                            onApplyWallpaper(wallpaper)
                        } label: {
                            Text("Set as Wallpaper")
                                .font(.system(size: 40 / 2, weight: .semibold))
                                .foregroundColor(.primary.opacity(canSetWallpaper ? 0.78 : 0.45))
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .disabled(!canSetWallpaper || wallpaper == nil)
                        
                    }
                    .padding(.horizontal, 20)    
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, minHeight:20)
            .padding(.horizontal, 10)
            .padding(.top, 15)

            Spacer()
            HStack (spacing: 12) {
                        if let wallpaper {
                            Text("By \(wallpaper.author)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Spacer()

                        Button {
                            guard let wallpaper else { return }
                            onDownload(wallpaper)
                        } label: {
                            HStack(spacing: 6) {
                                Text(isDownloadingWallpaper ? "Downloading..." : "Download")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(wallpaper == nil || isDownloadingWallpaper)
                    }
                    .padding(.horizontal, 10)
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
        isDownloadingWallpaper: false,
        onShuffle: {},
        onApplyWallpaper: { _ in },
        onDownload: { _ in }
    )
    .frame(width: 380, height: 320)
}

#Preview("Random Tab - Loading") {
    RandomTabView(
        wallpaper: nil,
        canSetWallpaper: false,
        isShuffling: true,
        isDownloadingWallpaper: false,
        onShuffle: {},
        onApplyWallpaper: { _ in },
        onDownload: { _ in }
    )
    .frame(width: 380, height: 320)
}
