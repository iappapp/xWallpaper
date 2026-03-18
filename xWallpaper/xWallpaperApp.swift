//
//  xWallpaperApp.swift
//  xWallpaper
//
//  Created by mac on 2026/2/2.
//

import SwiftUI

@main
struct xWallpaperApp: App {
    // 适配传统的 AppDelegate 来管理菜单栏
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}
