# ClipStash

A lightweight, always-on-top clipboard manager for macOS, built with Swift & SwiftUI.

macOS 原生粘贴板管理器，常驻窗口置顶，支持所有内容类型。

---

## Quick Install / 快速安装

### Build locally now / 当前推荐：本地构建

```bash
git clone https://github.com/antyxiong333/ClipStash.git
cd ClipStash
./build-app.sh
cp -R ClipStash.app /Applications/
open /Applications/ClipStash.app
```

The existing v1.1.0 DMG is a legacy unsigned build and is blocked by Gatekeeper on a clean Mac. A one-click DMG download will be restored after a **Developer ID Application** certificate and Apple notarization are configured.

现有 v1.1.0 DMG 是旧的未签名版本，在全新 Mac 上会被 Gatekeeper 拦截。配置 **Developer ID Application** 证书并完成 Apple 公证后，再恢复可直接下载的 DMG。

> **Screenshots / 截图权限：** Open Settings (gear icon) > Screen Recording > Open System Settings. Allow the copy of ClipStash you are running, then quit and reopen it.
>
> 打开齿轮设置 > Screen Recording > Open System Settings，在系统设置的「隐私与安全 > 屏幕与系统音频录制」中允许当前这份 ClipStash，然后退出并重新打开。全局快捷键无需辅助功能权限。

---

## Features / 功能

### v1.4.27 - Live Captions, Local AI & Display Language / 实时字幕、本地 AI 与界面语言

- **Live caption translation** / 实时字幕翻译：source and target captions remain paired to the same recognized-speech snapshot; the fast path only submits meaningful speech segments and drops obsolete partial work / 原文与译文始终显示同一份语音识别快照；快速路径只处理有语义的片段并丢弃过期任务
- **Local inference, no Ollama** / 内置本地推理：choose Qwen3 4B Q4 or Gemma 3 4B Q4 locally, using the bundled llama.cpp runtime / 可在本地选择 Qwen3 4B Q4 或 Gemma 3 4B Q4，使用应用内置 llama.cpp 运行时，不依赖 Ollama
- **Gemma Metal acceleration** / Gemma Metal 加速：Gemma pre-warms when enabled and uses full Apple Silicon Metal offload plus Flash Attention; Qwen keeps its original on-demand runtime configuration / 启用 Gemma 后会预热，并使用 Apple Silicon Metal 全层卸载与 Flash Attention；Qwen 保持原有的按需启动配置
- **Caption modes** / 字幕模式：Auto prioritizes latency; Meeting adds terms, corrections and action items after final utterances; Video adds concepts and takeaways / 自动模式优先低延迟；会议与视频模式在句子结束后分别补充提示
- **Dictionary hints** / 单词词典：click a source-language word to add a target-language translation to a newest-first history in Hints; Clear removes that history / 点击原文单词可在提示栏累计查询翻译，最新在最上方；Clear 可清空
- **Chinese / English UI** / 中英文界面：Settings > Display language switches the Settings screen, core floating-panel actions, live-caption UI, and menu-bar menu without changing layout / 设置 > 显示语言可切换设置页、主面板常用操作、字幕窗口及菜单栏菜单，不改变布局
- **Per-display editor placement** / 多显示器截图定位：screenshot editor placement continues to follow the display where the selection was made / 截图编辑器仍会在对应截图屏幕的位置打开

### v1.3.0 - Positioned Capture Editor / 原位截图编辑器

- **Position-matched editor** / 原位编辑：reads the native screenshot selection rectangle and restores the editor window to the same bounds / 读取系统截图选区坐标，让编辑窗口以相同位置与大小打开
- **Retina-aware sizing** / Retina 尺寸适配：uses screen points for the window and keeps full-resolution pixels for export / 窗口按屏幕逻辑尺寸显示，导出仍保留原始高清像素
- **Multi-display placement** / 多显示器定位：converts Quartz coordinates through the display where the selection was made / 根据实际截图显示器转换全局坐标
- **Unified signed build** / 统一签名构建：DMG creation now reuses the app build and signing pipeline / DMG 统一复用应用构建与签名流程

### v1.2.3 - Adaptive Editor / 自适应编辑器

- **Content-sized window** / 内容尺寸窗口：the editor follows the screenshot size and only scales down when it exceeds the active display / 编辑窗口跟随截图尺寸，仅在超出当前显示器时等比缩小
- **Responsive toolbar** / 响应式工具栏：primary actions remain visible while drawing controls scroll on narrow captures / 主要操作始终可见，窄截图下绘图工具可横向滚动
- **Scale-safe annotations** / 精确缩放标注：drawing coordinates map between the displayed canvas and the original image / 标注坐标在显示画布和原图之间准确转换

### v1.2.2 - Global Capture Workspace / 全局截图工作区

- **Wide editor workspace** / 宽幅编辑器：opens across the active display with a responsive, non-wrapping toolbar / 在当前显示器打开宽幅编辑工作区，工具栏不会再挤压换行
- **Global capture shortcut** / 全局截图快捷键：`Cmd+Ctrl+S` works while another application is active / 其他应用处于前台时也可直接进入截图选择
- **Stable local signing** / 稳定本地签名：this Mac uses a command-line-authorized Apple Development identity for team `74L6FS4NS6`; release builds can override it with Developer ID / 本机使用团队 `74L6FS4NS6` 中已授权命令行的 Apple Development 身份，发布构建可切换为 Developer ID

### v1.2.1 - Screenshot Reliability / 截图修复

- **Permission checks** / 权限检查：show the current Screen Recording status and a link to System Settings / 显示屏幕录制权限状态，提供系统设置入口
- **Capture recovery** / 截图恢复：report capture errors, restore the panel after failure or cancellation, and prevent overlapping capture sessions / 失败时显示原因，失败或取消后恢复面板，防止重复启动截图
- **Registered hotkeys** / 系统快捷键：`Cmd+Ctrl+S` and `Cmd+Shift+V` use system hotkey registration; conflicts appear in Settings / 通过系统注册快捷键，冲突会在设置中提示
- **Build identification** / 版本识别：Settings shows the running version and app path / 设置中显示当前版本和应用路径

### v1.2.0 - Settings / 设置

- **Settings panel** / 设置面板 — open from the gear button in the floating panel / 从浮动面板齿轮按钮进入
- **Launch at login** / 开机自动启动 — automatically open ClipStash after macOS login / 登录 macOS 后自动启动 ClipStash

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

### Known Issues / 已知问题

- **Screen Recording permission applies to the running app** — an old copy in Applications may not share authorization with a local build. Check the path in Settings, authorize that copy, then reopen it. Protected content may still be excluded by macOS.
  屏幕录制权限需要对当前运行的应用生效。Applications 中的旧版和本地构建可能不共享授权，请核对设置里的路径，授权后重新启动。受保护内容仍可能无法截取。
- **Local ad-hoc builds may need permission again after updates.** The build script signs the complete app bundle; stable identity across builds requires a code-signing certificate via `CLIPSTASH_SIGNING_IDENTITY`.
  本地临时签名版本在更新后可能需要重新授权。构建脚本已对完整应用签名；跨版本稳定身份需要通过 `CLIPSTASH_SIGNING_IDENTITY` 指定代码签名证书。
- **The v1.1.0 GitHub DMG is not notarized.** It is retained as a legacy artifact and is not the recommended installation path.
  GitHub 上的 v1.1.0 DMG 尚未经过 Apple 公证，仅作为历史产物保留，不建议作为当前安装方式。
- **Hotkey conflicts** — if another app has registered the same shortcut, use the camera button or menu bar > Screenshot. Settings reports registration errors.
  快捷键冲突时，可用相机按钮或菜单栏 Screenshot，注册错误会显示在设置中。

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

## macOS Distribution / macOS 发布

Public downloads outside the Mac App Store must use a `Developer ID Application` certificate, Hardened Runtime, a secure timestamp, and Apple notarization. `Apple Development` and `Apple Distribution` certificates are not substitutes for Developer ID distribution.

Mac App Store 之外的公开下载需要使用 `Developer ID Application` 证书、Hardened Runtime、安全时间戳和 Apple 公证。`Apple Development` 与 `Apple Distribution` 证书不能替代 Developer ID 站外分发证书。

```bash
# 1. Store notarization credentials once / 首次保存公证凭据
xcrun notarytool store-credentials "clipstash-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"

# 2. Build the Developer ID-signed DMG / 构建 Developer ID 签名的 DMG
CLIPSTASH_SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAM_ID)" \
  ./create-dmg.sh

# 3. Notarize and staple / 公证并装订票据
xcrun notarytool submit ClipStash-Installer.dmg \
  --keychain-profile "clipstash-notary" --wait
xcrun stapler staple ClipStash-Installer.dmg
spctl -a -vv -t open --context context:primary-signature ClipStash-Installer.dmg
```

Only upload the DMG to GitHub Releases after the final `spctl` check reports `accepted`.

只有最终 `spctl` 检查显示 `accepted` 后，才应将 DMG 上传到 GitHub Releases。

## Usage / 使用

| Action / 操作 | Method / 方式 |
|---|---|
| Show/Hide panel / 显示隐藏面板 | `Cmd+Shift+V` or menu bar icon |
| Take screenshot / 截图 | `Cmd+Ctrl+S` or menu bar > Screenshot |
| Re-copy item / 重新复制 | Click any item in the list |
| Pin item / 收藏条目 | Click the star icon |
| Float image / 浮动显示图片 | Click the pin icon on image items |
| Search / 搜索 | Type in the search bar |
| Settings / 设置 | Click the gear icon |
| Launch at login / 开机自动启动 | Settings > Launch at login |
| Display language / 显示语言 | Settings > System > Display language / 设置 > 系统 > 显示语言 |
| Caption mode / 字幕模式 | Settings > Live captions > Assistant mode / 设置 > 实时字幕 > 助手模式 |
| Dictionary lookup / 单词查询 | Click a source caption word / 点击原文单词 |
| Gemma setup / Gemma 设置 | Accept the Gemma license, save a Hugging Face **Read** token in Settings, then download / 接受 Gemma 许可，在设置中保存 Hugging Face **Read** Token 后下载 |

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
    LaunchAtLoginManager.swift      # macOS login item / 开机自动启动
    PasteboardReader.swift          # Content extraction / 内容提取
    PersistenceManager.swift        # JSON persistence / JSON 持久化
    ScreenCaptureService.swift      # Screenshot capture / 截图服务
    CaptionTimeline.swift           # Stable source/translation rows / 稳定的原文译文行
    DisplayLanguageSettings.swift   # UI language preference / 界面语言偏好
    LocalModelManager.swift         # Bundled local model runtime / 内置本地模型运行时
    MeetingAssistantService.swift   # Speech, translation, hints / 语音、翻译、提示
    MeetingLanguageSettings.swift   # Caption languages and modes / 字幕语言与模式
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

### v1.4.22 (2026-09-25)
- Added live source/translation caption sections, streaming quick translation, and sentence-final slow insights / 增加原文译文字幕分区、流式快速翻译和句末慢速提示
- Added optional built-in local Qwen3 inference with bundled runtime; model weights are managed in Application Support / 增加可选内置 Qwen3 本地推理，模型权重由应用在 Application Support 管理
- Added Auto, Meeting and Video caption modes plus newest-first dictionary hints / 增加自动、会议、视频字幕模式和最新优先的单词词典提示
- Redesigned Settings into caption, AI, permission, and system sections / 设置页重组为字幕、AI、权限和系统分区
- Added a Chinese/English display-language preference that updates the Settings, core panel, live captions, and menu-bar menu / 增加中英文界面语言设置，同步更新设置页、主面板常用项、字幕窗口和菜单栏菜单

### v1.3.0 (2026-09-07)
- Restore the editor window to the screenshot selection's position and size / 编辑窗口恢复到截图选区的位置与大小
- Use native screenshot metadata to correct Retina 2x sizing / 使用系统截图元数据修正 Retina 2 倍尺寸
- Keep full-resolution output while adapting the editor UI to screen-point dimensions / 保留高清导出，同时按屏幕逻辑尺寸适配编辑器
- Reuse the signed app build when creating a DMG / 创建 DMG 时复用已签名应用构建
- Document the verified macOS signing and notarization requirements / 补充已验证的 macOS 签名与公证要求

### v1.2.3 (2026-09-07)
- Size the editor from the captured image instead of filling the display / 编辑器尺寸改为跟随截图内容
- Scale oversized screenshots proportionally to the active display / 超大截图按当前显示器等比缩小
- Keep pin, cancel, and save actions visible in narrow windows / 窄窗口中置顶、取消和保存操作保持可见
- Map annotations back to original-image coordinates / 标注位置准确映射回原图坐标

### v1.2.2 (2026-09-07)
- Reworked the screenshot editor into a wide active-display workspace / 截图编辑器改为当前显示器宽幅工作区
- Grouped drawing controls and fixed action-button sizing / 重组绘图工具并固定操作按钮尺寸
- Verified `Cmd+Ctrl+S` from Finder as a global shortcut / 已从 Finder 前台验证全局截图快捷键
- Prepared the build for stable Developer ID release signing / 构建流程支持 Developer ID 正式发布签名

### v1.2.1 (2026-09-07)
- Added Screen Recording permission checks and a System Settings entry / 增加屏幕录制权限检测和设置入口
- Fixed silent screenshot failures and panel recovery after cancellation / 修复截图静默失败和取消后面板消失
- Replaced keyboard event monitoring with registered hotkeys; report conflicts / 使用系统注册快捷键并提示冲突
- Wait for shortcut modifiers to be released before selecting a screenshot / 截图前等待快捷键修饰键释放
- Corrected the screenshot tooltip to Cmd+Ctrl+S / 修正截图快捷键提示
- Sign the complete app bundle; show version and path in Settings / 完整应用签名，设置中显示版本与路径
- Known: upgrading from the old hash-based signature to v1.2.2 requires one final permission reset / 已知：从旧的哈希签名升级至 v1.2.2 时需最后重新授权一次

### v1.2.0 (2026-09-07)
- Added Settings panel in the floating window
- Added launch-at-login toggle using macOS ServiceManagement
- Shows current login item status and setup errors in Settings

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
