# xWallpaper

一个基于 **SwiftUI + AppKit** 的 macOS 菜单栏壁纸工具。  
应用常驻在状态栏，通过 Popover 面板提供随机壁纸、历史壁纸、类别浏览和设置页。

---

## 1. 项目简介

xWallpaper 是一个轻量的 macOS 壁纸应用，核心目标是：

- 快速获取 Unsplash 壁纸
- 一键将当前图片设置为系统桌面壁纸
- 提供历史记录与类别切换
- 以菜单栏 Popover 形式呈现，减少打扰

应用入口不是传统主窗口，而是状态栏图标触发的弹出面板。

---

## 2. 主要功能

### 2.1 随机壁纸视图（Random）
- 展示当前壁纸大图（`AsyncImage`）
- 中央旋转按钮用于拉取下一张随机图
- 点击 **Set as Wallpaper** 将当前图设为桌面壁纸
- 随机拉取过程中显示加载状态并防止重复点击

### 2.2 历史图片视图（History）
- 3 列滚动缩略图网格
- 空数据时展示 12 个占位图
- 点击某个缩略图可设为当前选中图
- 历史数据持久化在 `UserDefaults`

### 2.3 类别视图（Category）
- 3 列类别卡片布局
- 类别卡片含封面图（来自 Unsplash Source 占位 URL）、左下角标题、选中态勾选
- 选择类别后会触发该类别下的图片搜索

### 2.4 设置视图（Settings）
- 启动项、更新策略、下载目录等设置项展示
- 包含反馈入口文案、版本信息和退出按钮
- 使用 `@AppStorage` 保存设置项

---

## 3. 关键特性

- **菜单栏应用形态**：状态栏图标 + Popover
- **多页面统一容器**：Header + 4 Tab 页面
- **异步网络请求**：URLSession + Codable 解码
- **壁纸设置稳健性增强**：
  - HTTP 状态码校验
  - 图片数据有效性校验
  - 文件原子写入
  - 错误类型分层（网络、响应、写入、应用失败等）
- **历史记录去重 + 截断**：避免无限增长

---

## 4. 代码目录与职责

```text
xWallpaper/
├── Assets.xcassets/                     # App 图标与资源
├── xWallpaper/
│   ├── xWallpaperApp.swift              # App 入口（SwiftUI App）
│   ├── AppDelegate.swift                # 状态栏图标与 Popover 管理
│   ├── NSStatusItem.swift               # 状态栏相关辅助（预留/扩展）
│   ├── xWallpaper.entitlements          # 沙盒权限配置（含网络权限）
│   ├── manager/
│   │   ├── UnsplashAPI.swift            # Unsplash 请求与模型映射
│   │   └── WallpaperManager.swift       # 下载图片并设置系统桌面
│   ├── model/
│   │   ├── Wallpaper.swift              # 壁纸数据模型
│   │   └── Category.swift               # 类别数据模型
│   └── view/
│       ├── MainMenuView.swift           # 主容器：状态、路由、业务编排
│       ├── MainMenuHeaderBarView.swift  # 顶部标题+切换按钮
│       ├── RandomTabView.swift          # 随机页
│       ├── HistoryTabView.swift         # 历史页
│       ├── CategoryTabView.swift        # 类别页
│       ├── SettingsTabView.swift        # 设置页容器
│       ├── CategoryView.swift           # 类别卡片网格
│       ├── WallpaperGridView.swift      # 通用壁纸缩略图网格
│       └── SettingsView.swift           # 设置页具体内容
├── xWallpaper.xcodeproj/                # Xcode 工程
├── xWallpaperTests/                     # 单元测试
└── xWallpaperUITests/                   # UI 测试
```

---

## 5. 核心流程说明

### 5.1 随机换图流程
1. `RandomTabView` 点击旋转按钮，触发 `onShuffle`
2. `MainMenuView.handleShuffleTap()` 调用 `UnsplashAPI.fetchRandomWallpaper`
3. 请求成功后更新 `selectedWallpaper`
4. UI 自动刷新展示新图

### 5.2 设置壁纸流程
1. 点击 `Set as Wallpaper`
2. `MainMenuView.applyWallpaper(_:)` 调用 `WallpaperManager.setWallpaper`
3. `WallpaperManager` 下载图片并写入 `~/.xWallpaper/`（当前实现）
4. 使用 `NSWorkspace.setDesktopImageURL` 设置桌面
5. 成功后写入历史记录

### 5.3 类别拉取流程
1. 在 `CategoryView` 选中类别
2. `MainMenuView.refreshWallpapers(selectFirst:)` 调用 `UnsplashAPI.fetchWallpapers(category:)`
3. 解析结果后更新 `wallpapers` 与当前选中图

---

## 6. 本地运行

### 6.1 环境要求
- macOS
- Xcode 15+
- Swift 5+

### 6.2 启动方式
1. 用 Xcode 打开 `xWallpaper.xcodeproj`
2. 选择 scheme：`xWallpaper`
3. 运行（`Run`）
4. 在系统状态栏找到应用图标并打开面板

---

## 7. 配置说明

### 7.1 Unsplash Key
在 `xWallpaper/manager/UnsplashAPI.swift` 中：

- `accessKey = "..."`

建议将 Key 移出源码（如 `.xcconfig` 或环境注入），避免泄露。

### 7.2 权限
在 `xWallpaper/xWallpaper.entitlements` 中：
- `com.apple.security.app-sandbox`
- `com.apple.security.network.client`

若请求失败但浏览器正常，请优先检查沙盒与网络权限。

---

## 8. 当前已实现的稳定性优化

- 防止重复点击触发并发请求（随机与设置壁纸）
- 设置壁纸失败不再静默，提供明确错误类型
- 图片下载后校验有效性，避免损坏文件导致设置失败

---

## 9. 后续可优化方向

- 设置页真正接入“启动自启/下载目录选择”系统能力
- 增加网络失败的 UI 提示（Toast/Alert）
- 历史记录增加时间戳、分页与清理策略
- 将 Unsplash Key 改为安全配置管理
- 增加更多单元测试与 UI 自动化测试

---

## 10. 免责声明

本项目的图片数据来自 Unsplash API。请在生产使用中遵守 Unsplash API 使用条款与图片版权规范。
