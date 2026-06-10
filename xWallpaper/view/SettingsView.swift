import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("launchOnStartup") var launchOnStartup = false
    @AppStorage("updateAllScreens") var updateAllScreens = false
    @AppStorage("updateFrequency") var updateFrequency = "Daily"
    @AppStorage("downloadLocation") var downloadLocation = "~/Downloads"
    @AppStorage("unsplashAccessKey") var unsplashAccessKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 14) {
                Toggle("Launch on system startup", isOn: $launchOnStartup)
                    .toggleStyle(.checkbox)

                Toggle("Update all screens and desktops", isOn: $updateAllScreens)
                    .toggleStyle(.checkbox)

                HStack {
                    Text("Update Frequency")
                    Picker("", selection: $updateFrequency) {
                        Text("Daily").tag("Daily")
                        Text("Hourly").tag("Hourly")
                        Text("30 Minutes").tag("30 Minutes")
                        Text("15 Minutes").tag("15 Minutes")
                        Text("1 Minute").tag("1 Minute")
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                HStack(spacing: 10) {
                    Text("Download Location")
                    Text(downloadLocation)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.primary.opacity(0.9))
                    Button {
                        openDownloadDirectory()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 50) {
                    Button("Change") {
                        chooseDownloadDirectory()
                    }
                    .buttonStyle(.bordered)

                    Button("Set Default") {
                         downloadLocation = "~/Downloads" 
                         }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 8) {
                    Text("Unsplash API Key")
                    TextField("Enter your Unsplash Access Key", text: $unsplashAccessKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .font(.system(size: 18, weight: .medium))
            .padding(.top, 10)

            Spacer(minLength: 2)


            HStack {
                Text("v2025.02.1 (54)")
                Spacer()
                Button("Quit Unsplash Wallpapers") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.showsHiddenFiles = true
        panel.message = "Select an authorized wallpaper directory (recommended: ~/.xWallpaper)"
        panel.directoryURL = URL(fileURLWithPath: downloadLocation.replacingOccurrences(of: "~", with: NSHomeDirectory()))

        let handleSelection: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            _ = WallpaperManager.shared.authorizeWallpaperDirectory(url)
            downloadLocation = url.path
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: handleSelection)
        } else {
            panel.begin(completionHandler: handleSelection)
        }
    }

    private func openDownloadDirectory() {
        let path = downloadLocation.replacingOccurrences(of: "~", with: NSHomeDirectory())
        let url = URL(fileURLWithPath: path)
        
        let fileManager = FileManager.default
        
        // 创建目录（如果不存在）
        if !fileManager.fileExists(atPath: url.path) {
            return
        }
        
        // 首先尝试授权目录（如果之前授权过会直接返回）
        _ = WallpaperManager.shared.authorizeWallpaperDirectory(url)
        
        // 启用安全作用域访问再打开
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            NSWorkspace.shared.open(url)
        } else {
            // 如果安全作用域失败，直接尝试打开（本地路径通常不需要）
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .frame(width: 380, height: 320)
}
