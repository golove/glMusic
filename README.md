<p align="center">
  <img src="glMusic/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="glMusic Icon" />
</p>

<h1 align="center">glMusic</h1>

<p align="center">
  <strong>一款基于 Swift & SwiftUI 构建的现代 macOS 原生高颜值音乐播放器</strong><br>
  深度融合 macOS 设计规范，呈现极致 Apple Music 视觉质感、原生 SDK 官方直连、智能换源解灰与沉浸听歌体验。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Release-v0.3.4-0071e3?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Swift%205%20%2F%206-F05138?style=flat-square&logo=swift" alt="Language" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI%20%2F%20Observation-0071e3?style=flat-square" alt="Framework" />
  <img src="https://img.shields.io/badge/API-Native%20Swift%20SDK-brightgreen?style=flat-square" alt="API" />
  <img src="https://img.shields.io/badge/Backend-Zero%20Dependency-blue?style=flat-square" alt="Backend" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" />
</p>

---

## 📖 项目简介

**glMusic** 是一款专为 macOS 桌面平台打造的高颜值、高性能音乐流媒体与本地音乐管理客户端。应用采用全原生 **SwiftUI + Swift Concurrency + Observation** 架构编写，彻底告别 Electron 等混合技术方案的高内存占用与卡顿。

更进一步，本项目现已全面集成 **NeteaseCloudMusicAPI-Swift** 原生 SDK 与智能换源解灰引擎，**彻底移除了对外部 Node.js 本地服务的依赖**，客户端直接与网易云官方服务器高并发加密通信；同时支持 **VIP 歌曲 30s/45s 试听限制自动换源破解** 以及 **PlayerBar 原生全音质自由切换 (SoundQualityType)**。

整体 UI 严格遵循 **macOS Human Interface Guidelines (HIG)**，高度还原 macOS 原生 **Apple Music** 的界面层次感与精致质感——包含原生窗口半透毛玻璃材质、梦幻城市夜景散景流光背景、自适应多色清新主题、悬浮胶囊播放条、**毫秒级 YRC 逐字卡拉OK歌词**、**歌词排版自定义系统**、**音频输出设备即时热切换**、**多语言国际化支持**、**GitHub 自动在线更新**、全功能本地音频导入、离线无损下载管理以及完整的广播与播客电台系统。

---

## ![alt text](camera.macro.png) 程序截图

<img width="1563" height="982" alt="glMusic 歌词界面" src="https://github.com/user-attachments/assets/057d1d26-a2fd-4636-b532-115b053ede10" />

<img width="1563" height="982" alt="glMusic 浏览页面" src="https://github.com/user-attachments/assets/04dce898-24cb-4317-a217-84ec6a937d42" />

<img width="1563" height="982" alt="glMusic 电台与播客" src="https://github.com/user-attachments/assets/df4023ef-d8ef-4f40-bee1-e075789aba91" />

<img width="1563" height="982" alt="glMusic 歌手详情" src="https://github.com/user-attachments/assets/007f3c80-9084-47f7-ac03-02c80713b863" />

---

## ✨ 核心特性

### 1. ⚡️ 原生 Swift SDK 官方直连与智能换源解灰 (Native Direct Connect & VIP Unblock)
- **原生 EAPI / WeAPI 直连架构（零后台服务依赖）**：
  - 彻底摆脱以往必须在本地运行 Node.js 3000 端口服务 (`Binaryify/NeteaseCloudMusicApi`) 的繁琐配置；
  - 基于原生 Swift SDK（[NeteaseCloudMusicAPI-Swift](https://github.com/Lincb522/NeteaseCloudMusicAPI-Swift)）原生加密引擎直接与网易云服务器通信，低延迟、高并发、开箱即用。
- **VIP 试听突破与智能解灰换源**：
  - 内置高质量智能解灰引擎（集成 GD 音乐台等直连音源）；
  - 自动识别 VIP 歌曲试听片段（30 秒/45 秒限制）及无版权灰色歌曲，秒级自动匹配 **320kbps 完整高品质音频**，在线播放与离线下载彻底告别播放截断。
- **播放栏音质即时切换 (SoundQualityType Menu)**：
  - 底部悬浮播放栏（PlayerBar）新增紧凑精致的 Apple Music 风格音质角标，位于「喜欢 (Like)」按钮正前方；
  - 原生下拉菜单支持一键切换 **标准 (128K)**、**极高 (320K)**、**无损 (FLAC)**、**Hi-Res**、**高清环绕声**、**沉浸环绕声**、**超清母带**；
  - 播放中支持热切换无缝重载，保持当前进度继续播放，并自动持久化记忆音质偏好。

### 2. 🎤 逐字卡拉OK动效与歌词排版定制系统 (Karaoke & Lyrics Customization)
- **官方毫秒级 YRC 逐字时间轴引擎**：
  - 自动对接网易云官方高级歌词接口，提取毫秒级 `yrc` 逐字时间轴数据；
  - 遇到长音拖拽时流光精准对齐，间奏停顿流光自动暂停，发音秒级同步点亮；
  - 针对无逐字轴的标准歌词，内置基于字数与语速的自适应演唱时长估算算法，告别长间奏蜗牛漫爬。
- **纯文字立体柔和渐变高亮**：
  - 彻底移除了破坏观感的“荧光标记笔”外框矩形色块阴影，实现真正的纯文字笔画点亮；
  - 采用精心调和的 4-Stop 垂直立体透光渐变，顶部亮白保证辨识度，下半段浸润淡化 60% 的温润主题色，通透晶莹不刺眼。
- **歌词样式全功能自定义面板 (`LyricsStyleSettingsPopover`)**：
  - **排版对齐**：经典居左对齐 / 沉浸大幕居中对齐；
  - **字号规格**：标准 (24pt) / 放大 (30pt) / 巨幕 (36pt)；
  - **动效模式**：实时逐字卡拉OK扫光 / 经典聚光灯聚焦；
  - **景深虚焦效果 (Depth Blur)**：当前行晶莹聚焦，非当前行随行距平滑呈现 0~2.5pt 电影级大光圈散焦；
  - **双语翻译对照**：外语歌词中文对照自由开关；
  - **上下边缘渐隐**：顶部与底部 48~64pt 柔和羽化遮罩，消除文字硬切。
- **顶栏两端原生悬停唤醒控制**：
  - 平日以 `0.33` 优雅淡雅半透明静驻，融入大背景；鼠标靠近时通过 `easeInOut(duration: 0.2)` 丝滑点亮至 `1.0` 完整不透明度；
  - 绑定完整受击热区，100% 灵敏响应，杜绝被底层滚动列表穿透吞掉点击。

### 3. 🔊 原生音频输出设备切换与流体音量交互 (Audio Device & Fluid Volume System)
- **CoreAudio 系统级音频输出即时切换**：
  - 无论在主界面底部播放栏还是全屏歌词页，均可一键弹出设备列表；
  - 支持即时在内置扬声器、AirPods、蓝牙耳机、HDMI 外接显示器、USB 专业声卡之间热切换，并自动标注 AirPods 与内置设备标识。
- **SF Symbols 5 原生分层逐级动效 (`.symbolEffect(.replace.byLayer)`)**：
  - 拖动音量调节滑块时，喇叭锥体底座定点居左锚定（零水平位移跳动）；
  - 音波弧线如同水波纹般逐层自然生长扩展或柔和褪去，彻底消除生硬硬切与滑块水平震颤。
- **全局一键快速静音与恢复**：
  - 点击喇叭图标可一键静音，再次点击平滑恢复此前音量大小。

### 4. 🌐 国际化多语言系统 (Multi-Language Localization)
- 全面支持 **简体中文 (zh-Hans)**、**English**、**繁體中文 (zh-Hant)** 三种语言环境；
- 支持在应用内即时切换语言，界面与系统提示全局秒级更新，无需重启应用；
- 基于 Apple 现代化 `.xcstrings` 字符串目录与统一本地化扩展管理。

### 5. 🔄 GitHub 自动检查更新与平滑升级 (Auto-Update Engine)
- **启动静默检测**：应用启动时异步联网查询 GitHub Releases 最新版本标签（如 `v0.3.4`）；
- **原生更新提示浮层**：发现新版本自动弹出版本号对比与详细更新日志；
- **一键自动化安装**：支持一键在后台静默下载最新 DMG/ZIP 包、自动校验替换并重启应用，免去手动去浏览器下载的繁琐步骤；
- **菜单栏手动触发**：支持通过顶部菜单栏 `glMusic -> 检查更新...` 随时手动检测。

### 6. 🎵 歌单广场与本地播放历史 (Playlist Square & History)
- **全新歌单广场 (`PlaylistSquareView`)**：
  - 提供全部分类标签（华语、流行、摇滚、民谣、电子、轻音乐、影视原声、ACG 等）；
  - 瀑布流网格展示海量官方精选歌单与亿级播放量热门推荐，支持分页无限加载。
- **播放历史记录 (`HistoryView`)**：
  - 自动在本地持久化记录最近收听的每一首歌曲与时间线；
  - 支持一键连续播放历史足迹、清空播放记录与多选批量操作。

### 7. 🎨 6 套清新主题配色系统 (Adaptive Color Themes)
- **多套精心调校的自然色彩**：
  - 🌿 **薄荷清风 (Mint Breeze)**：灵动清凉，营造初春微风般听觉呼吸感；
  - 🌊 **海风清蓝 (Sea Breeze)**：澄澈蔚蓝，视野辽阔宁静，还原 Apple 经典水蓝意境；
  - 🌸 **樱花柔粉 (Sakura Pink)**：温润轻盈，升华原生 Apple Music 经典粉质感；
  - 🍵 **抹茶初夏 (Matcha Green)**：自然素雅，森林系治愈色调，柔和护眼；
  - 🍑 **蜜桃日落 (Peach Sunset)**：元气甜橙，宛如落日余晖洒在唱片机上；
  - 🪻 **薰衣草紫 (Lavender Mist)**：梦幻罗兰，雅致轻奢，夜间聆听绝佳。
- **全应用动态响应式着色**：基于 `@Observable` 的响应式架构，胶囊播放栏、歌曲行高亮、红心收藏、操作按钮、歌词高光渐变与详情页均随主题平滑同步。

### 8. 🌃 城市夜景多层散景流光背景 (Night City Bokeh Ambient System)
- **系统级原生毛玻璃透光**：依托 macOS 14+ `.containerBackground(.thinMaterial, for: .window)` 窗口底层材质，自然融入 macOS 桌面光影。
- **19 个四级景深镜头散景 (Depth of Field)**：
  - **4 处远景大光晕 (Diffuse Cloud)**：直径 230~290px，构建广袤深邃的夜景基底色调；
  - **4 处中景柔光球 (Soft Orb)**：直径 110~135px，自然景深过渡；
  - **7 处具象清晰光斑 (Crisp Bokeh Discs)**：直径 48~88px，边缘清晰可见，附带「微亮光圈边缘环 (Soap Bubble Rim)」；
  - **4 处近景晶莹亮点 (Sparkling Pin)**：高亮微星核点缀，如玻璃反光与夜间星芒。
- **舒缓浮动与多色混光**：6.5 秒极缓漂移呼吸节奏，主题主色、伴生次色与晶莹高光色交织，非侵入式渲染（零阻碍滚动与点击）。

### 9. 📥 全功能「本地音乐导入」与离线资料库 (Local Music Import)
- **原生拖拽导入 (Drag & Drop)**：支持从访达（Finder）直接拖拽单首、多首音频文件或整个音乐文件夹到窗口，界面实时展现拖拽引导虚线框。
- **全局快捷键与原生面板**：支持 `⌘ + O`（或菜单栏 `文件 -> 导入本地音乐...`）唤起系统 `NSOpenPanel` 批量导入。
- **全主流音频格式兼容**：全面支持 `MP3`、`FLAC`、`M4A`、`WAV`、`AAC`、`AIFF`、`ALAC`、`OGG`。
- **智能元数据与 ID3 深度提取**：通过 `AVURLAsset` 解析提取歌曲标题、艺人、专辑名称与精确到毫秒的音频时长，无标签时智能清洗文件名。
- **内嵌高清封面与伴生歌词提取**：
  - 自动提取音频内嵌高清专辑封面保存在本地；
  - 优先扫描同目录同名伴生 `.lrc` 文件，自动识别内嵌同步/非同步歌词，支持 UTF-8、GB18030、GBK 智能防乱码。
- **零缓冲秒起播放与分类筛选**：本地分配安全唯一 ID，本地解码 0 缓冲即刻起播；资料库支持「全部 / 本地导入 / 已下载」多胶囊模式一键切换与搜索过滤。

### 10. 🎧 原生 Apple Music 交互美学与系统级媒体控制
- **NavigationSplitView 响应式三栏/两栏布局**：自然适配不同显示器与分屏窗口尺寸变化。
- **悬浮胶囊播放栏 (Floating PlayerBar)**：底部毛玻璃拟物化胶囊，集成播放进度拖拽、音质档位切换、音量微调、一键静音、设备切换、待播清单弹出窗口。
- **系统级媒体中心深度集成 (`MediaPlayer`)**：
  - 全面打通 `MPNowPlayingInfoCenter` 与 `MPRemoteCommandCenter`；
  - 支持键盘物理多媒体按键（播放/暂停/上一曲/下一曲/滑动进度）；
  - 深度支持 macOS 控制中心、菜单栏媒体小部件与锁屏高清封面展示。

### 11. 📻 广播电台与探索体验 (Radio & DJ)
- **焦点电台横幅 (Focus Banners)**：大尺寸轮播卡片，悬停微动效与快速试听环。
- **全品类探索与节目排期**：音乐播客、情感生活、脱口秀、有声书等分类自由探索；电台详情页常驻吸顶导航与批量连续播放。
- **现在就听 (Home) & 每日推荐 (Daily)**：精选聚焦 Banner、推荐歌单、新歌速递、每日推荐日历卡片每日定时更新。

### 12. ⚡️ 高韧性架构与极致性能 (Architecture & Performance)
- **线程安全内存缓存 (`actor APICache`)**：对 Banner、推荐歌单、榜单、电台等数据按 TTL 内存缓存，大幅减少重复网络开销。
- **瞬态故障指数退避重试 (Exponential Backoff)**：网络波动或超时自动平滑重试。
- **受控并发下载队列 (Max Concurrent = 3)**：批量下载时限流受控，避免网络阻塞或服务器限流。

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
├── glMusicApp.swift                  # 应用程序入口：全局环境注入、顶部原生菜单栏、快捷指令
├── ContentView.swift                # 主框架总控：SplitView、深层导航栈、全局快捷键、窗口材质
├── ThemeManager.swift               # 主题管理器：6套清新配色、歌词柔和渐变、持久化与色温状态
├── PlayerManager.swift               # 播放核心引擎：AVPlayer、SoundQualityType 动态音质切换、YRC 逐字解析、待播队列、系统媒体控制
├── DownloadManager.swift             # 离线下载与本地音频导入引擎：ID3提取、LRC解析、并发队列控制
├── HistoryManager.swift              # 本地播放历史记录管理器：播放足迹持久化与增删改查
├── UpdateManager.swift               # 自动更新管理器：GitHub Releases 检查、下载、替换与重启
├── LanguageManager.swift             # 国际化语言管理器：简体/英文/繁体实时免重启无缝切换
├── AudioDeviceManager.swift          # CoreAudio 音频设备管理器：输出设备枚举与热切换
├── StructModel.swift                 # 侧边栏导航定义与通用数据模型
│
├── Network/
│   ├── NetworkManager.swift          # 原生直连网络层：基于 NCMClient 的 EAPI/WeAPI 官方直连、智能换源解灰(突破VIP试听)、actor 内存缓存
│   └── APIModels.swift               # 数据模型映射：LyricLine、LyricWord、Playlist 等 (Sendable / Codable)
│
└── Views/
    ├── Sidebar.swift                 # 原生侧边栏 (发现 + 资料库 + 歌单列表 + 主题/语言入口)
    ├── PlayerBar.swift               # 底部悬浮胶囊播放栏 (进度条/音质即时切换/平滑动效音量/设备切换/待播清单/红心)
    ├── LyricsView.swift              # 全屏动态歌词视图 (悬停唤醒顶栏/双语对照/毛玻璃封面背景)
    ├── LyricsStyleSettingsView.swift # 歌词显示样式弹窗 (对齐/字号/景深虚焦/边缘渐隐) & KaraokeLyricLineView
    ├── PlaylistSquareView.swift      # 「歌单广场」视图 (全部分类标签筛选、高品质歌单瀑布流)
    ├── HistoryView.swift             # 「播放历史」专属视图 (足迹列表、一键播放、记录清理)
    ├── DownloadedSongsView.swift     # 「本地与下载」专属资料库页面 (拖拽接收/胶囊筛选/访达定位)
    ├── AudioDevicePickerView.swift   # 音频输出设备切换弹出组件
    ├── LanguagePickerView.swift      # 多语言切换弹窗
    ├── UpdateModalView.swift         # 新版本检测与升级提示弹窗
    ├── ThemePickerView.swift         # 主题选择弹出面板与网格卡片
    ├── NightBokehBackground.swift    # 城市夜景多层散景流光背景 (19个虚实景深光斑)
    ├── UnifiedSongRow.swift          # 全局通用单曲行组件 (序号/波形/封面/标题/喜欢/下载/右键菜单)
    ├── PlaybackActionBar.swift       # 全局播放操作栏 (播放全部/随机播放/下载全部)
    ├── DownloadButton.swift          # 全局三态动态下载按钮 (未下载/进度环/已下载)
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
    ├── LoginView.swift               # 二维码 / 验证码 双模式登录页面
    └── WindowToolbarAccessor.swift   # 原生窗口工具栏透明度与标题栏微调辅助器
```

---

## 🚀 快速上手与本地运行

### 环境要求
- **macOS**：macOS 14.0 (Sonoma) 或更高版本 (全面支持 macOS 15 Sequoia)
- **Xcode**：Xcode 15.0 或更高版本 (Swift 5.9 / Swift 6)
- **后端服务**：**无需配置任何外部服务**（内置 Swift 原生 SDK 直连网易云，彻底脱离 Node.js / Docker）

### 1. 克隆与打开项目
```bash
git clone https://github.com/golove/glMusic.git
cd glMusic
open glMusic.xcodeproj
```

### 2. 编译与运行
- 在 Xcode 顶部选择目标设备为 **My Mac**；
- Xcode 会通过 Swift Package Manager 自动解析并下载 `NeteaseCloudMusicAPI-Swift` 原生依赖包；
- 按下快捷键 `⌘ + R` 即可直接编译并启动应用；
- 或者在终端使用命令行编译：
```bash
xcodebuild -project glMusic.xcodeproj -scheme glMusic -destination 'platform=macOS' build
```

---

## 🛡️ 沙盒与存储机制说明

- 所有下载与导入的离线音乐、歌词与封面安全保存在用户的存储目录中：  
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
