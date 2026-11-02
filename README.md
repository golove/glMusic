<p align="center">
  <img src="glMusic/Assets.xcassets/AppIcon.appiconset/AppIcon-5 1.png" width="128" height="128" alt="glMusic Icon" />
</p>

<h1 align="center">glMusic</h1>

<p align="center">
  <strong>一款基于 Swift & SwiftUI 构建的现代 macOS 原生音乐播放器</strong><br>
  深度融合 macOS 设计规范，呈现极致 Apple Music 视觉质感与沉浸听歌体验。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-black?style=flat-square&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Swift%205%20%2F%206-F05138?style=flat-square&logo=swift" alt="Language" />
  <img src="https://img.shields.io/badge/Framework-SwiftUI%20%2F%20Combine-0071e3?style=flat-square" alt="Framework" />
  <img src="https://img.shields.io/badge/API-NeteaseCloudMusicApi-red?style=flat-square" alt="API" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" />
</p>

---

## 📖 项目简介

**glMusic** 是一款面向 macOS 桌面平台打造的高颜值、高性能音乐流媒体客户端。应用采用全原生 **SwiftUI + Swift Concurrency** 技术栈编写，彻底告别 Electron 等混合架构的高内存占用与卡顿。

整体 UI 严格遵循 **macOS Human Interface Guidelines (HIG)**，高度还原 macOS 原生 **Apple Music** 的界面层次感与精致质感——包含自适应毛玻璃材质、浮动胶囊播放条、动态专辑色全屏双语歌词、离线无损下载管理以及完整的广播与播客电台系统。

---

---
### 效果图
<img src="glMusic/Assets.xcassets/preview image/Screenshot1.imageset/Screenshot1.png" >
<img src="glMusic/Assets.xcassets/preview image/Screenshot2.imageset/Screenshot2.png" >
---

## ✨ 核心特性

### 1. 🎨 原生 Apple Music 交互美学
- **NavigationSplitView 响应式三栏/两栏布局**：自然适配不同显示器与窗口尺寸变化，无多余边框。
- **悬浮胶囊播放栏 (Floating PlayerBar)**：底部毛玻璃拟物化胶囊，集成播放进度、音量拖拽、封面悬浮卡、喜欢红心与待播清单弹出窗口。
- **智能焦点与辅助功能优化**：针对 macOS 键盘导航（Full Keyboard Access）深度定制，鼠标点击即时解焦，杜绝冷启动时出现刺眼的焦点红框；支持 Tab 键纯键盘操作。

### 2. 🎤 沉浸式动效全屏歌词 (Apple Music Style)
- **动态封面主色光斑背景**：根据当前播放歌曲的封面提取主色调，辅以多层高斯模糊与暗角滤镜，打造柔和梦幻的视觉背景。
- **双语同步高亮滚动**：支持中文原文 + 译文双行对照，伴随毫秒级播放进度平滑升降高亮。
- **精准点击寻道**：轻点任意歌词行立即精确跳转播放进度（Seek）。
- **视口自适应防撑爆**：精准适配 macOS `hiddenTitleBar` 模式，避让左上角交通灯区域，支持 `ESC` 或手势快捷返回。

### 3. 💾 本地音乐下载与零延迟离线播放
- **全套离线资产闭环**：下载时按「无损 (Lossless) $\to$ 极高 (ExHigh) $\to$ 标准 $\to$ 解灰备用源」智能嗅探最佳音源，同步离线保存 `.lrc` 双语歌词与高清 `.jpg` 封面。
- **零缓冲本地即起播放**：已下载曲目在离线状态下直接以沙盒 `file://` 协议秒级起播，即使断网亦能顺畅同步动态歌词。
- **专属「已下载」资料库页面**：
  - 实时展示曲目总数与本地磁盘占用空间（例如 `18 首歌曲 · 142.6 MB`）；
  - 提供快捷「全部播放」、「随机播放」、「在访达中显示文件夹」；
  - 实时本地搜索过滤，按歌名、歌手、专辑即时检索；
  - 单曲一键「在访达中定位」与快捷删除，防误触二次确认。

### 4. 📻 全功能广播与深度播客 (Radio & DJ)
- **焦点电台横幅 (Focus Banners)**：大尺寸轮播大卡片，悬停微动效与粉色圆形播放环，点击即刻试听。
- **热门推荐电台**：精选热门电台卡片展示，支持悬停一键快速连播与详情展开。
- **今日热门广播节目榜**：Top 排行榜双列速递布局，展示收听量、节目时长、单曲收藏与离线下载。
- **全品类探索与电台详情页**：音乐播客、情感生活、脱口秀、有声书、二次元、电音等分类自由切换；支持进入电台详情页浏览历史节目排期并批量播放。

### 5. 🎵 完善的曲库与探索体验
- **现在就听 (Home)**：精选聚焦 Banner（单曲/专辑/歌单/网页全业务流分发）、推荐歌单、新歌速递。
- **每日推荐 (Daily Recommend)**：日历卡片设计，每天 6:00 自动更新专属推荐曲目。
- **专辑详情 (Album Detail) & 艺人主页 (Artist Detail)**：多层级导航栈（NavigationStack），常驻吸顶返回栏，专辑曲目列表与歌手热门 Top 50 榜单。
- **待播清单 (Queue)**：点击播放条列表按钮弹出，实时高亮当前音轨，支持插播（下一首播放）、单曲移除与一键清空。
- **喜欢与收藏**：全界面红心联动网易云 `/like` API，实时同步个人喜欢曲目。
- **登录中心 (Login)**：支持短信验证码与二维码扫码双模式登录，同步用户自建与收藏歌单。

---

## ⌨️ 全局键盘快捷键

| 快捷键 | 功能描述 |
| :--- | :--- |
| `Space` (空格键) | 播放 / 暂停当前歌曲 |
| `⌘ + →` | 下一首 |
| `⌘ + ←` | 上一首 |
| `⌘ + ↑` | 增加音量 (+5%) |
| `⌘ + ↓` | 降低音量 (-5%) |
| `⌘ + [` | 返回上一级页面 |
| `ESC` | 退出全屏动态歌词视图 |
| `Tab` | 切换界面焦点元素进行键盘导航 |

---

## 🛠️ 项目架构

```
glMusic/
├── glMusicApp.swift                  # 应用程序入口，注入全局环境与状态
├── ContentView.swift                # 主框架总控：SplitView、深层导航栈、全局快捷键
├── StructModel.swift                 # 侧边栏及基础模型定义
├── DownloadManager.swift             # 离线下载管理器：URLSession并发管理、沙盒存储、元数据持久化
├── PlayerManager.swift               # 播放核心：AVPlayer控制、歌词同步解析、待播队列、状态记忆
│
├── Network/
│   ├── NetworkManager.swift          # 网易云 API 客户端请求封装 (Async/Await)
│   └── APIModels.swift               # 数据模型映射 (Codable / Sendable)
│
└── Views/
    ├── Sidebar.swift                 # 原生侧边栏 (资料库 + 广播 + 歌单列表)
    ├── PlayerBar.swift               # 底部悬浮胶囊播放栏
    ├── LyricsView.swift              # Apple Music 风格全屏动态模糊双语歌词
    ├── DownloadButton.swift          # 全局三态动态下载按钮 (未下载/进度环/已下载)
    ├── DownloadedSongsView.swift     # 「已下载」专属本地资料库管理页
    ├── HomeView.swift                # 「现在就听」主页：聚焦横幅、推荐歌单、新歌网格
    ├── RadioView.swift               # 「广播」主页：电台横幅、热门推荐、节目榜单、分类探索
    ├── RadioDetailView.swift         # 电台与播客详情页 (常驻吸顶导航与节目单)
    ├── DailyRecommendView.swift      # 「每日推荐」日历卡片页
    ├── PlaylistDetailView.swift      # 歌单详情页
    ├── AlbumDetailView.swift         # 专辑详情页
    ├── ArtistDetailView.swift        # 歌手详情页
    ├── QueueView.swift               # 待播清单弹出面板
    ├── SearchView.swift              # 音乐搜索与热搜榜
    ├── SongsView.swift               # 歌曲排行榜列表
    ├── AlbumsView.swift              # 新碟上架网格
    ├── ArtistsView.swift             # 热门歌手网格
    ├── RecentlyAddedView.swift       # 最近添加
    └── LoginView.swift               # 二维码 / 验证码 双模式登录页面
```

---

## 🚀 快速上手与本地运行

### 环境要求
- **macOS**：macOS 14.0 (Sonoma) 或更高版本 (支持 macOS 15 Sequoia)
- **Xcode**：Xcode 15.0 或更高版本
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

## 🛡️ 沙盒与文件权限说明

- 本应用开启了标准 macOS App Sandbox（`com.apple.security.app-sandbox = true`）；
- 所有下载的离线音乐、歌词与封面安全保存在用户的沙盒存储目录中：  
  `~/Library/Containers/com.golove.glMusic/Data/Documents/Downloads/`
- 支持通过 `NSWorkspace` 原生唤醒访达直接高亮定位目标音频文件，无需额外的外部文件读写授权弹窗。

---


---
## ⚠️安装后提示文件损坏打不开
***终端运行下面这条命令***
```bash
 xattr -dr com.apple.quarantine /Applications/glMusic.app
 ```
 

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 许可证开源，仅供学习、交流与技术研究使用。音乐版权归各大唱片公司与音乐平台所有。
