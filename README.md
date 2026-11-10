<p align="center">
  <img src="glMusic/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="glMusic Icon" />
</p>

<h1 align="center">glMusic</h1>

<p align="center">
  <strong>一款基于 Swift & SwiftUI 构建的现代 macOS 原生高颜值音乐播放器</strong><br>
  深度融合 macOS 设计规范，呈现极致 Apple Music 视觉质感、原生 SDK 官方直连、智能换源解灰、桌面悬浮歌词与极低能耗沉浸听歌体验。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Release-v0.3.9-0071e3?style=flat-square" alt="Version" />
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

更进一步，本项目现已全面集成 **NeteaseCloudMusicAPI-Swift** 原生 SDK 与智能换源解灰引擎，**彻底移除了对外部 Node.js 本地服务的依赖**，客户端直接与网易云官方服务器高并发加密通信；同时支持 **VIP 歌曲 30s/45s 试听限制自动换源破解**、**PlayerBar 原生全音质自由切换 (SoundQualityType)**、**无爆音平滑换轨与音频自然交叉渐变 (Crossfade)**。

整体 UI 严格遵循 **macOS Human Interface Guidelines (HIG)**，高度还原 macOS 原生 **Apple Music** 的界面层次感与精致质感——包含原生窗口半透毛玻璃材质、梦幻城市夜景散景流光背景、自适应多色清新主题、悬浮胶囊播放条、**全功能桌面悬浮歌词系统**、**菜单栏状态栏迷你控制器**、**毫秒级 YRC 逐字卡拉OK歌词**、**歌词排版自定义系统**、**音频输出设备即时热切换**、**自建歌单管理**、**多语言国际化支持**、**可信原子自动更新**、全功能本地音频导入、离线无损下载管理以及完整的广播与播客电台系统。

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

### 2. 🪟 独立桌面悬浮歌词系统 (Desktop Lyrics Window)
- **原生独立悬浮面板 (`DesktopLyricsPanel`)**：
  - 采用系统级 `NSPanel` 创建无边框置顶悬浮窗，支持全屏游戏与多应用工作时常驻桌面；
  - **防穿透与锁定模式**：支持一键锁定歌词窗口（`⇧ + ⌘ + L`），锁定后鼠标事件完全穿透至下层桌面，右上角智能显现胶囊解锁按钮；
  - **无级尺寸拖拽与字号调节**：支持通过右下角拉手实时调整窗口尺寸，并提供 `A-` / `A+` 无级字号调节；
  - **3 套背景风格自由切换**：深黑半透毛玻璃 (Dark Glass)、浅白高透毛玻璃 (Light Glass)、完全透明 (Transparent)；
  - **智能双行排版与翻译对照**：第一行毫秒级逐字高亮，第二行自适应呈现双语翻译或下一句预告。

### 3. 🎛️ 状态栏常驻迷你控制器 (MenuBar Mini Player)
- **原生 macOS 菜单栏常驻交互**：
  - 系统菜单栏右侧常驻自定义极简透明音乐音符图标，轻点即刻弹出轻量交互控制器；
  - 呈现高精度微缩专辑封面、曲名与歌手、播放/暂停/切歌、交互式进度滑块、喜欢、实时音量控制；
  - 提供快捷切换桌面悬浮歌词与唤醒主界面的快捷操作。

### 4. 🎵 音频无爆音微淡出与自然交叉渐变引擎 (Micro-Fade Transition & Seamless Crossfade)
- **无爆音平滑换轨引擎 (Micro-Fade Transition Engine)**：
  - 用户手动切歌或换轨时，执行 **20ms 快速微淡出 + 静音安全换轨 + 35ms 优雅微淡入**，彻底消灭 PCM 波形截断产生的硬电爆音与收音机杂音；
  - 接入快速连点切歌防抖缓冲机制与会话令牌 (`UUID SessionId`)，高频切歌不串音。
- **音频平滑交叉渐变 (Natural Crossfade)**：
  - 歌曲末尾自动启用双 AVPlayer 实例进行自然淡出与淡入交叠过渡（时长可在菜单栏自定义）；
  - 结合播放结束通知拦截机制，在两曲交界处平滑无缝升格为主播放器，彻底解决曲末切歌时下一曲开头跳闪与重播问题。

### 5. 🎤 逐字卡拉OK动效与极致渲染管线 (Karaoke & High-Performance Rendering)
- **官方毫秒级 YRC 逐字时间轴引擎**：
  - 自动对接网易云官方高级歌词接口，提取毫秒级 `yrc` 逐字时间轴数据；
  - 遇到长音拖拽时流光精准对齐，间奏停顿流光自动暂停，发音秒级同步点亮；
  - 针对无逐字轴的标准歌词，内置基于字数与语速的自适应演唱时长估算算法。
- **GPU 几何 Alpha 遮罩宽度裁剪（0 CoreText 排版重构）**：
  - 告别高频重构 `LinearGradient` 造成的着色器与文本反复排版开销；
  - 底层常驻静态暗色文本，顶层常驻静态主题色文本，仅由 CoreAnimation 改变顶层图层 Mask 几何宽度（附带 8pt 边缘平滑羽化），大幅消减 CPU 开销。
- **SwiftUI 视图树 Equatable 隔离**：
  - 歌词行全面接入 `Equatable` 协议，行切换时仅重新求值 2 行（上一行与当前行），**跳过其余 98% 的非活动行计算**；
  - 仅活跃行私有子视图挂载时间监听，非活跃行 0 重绘。
- **歌词样式全功能自定义面板 (`LyricsStyleSettingsPopover`)**：
  - **排版对齐**：经典居左对齐 / 沉浸大幕居中对齐；
  - **字号规格**：标准 (24pt) / 放大 (30pt) / 巨幕 (36pt)；
  - **动效模式**：实时逐字卡拉OK扫光 / 经典聚光灯聚焦；
  - **景深虚焦效果 (Depth Blur)**：采用原生对比度与透明度衰减，0 GPU 卷积滤镜损耗；
  - **双语翻译对照**：外语歌词中文对照自由开关；
  - **上下边缘渐隐**：顶部与底部 48~64pt 柔和羽化遮罩。

### 6. ⚡️ 能耗与性能极致优化 (Energy Efficiency & Resource Budget)
- **真实仪器采样能耗基准 (Time Profiler Verified)**：
  - **主界面静置播放**：平均 CPU 占用率稳定在约 **6.2%**（主要为 CoreAudio 原生硬件解码开销）；
  - **全屏动态逐字歌词展开**：平均 CPU 占用率稳定在约 **12% ~ 14%**（与 Apple Music 原生全屏歌词处于同一水准）；
  - **全屏经典聚光灯模式**：平均 CPU 占用率稳定在约 **6% ~ 7%**。
- **自适应时间观察器分频 (Adaptive Tick Throttling)**：
  - 在未打开歌词页面或选择聚光灯模式时，AVPlayer 时间广播自动降频至 **~3.3Hz（每 300ms 一次）**，消减 66% 主线程无意义唤醒；
  - 仅在进入逐字歌词模式时以 10Hz 全频响应保障丝滑。
- **1Hz 秒级时钟解耦**：
  - 播放时间文本解耦为独立的 `currentSecond: Int`，每秒仅排版计算 1 次，消减 90% 的字符串拼接。
- **内存热缓存机制 (Hot Data Cache)**：
  - 首页横幅、推荐歌单与榜单接入 `HomeDataCache` 与 `BrowseDataCache`，二次浏览毫秒级秒开。

### 7. 🔐 系统级安全与数据持久化强化 (Security & Data Integrity)
- **macOS Keychain 钥匙串集成 (`KeychainHelper`)**：
  - 用户登录凭据与敏感 Cookie 统一通过系统安全钥匙串（`kSecClassGenericPassword`）加密存储，彻底告别明文 UserDefaults 存储；
  - 启动时自动无缝从旧版配置迁移至 Keychain。
- **APICache 安全哈希与 150MB LRU 磁盘配额**：
  - 采用 CryptoKit SHA-256 哈希命名磁盘缓存，彻底杜绝特殊字符与 URL 路径冲突；
  - 引入 150MB 磁盘缓存预算与 LRU（最近最少使用）自动淘汰清理机制，防止磁盘空间无限膨胀。
- **严格单所有权下载管理器 (`@MainActor DownloadManager`)**：
  - 集中并发状态至主线程调度器，彻底废弃 `@unchecked Sendable`；
  - 采用清晰的任务生命周期状态机，杜绝并发下载与失败重试时的计数不平衡与数据竞争。

### 8. 🔄 可信安装链与原子自动更新 (Atomic Auto-Updater with Rollback)
- **包完整性与 Codesign 代码签名校验**：
  - 安装更新前自动通过系统 `codesign --verify --deep --strict` 验证二进制与 Bundle 完整性；
  - 全流程检查 `Process.terminationStatus` 退出码，解压、挂载与复制任何一步失败立即终止。
- **原子备份与失败自动秒级回滚 (`.glmusic_backup`)**：
  - 替换旧 App 前先重命名为备份副本，ditto 写入失败时自动原子级原地恢复旧版本，坚决避免更新失败导致应用损毁无法启动。

### 9. 📁 自建歌单与资料库系统 (Custom Playlists & Library)
- **自建本地歌单管理 (`CustomPlaylistManager`)**：
  - 支持创建任意多个个性化歌单、编辑歌单名称与封面；
  - 任意歌曲右键即可一键「添加到歌单」；
  - 详情页采用与官方歌单一致的吸顶常驻头部与返回按钮联动布局。
- **全功能「本地音乐导入」**：
  - 支持从访达（Finder）直接拖拽单曲、多曲或文件夹导入；
  - 全面支持 `MP3`、`FLAC`、`M4A`、`WAV`、`AAC`、`AIFF`、`ALAC`、`OGG`；
  - 自动提取音频内嵌高清封面与 ID3 元数据，优先匹配同目录同名伴生 `.lrc` 文件。

### 10. 🔊 原生音频输出设备切换与流体音量交互 (Audio Device & Fluid Volume System)
- **CoreAudio 系统级音频输出即时切换**：
  - 随时在内置扬声器、AirPods、蓝牙耳机、HDMI 外接显示器、USB 专业声卡之间热切换，并自动标注 AirPods 专属标识。
- **SF Symbols 5 原生分层逐级动效**：
  - 调节音量时喇叭锥体定点居左锚定，弧线逐层生长或褪去，彻底消除生硬硬切与滑块水平震颤。
- **全局一键快速静音与恢复**：点击喇叭图标一键静音，再次点击平滑恢复此前音量。

### 11. 🎨 6 套清新自然主题配色系统 (Adaptive Color Themes)
- 🌿 **薄荷清风 (Mint Breeze)**：灵动清凉，初春微风般听觉呼吸感；
- 🌊 **海风清蓝 (Sea Breeze)**：澄澈蔚蓝，视野辽阔宁静，还原 Apple 经典水蓝意境；
- 🌸 **樱花柔粉 (Sakura Pink)**：温润轻盈，升华原生 Apple Music 经典粉质感；
- 🍵 **抹茶初夏 (Matcha Green)**：自然素雅，森林系治愈色调，柔和护眼；
- 🍑 **蜜桃日落 (Peach Sunset)**：元气甜橙，落日余晖洒在唱片机上；
- 🪻 **薰衣草紫 (Lavender Mist)**：梦幻罗兰，雅致轻奢，夜间聆听绝佳。

### 12. 🌐 国际化多语言支持 (Multi-Language Localization)
- 全面支持 **简体中文 (zh-Hans)**、**English**、**繁體中文 (zh-Hant)** 三种语言环境；
- 支持在应用内即时热切换语言，全局秒级更新，无需重启应用。

---

## ⌨️ 全局键盘快捷键

| 快捷键 | 功能描述 |
| :--- | :--- |
| `Space` (空格键) | 播放 / 暂停当前歌曲 |
| `⌘ + →` | 下一首 |
| `⌘ + ←` | 上一首 |
| `⌘ + ↑` | 增加音量 (+5%) |
| `⌘ + ↓` | 降低音量 (-5%) |
| `⌘ + L` | 打开 / 关闭全屏动态歌词页面 |
| `⇧ + ⌘ + D` | 打开 / 隐藏**桌面悬浮歌词** |
| `⇧ + ⌘ + L` | **锁定 / 解锁**桌面歌词窗口 |
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
├── PlayerManager.swift               # 播放核心引擎：AVPlayer、SoundQualityType 切换、交叉渐变换轨、时钟分频
├── LyricsService.swift               # 歌词领域服务：YRC 逐字解析、LRC 对齐、翻译匹配、O(1) 索引搜索
├── NowPlayingService.swift           # 系统级媒体集成：MPNowPlayingInfoCenter、MPRemoteCommandCenter、锁屏控制
├── DesktopLyricsManager.swift        # 桌面歌词管理器：独立 NSPanel 置顶窗口控制、尺寸调节、锁定穿透
├── CustomPlaylistManager.swift       # 自建本地歌单持久化管理器：歌单创建、增删改查
├── DownloadManager.swift             # 离线下载与本地导入引擎：@MainActor 集中并发调度、ID3提取、LRC关联
├── HistoryManager.swift              # 本地播放历史记录管理器：播放足迹持久化与增删改查
├── UpdateManager.swift               # 可信自动更新管理器：Codesign 校验、原子备份回滚、下载替换
├── LanguageManager.swift             # 国际化语言管理器：简体/英文/繁体实时免重启无缝切换
├── AudioDeviceManager.swift          # CoreAudio 音频设备管理器：输出设备枚举与热切换
├── StructModel.swift                 # 侧边栏导航定义与通用数据模型
│
├── Network/
│   ├── NetworkManager.swift          # 原生直连网络层：基于 NCMClient 的 EAPI/WeAPI 官方直连、智能换源解灰
│   ├── KeychainHelper.swift          # 系统钥匙串辅助类：安全保存敏感用户 Cookie 与 Token
│   └── APIModels.swift               # 数据模型映射：LyricLine、LyricWord、APISong 等 (Sendable / Codable)
│
└── Views/
    ├── Sidebar.swift                 # 原生侧边栏 (发现 + 资料库 + 自建歌单列表 + 主题/语言入口)
    ├── PlayerBar.swift               # 底部悬浮胶囊播放栏 (进度条/音质即时切换/平滑动效音量/设备切换/待播清单/红心)
    ├── MenuBarView.swift             # 系统状态栏常驻下拉迷你播放器组件
    ├── LyricsView.swift              # 全屏动态歌词视图 (悬停唤醒顶栏/双语对照/毛玻璃封面背景/Equatable隔离)
    ├── LyricsStyleSettingsView.swift # 歌词显示样式弹窗 (对齐/字号/景深虚焦/边缘渐隐) & GPU 遮罩卡拉OK组件
    ├── DesktopLyricsView.swift       # 桌面悬浮歌词窗口视图 (深黑/浅白/透明样式、A-/A+字号调节、锁定解锁)
    ├── CustomPlaylistDetailView.swift# 自建歌单详情页 (吸顶常驻头部联动、歌曲管理)
    ├── SongCoverThumbnailView.swift  # 统一封面缩略图组件 (异步加载、磁盘缓存)
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
    └── WindowToolbarAccessor.swift   # 原生窗口工具栏透明度与标题栏微调辅助器 (单次配置防循环)
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
- 或者在终端使用命令行构建 Release 包：
```bash
xcodebuild -project glMusic.xcodeproj -scheme glMusic -destination 'platform=macOS' -configuration Release build
```

---

## 🛡️ 沙盒与存储机制说明

- **离线音乐与歌词存储**：  
  所有下载与导入的离线音乐、歌词与封面安全保存在专属存储沙盒目录中：  
  `~/Library/Containers/com.golove.glMusic/Data/Documents/Downloads/`
- **安全凭证存储**：  
  网易云账号 Cookie 与认证凭据安全存放在 macOS 系统的加密 Keychain 钥匙串中。
- 支持通过 `NSWorkspace` 原生唤醒访达直接高亮定位目标音频文件，无需额外的外部文件读写授权弹窗。

---

## ⚠️ 常见问题排查 (FAQ)

### 安装后 macOS 提示「文件已损坏，无法打开」？
由于 macOS Gatekeeper 安全机制，从第三方渠道下载未经过 Apple 公证签名的发布包可能被系统隔离。请在终端执行以下命令解除安全隔离限制：
```bash
sudo xattr -dr com.apple.quarantine /Applications/glMusic.app
```

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 许可证开源，仅供学习、交流与技术研究使用。音乐版权归各大唱片公司与音乐平台所有。
