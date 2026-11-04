<p align="center">
  <img src="glMusic/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="glMusic Icon" />
</p>

<h1 align="center">glMusic</h1>

<p align="center">
  <strong>一款基于 Swift & SwiftUI 构建的现代 macOS 原生高颜值音乐播放器</strong><br>
  深度融合 macOS 设计规范，呈现极致 Apple Music 视觉质感、夜景散景流光与沉浸听歌体验。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Swift%205%20%2F%206-F05138?style=flat-square&logo=swift" alt="Language" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI%20%2F%20Observation-0071e3?style=flat-square" alt="Framework" />
  <img src="https://img.shields.io/badge/API-NeteaseCloudMusicApi-red?style=flat-square" alt="API" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" />
</p>

---

## 📖 项目简介

**glMusic** 是一款专为 macOS 桌面平台打造的高颜值、高性能音乐流媒体与本地音乐管理客户端。应用采用全原生 **SwiftUI + Swift Concurrency + Observation** 架构编写，彻底告别 Electron 等混合技术方案的高内存占用与卡顿。

整体 UI 严格遵循 **macOS Human Interface Guidelines (HIG)**，高度还原 macOS 原生 **Apple Music** 的界面层次感与精致质感——包含原生窗口半透毛玻璃材质、梦幻城市夜景散景流光背景、自适应多色清新主题、悬浮胶囊播放条、动态专辑色全屏双语歌词、全功能本地音频导入、离线无损下载管理以及完整的广播与播客电台系统。

---

## ✨ 核心特性

### 1. 🎨 6 套清新主题配色系统 (Adaptive Color Themes)
- **多套精心调校的自然色彩**：
  - 🌿 **薄荷清风 (Mint Breeze)**：灵动清凉，营造初春微风般听觉呼吸感；
  - 🌊 **海风清蓝 (Sea Breeze)**：澄澈蔚蓝，视野辽阔宁静，还原 Apple 经典水蓝意境；
  - 🌸 **樱花柔粉 (Sakura Pink)**：温润轻盈，升华原生 Apple Music 经典粉质感；
  - 🍵 **抹茶初夏 (Matcha Green)**：自然素雅，森林系治愈色调，柔和护眼；
  - 🍑 **蜜桃日落 (Peach Sunset)**：元气甜橙，宛如落日余晖洒在唱片机上；
  - 🪻 **薰衣草紫 (Lavender Mist)**：梦幻罗兰，雅致轻奢，夜间聆听绝佳。
- **全应用动态响应式着色**：基于 `@Observable` 的响应式架构，胶囊播放栏、歌曲行高亮、红心收藏、操作按钮、分类胶囊与详情页均随主题平滑无感同步。
- **双入口即时切换**：侧边栏常驻调色板弹出窗口，顶部菜单栏（`主题风格`）原生快捷操作，支持自动持久化记忆。

### 2. 🌃 城市夜景多层散景流光背景 (Night City Bokeh Ambient System)
- **系统级原生毛玻璃透光**：依托 macOS 14+ `.containerBackground(.thinMaterial, for: .window)` 窗口底层材质，自然融入 macOS 桌面光影。
- **19 个四级景深镜头散景 (Depth of Field)**：
  - **4 处远景大光晕 (Diffuse Cloud)**：直径 230~290px，构建广袤深邃的夜景基底色调；
  - **4 处中景柔光球 (Soft Orb)**：直径 110~135px，自然景深过渡；
  - **7 处具象清晰光斑 (Crisp Bokeh Discs)**：直径 48~88px，边缘清晰可见，附带大光圈镜头特有的「微亮光圈边缘环 (Soap Bubble Rim)」，告别糊成一片的虚化；
  - **4 处近景晶莹亮点 (Sparkling Pin)**：高亮微星核点缀，如玻璃反光与夜间星芒。
- **舒缓浮动与多色混光**：6.5 秒极缓漂移呼吸节奏，主题主色、伴生次色与晶莹高光色交织，非侵入式渲染（零阻碍滚动与点击）。

### 3. 📥 全功能「本地音乐导入」与离线资料库 (Local Music Import)
- **原生拖拽导入 (Drag & Drop)**：支持从访达（Finder）直接拖拽单首、多首音频文件或整个音乐文件夹到窗口，界面实时展现拖拽引导虚线框。
- **全局快捷键与原生面板**：支持 `⌘ + O`（或菜单栏 `文件 -> 导入本地音乐...`）唤起系统 `NSOpenPanel` 批量导入。
- **全主流音频格式兼容**：全面支持 `MP3`、`FLAC`、`M4A`、`WAV`、`AAC`、`AIFF`、`ALAC`、`OGG`。
- **智能元数据与 ID3 深度提取**：通过 `AVURLAsset` 解析提取歌曲标题、艺人、专辑名称与精确到毫秒的音频时长，无标签时智能清洗文件名。
- **内嵌高清封面与伴生歌词提取**：
  - 自动提取音频内嵌高清专辑封面保存在本地；
  - 优先扫描同目录同名伴生 `.lrc` 文件，自动识别内嵌同步/非同步歌词，支持 UTF-8、GB18030、GBK 智能防乱码。
- **零缓冲秒起播放与分类筛选**：本地分配安全唯一 ID，本地解码 0 缓冲即刻起播；资料库支持「全部 / 本地导入 / 已下载」多胶囊模式一键切换与搜索过滤。

### 4. 🎧 原生 Apple Music 交互美学与系统级媒体控制
- **NavigationSplitView 响应式三栏/两栏布局**：自然适配不同显示器与分屏窗口尺寸变化。
- **悬浮胶囊播放栏 (Floating PlayerBar)**：底部毛玻璃拟物化胶囊，集成播放进度拖拽、音量微调、封面卡、喜欢红心与待播清单弹出窗口。
- **系统级媒体中心深度集成 (`MediaPlayer`)**：
  - 全面打通 `MPNowPlayingInfoCenter` 与 `MPRemoteCommandCenter`；
  - 支持键盘物理多媒体按键（播放/暂停/上一曲/下一曲/滑动进度）；
  - 深度支持 macOS 控制中心、菜单栏媒体小部件与锁屏高清封面展示。
- **全屏动效双语歌词 (Apple Music Style)**：动态封面主色光斑背景，双语同步高亮滚动，支持轻点任意行精准 Seek 跳转播放。

### 5. 📻 广播电台与探索体验 (Radio & DJ)
- **焦点电台横幅 (Focus Banners)**：大尺寸轮播卡片，悬停微动效与快速试听环。
- **全品类探索与节目排期**：音乐播客、情感生活、脱口秀、有声书等分类自由探索；电台详情页常驻吸顶导航与批量连续播放。
- **现在就听 (Home) & 每日推荐 (Daily)**：精选聚焦 Banner、推荐歌单、新歌速递、每日推荐日历卡片每日定时更新。

### 6. ⚡️ 高韧性架构与极致性能 (Architecture & Performance)
- **线程安全内存缓存 (`actor APICache`)**：对 Banner、推荐歌单、榜单、电台等数据按 TTL 内存缓存，大幅减少重复网络开销。
- **瞬态故障指数退避重试 (Exponential Backoff)**：网络波动或超时自动平滑重试。
- **受控并发下载队列 (Max Concurrent = 3)**：批量下载时限流受控，避免网络阻塞或服务器限流。
- **组件去重与模块化设计**：提炼通用组件 [`UnifiedSongRow`](file:///Users/golove/Documents/glMusic/glMusic/Views/UnifiedSongRow.swift) 与 [`PlaybackActionBar`](file:///Users/golove/Documents/glMusic/glMusic/Views/PlaybackActionBar.swift)，全项目消除 1100+ 行重复代码。

---

## ⌨️ 全局键盘快捷键

| 快捷键 | 功能描述 |
| :--- | :--- |
| `Space` (空格键) | 播放 / 暂停当前歌曲 |
| `⌘ + →` | 下一首 |
| `⌘ + ←` | 上一首 |
| `⌘ + ↑` | 增加音量 (+5%) |
| `⌘ + ↓` | 降低音量 (-5%) |
| `⌘ + O` | **导入本地音频文件或文件夹** |
| `⌘ + [` | 返回上一级页面 |
| `ESC` | 退出全屏动态歌词视图 |
| `Tab` | 切换界面焦点元素进行键盘导航 |

---

## 🛠️ 项目架构

```
glMusic/
├── glMusicApp.swift                  # 应用程序入口：全局环境注入、顶部原生菜单栏、键盘指令
├── ContentView.swift                # 主框架总控：SplitView、深层导航栈、全局快捷键、窗口毛玻璃
├── ThemeManager.swift               # 主题管理器：6套清新配色、渐变、持久化与色温状态
├── StructModel.swift                 # 侧边栏导航定义与通用模型
├── DownloadManager.swift             # 离线下载与本地音频导入引擎：ID3提取、LRC解析、并发队列控制
├── PlayerManager.swift               # 播放核心引擎：AVPlayer、歌词同步解析、待播队列、系统媒体中心集成
│
├── Network/
│   ├── NetworkManager.swift          # 网络层：actor 内存缓存、指数退避重试、API 请求封装
│   └── APIModels.swift               # 数据模型映射 (Codable / Sendable / HTTPS安全转接)
│
└── Views/
    ├── Sidebar.swift                 # 原生侧边栏 (资料库 + 广播 + 歌单列表 + 主题调色板入口)
    ├── ThemePickerView.swift         # 主题选择弹出面板与网格卡片
    ├── NightBokehBackground.swift    # 城市夜景多层散景流光背景 (19个虚实景深光斑)
    ├── PlayerBar.swift               # 底部悬浮胶囊播放栏 (进度条/音量/待播清单/红心)
    ├── UnifiedSongRow.swift          # 全局通用单曲行组件 (序号/波形/封面/标题/喜欢/下载/右键菜单)
    ├── PlaybackActionBar.swift       # 全局播放操作栏 (播放全部/随机播放/下载全部)
    ├── DownloadButton.swift          # 全局三态动态下载按钮 (未下载/进度环/已下载)
    ├── DownloadedSongsView.swift     # 「本地与下载」专属资料库页面 (拖拽接收/胶囊筛选/访达定位)
    ├── LyricsView.swift              # Apple Music 风格全屏动态模糊双语歌词
    ├── HomeView.swift                # 「现在就听」主页：聚焦横幅、推荐歌单、新歌网格
    ├── BrowseView.swift              # 「浏览」页面
    ├── RadioView.swift               # 「广播」主页：电台横幅、热门推荐、节目榜单、分类探索
    ├── RadioDetailView.swift         # 电台与播客详情页 (常驻吸顶导航与节目单)
    ├── DailyRecommendView.swift      # 「每日推荐」动态日历卡片页
    ├── PlaylistDetailView.swift      # 歌单详情页
    ├── AlbumDetailView.swift         # 专辑详情页
    ├── ArtistDetailView.swift        # 歌手详情页 (热门歌曲 Top 50 + 专辑网格)
    ├── QueueView.swift               # 待播清单弹出面板
    ├── SearchView.swift              # 音乐搜索与热搜榜
    ├── SongsView.swift               # 歌曲排行榜列表
    ├── AlbumsView.swift              # 新碟上架网格
    ├── ArtistsView.swift             # 热门歌手网格
    ├── RecentlyAddedView.swift       # 最近添加
    ├── LoginView.swift               # 二维码 / 验证码 双模式登录页面
    └── WindowToolbarAccessor.swift   # 原生窗口工具栏透明度与标题栏微调辅助器
```

---

## 🚀 快速上手与本地运行

### 环境要求
- **macOS**：macOS 14.0 (Sonoma) 或更高版本 (全面支持 macOS 15 Sequoia)
- **Xcode**：Xcode 15.0 或更高版本 (Swift 5.9 / Swift 6)
- **后端服务**：需要本地或远程运行 [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi)

### 1. 启动 API 后端服务
在本地启动 Node.js 网易云 API 服务（默认端口 `3000`）：
```bash
# 方式 1：使用 npx 快速运行
npx NeteaseCloudMusicApi

# 方式 2：使用 Docker 部署
docker run -d -p 3000:3000 --name netease_api binaryify/netease_cloud_music_api
```
启动成功后，浏览器访问 `http://127.0.0.1:3000` 确认服务运行正常。

### 2. 克隆与打开项目
```bash
git clone https://github.com/your-username/glMusic.git
cd glMusic
open glMusic.xcodeproj
```

### 3. 编译与运行
- 在 Xcode 顶部选择目标设备为 **My Mac**；
- 按下快捷键 `⌘ + R` 即可完成编译并启动应用；
- 或者在终端使用命令行编译：
```bash
xcodebuild -project glMusic.xcodeproj -scheme glMusic -destination 'platform=macOS' build
```

---

## 🛡️ 沙盒与存储机制说明

- 本应用开启了标准 macOS App Sandbox（`com.apple.security.app-sandbox = true`）；
- 所有下载与导入的离线音乐、歌词与封面安全保存在用户的沙盒存储目录中：  
  `~/Library/Containers/com.golove.glMusic/Data/Documents/Downloads/`
- 支持通过 `NSWorkspace` 原生唤醒访达直接高亮定位目标音频文件，无需额外的外部文件读写授权弹窗。

---

## ⚠️ 常见问题排查 (FAQ)

### 安装后 macOS 提示「文件已损坏，无法打开」？
由于 macOS Gatekeeper 安全机制，从第三方渠道下载未签名的编译包可能被隔离。请在终端执行以下命令解除安全隔离限制：
```bash
sudo xattr -dr com.apple.quarantine /Applications/glMusic.app
```

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 许可证开源，仅供学习、交流与技术研究使用。音乐版权归各大唱片公司与音乐平台所有。
