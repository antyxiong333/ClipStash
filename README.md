# ClipStash

A lightweight, always-on-top clipboard manager for macOS, built with Swift & SwiftUI.

macOS 原生粘贴板管理器，常驻窗口置顶，支持所有内容类型。

---

## Quick Install / 快速安装

1. Go to [Releases](https://github.com/antyxiong333/ClipStash/releases) and download the latest `ClipStash-Installer.dmg`
2. Open the DMG, drag `ClipStash.app` into `Applications`
3. Launch from Launchpad or Spotlight

前往 [Releases](https://github.com/antyxiong333/ClipStash/releases) 下载最新的 `ClipStash-Installer.dmg`，打开后将 ClipStash 拖入 Applications 即可。

> **First launch / 首次启动：** Grant **Accessibility** permission in System Settings > Privacy & Security > Accessibility for global hotkey support.
>
> 首次启动需在 **系统设置 > 隐私与安全 > 辅助功能** 中授权 ClipStash，才能使用全局快捷键。

---

## Features / 功能

### v1.0.0 - Clipboard Manager / 粘贴板管理

- **Always-on-top floating panel** / 浮动置顶窗口 — stays above all windows without stealing focus / 始终在最前面且不夺取焦点
- **Clipboard history** / 粘贴板历史 — automatically captures everything you copy / 自动记录所有复制内容
- **All content types** / 全类型支持 — text, rich text, images, files, URLs / 文本、富文本、图片、文件、链接
- **Click to re-copy** / 点击重新复制 — click any item to copy it back to clipboard / 点击历史条目即可重新复制
- **Search & filter** / 搜索过滤 — search by content, source app, or content type / 按内容、来源应用搜索
- **Pin items** / 置顶收藏 — star important items to keep them permanently / 星标重要内容防止被清理
- **Transparent mode** / 透明模式 — nearly invisible when idle, appears on hover / 默认高透明，鼠标悬浮时显现
- **Global hotkey** / 全局快捷键 — `Cmd+Shift+V` to toggle the panel / 显示/隐藏面板
- **Menu bar icon** / 菜单栏图标 — quick access from the system menu bar / 菜单栏快速访问
- **Persistent storage** / 持久化存储 — history saved to disk automatically / 历史记录自动保存

### v1.1.0 - Screenshot & Editor / 截图与编辑

- **Screenshot capture** / 截图功能 — uses system `screencapture` (same as `Cmd+Shift+4`) / 调用系统截图，体验一致
- **Screenshot editor** / 截图编辑器 — annotate with pen, arrow, rectangle, text / 画笔、箭头、矩形、文字标注
- **8 colors + line width** / 8 种颜色 + 线宽 — customizable annotation style / 自定义标注样式
- **Undo / Redo** / 撤销与重做 — full history stack for annotations / 完整的编辑历史
- **Inline text input** / 内联文字输入 — type directly on canvas, no popup dialog / 直接在画布上输入文字
- **Pin screenshot to screen** / 截图置顶浮动 — float a screenshot above all windows / 截图可作为浮动小窗常驻屏幕
- **DMG installer** / DMG 安装包 — drag-to-Applications installer / 拖拽安装
- **Light theme** / 浅色主题 — clean white UI, not affected by system dark mode / 纯白界面
- **Version display** / 版本号显示 — shown in menu bar dropdown / 菜单栏显示当前版本
- **Global hotkey** / 截图快捷键 — `Cmd+Ctrl+S` to take screenshot / 全局截图快捷键

### Known Issues / 已知问题

- **Screenshot may not capture foreground windows** — requires Screen Recording permission in System Settings > Privacy & Security > Screen & System Audio Recording. Even with permission, some apps may not be captured due to macOS restrictions.
  截图可能无法捕获前台窗口——需要在系统设置中授权屏幕录制权限。即使授权后，部分应用可能因 macOS 限制无法被截取。
- **Global hotkeys require Accessibility permission** — `Cmd+Shift+V` and `Cmd+Ctrl+S` won't work without Accessibility access.
  全局快捷键需要辅助功能权限才能生效。

---

## Requirements / 系统要求

- macOS 14.0 (Sonoma) or later
- Swift 5.9+

## Build from Source / 从源码构建

```bash
# Clone / 克隆
git clone https://github.com/antyxiong333/ClipStash.git
cd ClipStash

# Build app bundle / 构建 app
chmod +x build-app.sh
./build-app.sh

# Launch / 启动
open ClipStash.app

# Or create DMG installer / 或创建 DMG 安装包
chmod +x create-dmg.sh
./create-dmg.sh
```

## Usage / 使用

| Action / 操作 | Method / 方式 |
|---|---|
| Show/Hide panel / 显示隐藏面板 | `Cmd+Shift+V` or menu bar icon |
| Take screenshot / 截图 | `Cmd+Ctrl+S` or menu bar > Screenshot |
| Re-copy item / 重新复制 | Click any item in the list |
| Pin item / 收藏条目 | Click the star icon |
| Float image / 浮动显示图片 | Click the pin icon on image items |
| Search / 搜索 | Type in the search bar |

## Project Structure / 项目结构

```
ClipStash/
  App/
    ClipStashApp.swift              # App entry point / 应用入口
    AppDelegate.swift               # Menu bar, panel, hotkey / 菜单栏、面板、快捷键
  Models/
    ClipboardItem.swift             # Clipboard item model / 粘贴板条目模型
    ContentType.swift               # Content type enum / 内容类型枚举
  Services/
    ClipboardMonitor.swift          # Pasteboard polling / 粘贴板轮询监控
    ClipboardStore.swift            # Data store / 数据存储
    PasteboardReader.swift          # Content extraction / 内容提取
    PersistenceManager.swift        # JSON persistence / JSON 持久化
    ScreenCaptureService.swift      # Screenshot capture / 截图服务
  Views/
    FloatingPanel.swift             # NSPanel subclass / 浮动面板
    ClipboardListView.swift         # Main list view / 主列表视图
    ClipboardItemRow.swift          # Item row view / 条目行视图
    ScreenshotEditorView.swift      # Screenshot editor canvas / 截图编辑画布
    ScreenshotEditorWindow.swift    # Editor window / 编辑器窗口
    ScreenshotFloatingWindow.swift  # Pinned screenshot window / 截图浮动窗口
  Utilities/
    KeyboardShortcut.swift          # Global hotkeys / 全局快捷键
```

## Changelog / 更新日志

### v1.1.0 (2026-04-04)
- Added screenshot capture with system `screencapture` integration
- Added screenshot editor with pen, arrow, rectangle, text tools
- Added undo/redo for editor annotations
- Added inline text input on canvas
- Added screenshot floating window (pin to screen)
- Added DMG installer with drag-to-Applications layout
- Added light theme (forced `NSAppearance.aqua`)
- Added version display in menu bar
- Changed screenshot hotkey to `Cmd+Ctrl+S`
- Known: screenshot may only capture desktop wallpaper without Screen Recording permission

### v1.0.0 (2026-04-02)
- Initial release
- Clipboard history with all content types
- Always-on-top floating panel with transparent mode
- Search, pin, delete clipboard items
- Menu bar icon and global hotkey `Cmd+Shift+V`
- Persistent storage to `~/Library/Application Support/ClipStash/`

## License

MIT
