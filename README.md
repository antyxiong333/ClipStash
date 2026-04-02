# ClipStash

A lightweight, always-on-top clipboard manager for macOS, built with Swift & SwiftUI.

macOS 原生粘贴板管理器，常驻窗口置顶，支持所有内容类型。

---

## Features / 功能

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

## Requirements / 系统要求

- macOS 14.0 (Sonoma) or later
- Swift 5.9+

## Build / 构建

```bash
# Clone the repo / 克隆仓库
git clone git@github.com:antyxiong333/ClipStash.git
cd ClipStash

# Build and create .app bundle / 构建并打包
chmod +x build-app.sh
./build-app.sh

# Launch / 启动
open ClipStash.app
```

Or build manually / 或手动构建:

```bash
swift build -c release
```

## Usage / 使用

1. Launch `ClipStash.app` — a clipboard icon appears in the menu bar / 启动后菜单栏出现剪贴板图标
2. The floating panel appears at the top-right of your screen / 浮动面板出现在屏幕右上角
3. Copy anything in any app — it shows up in ClipStash automatically / 在任意应用复制内容，自动出现在列表中
4. Click an item to re-copy it / 点击条目重新复制
5. Use `Cmd+Shift+V` to show/hide the panel / 使用快捷键显示/隐藏

> **Note:** Grant Accessibility permission in System Settings > Privacy & Security > Accessibility for global hotkey support.
>
> **注意：** 需在系统设置 > 隐私与安全 > 辅助功能中授权，才能使用全局快捷键。

## Project Structure / 项目结构

```
ClipStash/
  App/
    ClipStashApp.swift          # App entry point / 应用入口
    AppDelegate.swift           # Menu bar, panel, hotkey / 菜单栏、面板、快捷键
  Models/
    ClipboardItem.swift         # Clipboard item model / 粘贴板条目模型
    ContentType.swift           # Content type enum / 内容类型枚举
  Services/
    ClipboardMonitor.swift      # Pasteboard polling / 粘贴板轮询监控
    ClipboardStore.swift        # Data store / 数据存储
    PasteboardReader.swift      # Content extraction / 内容提取
    PersistenceManager.swift    # JSON persistence / JSON 持久化
  Views/
    FloatingPanel.swift         # NSPanel subclass / 浮动面板
    ClipboardListView.swift     # Main list view / 主列表视图
    ClipboardItemRow.swift      # Item row view / 条目行视图
  Utilities/
    KeyboardShortcut.swift      # Global hotkey / 全局快捷键
```

## License

MIT
