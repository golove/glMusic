<p align="center">
  <img src="public/logo.png" width="128" height="128" alt="glMusic Icon" />
</p>

<h1 align="center">glMusic (Rust Client for Windows)</h1>

<p align="center">
  <strong>基于 Rust + Tauri 2.0 构建的现代原生高颜值网易云音乐客户端 (Windows 专享优化版)</strong><br>
  传承 glMusic (macOS 原生版) 极致 Apple Music 视觉质感，全面集成 <code>ncm-api-rs v0.1.0</code> 原生 SDK 与智能换源解灰引擎。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Release-v0.3.5-0071e3?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011%20(x64)-0078d4?style=flat-square&logo=windows" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Rust%202021%20%2F%20TypeScript-F05138?style=flat-square&logo=rust" alt="Language" />
  <img src="https://img.shields.io/badge/Framework-Tauri%202.0%20%2B%20Vue%203-0071e3?style=flat-square" alt="Framework" />
  <img src="https://img.shields.io/badge/API-ncm--api--rs%20v0.1.0-brightgreen?style=flat-square" alt="API" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License" />
</p>

---

## 📖 项目简介

本项目为 **glMusic** 的 Windows 原生轻量客户端工程（后续将另起独立分支支持 Linux）。后端完全使用 **Rust** 编写，通过整合网易云音乐原生 Rust SDK **`ncm-api-rs` (v0.1.0)** 直接与网易云服务器加密直连通信，**彻底摆脱对外部 Node.js 服务的依赖**。

### ✨ Windows 专属优化体验：
- 🪟 **沉浸式无边框磨砂窗口**：告别 Windows 传统白条标题栏，配合自定义顶部控制栏（历史前进/后退、实时播放状态、最小化/最大化/关闭按钮与双击最大化拖拽）。
- 🎨 **极致 Windows 字体抗锯齿排版**：全面优化 ClearType 文本渲染，超细长半透明微光滚动条。
- 🌆 **拟真 19 光斑城市夜景流光背景**：支持 GPU 硬件 3D 合成加速，提供“全效”、“轻量节能”、“极简暗黑”三档性能模式切换。
- 🎤 **Apple Music 风格全屏沉浸歌词**：支持弹性缩放呼吸高亮、上下视野柔和渐隐，以及“译文对照”与“大字/标准”字号即时切换。
- 💊 **悬浮胶囊播放条 (PlayerBar)**：全音质自由切换 (标准 / 极高 / 无损 / Hi-Res)、可点击歌手/专辑跳转详情页。
- 🔓 **VIP 试听限制自动换源与解灰**：内置 GD 音乐台全曲 320k 匹配引擎，破解 VIP 30s/45s 试听限制。
- 📱 **网易云官方二维码扫码登录**：支持手机端网易云音乐扫一扫登录，会话 Cookie 跨平台自动安全持久化存储。

---

## 📦 项目架构

```
glMusicRust/
├── src-tauri/                 # Rust 后端核心
│   ├── Cargo.toml            # 依赖配置：ncm-api-rs = "0.1.0", tauri = "2.0", tokio
│   ├── tauri.conf.json       # Tauri 窗口与多平台打包配置
│   └── src/
│       ├── main.rs           # 应用入口 (Windows / Linux)
│       ├── lib.rs            # Tauri 注册与初始化
│       ├── ncm.rs            # 基于 ncm-api-rs v0.1.0 的网易云核心服务
│       ├── unblock.rs        # VIP 试听破解与智能换源引擎
│       └── commands.rs       # 暴露给前端的高性能 IPC 命令
├── src/                      # 前端交互与 UI (Vue 3 + TypeScript)
│   ├── stores/player.ts      # 响应式全局播放器引擎
│   ├── services/api.ts       # 封装 Tauri IPC 与数据映射
│   ├── types/music.ts        # TypeScript 数据模型定义
│   ├── components/
│   │   ├── NightBokehBackground.vue  # 19 光斑拟真夜景流光背景
│   │   ├── Sidebar.vue               # macOS HIG 质感毛玻璃侧边导航
│   │   ├── PlayerBar.vue             # 悬浮胶囊播放条与音质切换
│   │   ├── LyricsView.vue            # Apple Music 风格全屏动效歌词
│   │   ├── QueueDrawer.vue           # 播放队列抽屉
│   │   └── LoginModal.vue            # 网易云二维码扫码登录弹窗
│   └── views/                        # 各大核心功能页面
├── .github/workflows/        # GitHub Actions 自动化多平台构建
│   └── release.yml           # 自动化构建 Windows (.msi/.exe) 与 Linux (.deb/.AppImage)
├── Dockerfile.linux          # Linux 独立打包容器
└── scripts/
    ├── build-windows.sh      # Windows 打包脚本
    └── build-linux.sh        # Linux 打包脚本
```

---

## 🚀 编译与构建 (Windows & Linux)

### 方式一：利用 GitHub Actions 云端一键打包（推荐，无需本地配置环境）

仓库内置了完整的 `.github/workflows/release.yml`：
1. 将代码推送到 GitHub 仓库并打一个版本标签（例如 `v0.3.5`）：
   ```bash
   git tag v0.3.5
   git push origin v0.3.5
   ```
2. GitHub Actions 将自动在云端微软 Windows 与 Ubuntu 环境中并行编译：
   - **Windows**：自动生成 `glMusic_0.3.5_x64-setup.exe` 和 `.msi` 安装包。
   - **Linux**：自动生成 `glMusic_0.3.5_amd64.deb` 和 `glMusic.AppImage` 免安装单文件。

---

### 方式二：在 Windows 本地编译构建

#### 环境要求：
- [Rust](https://www.rust-lang.org/) (MSVC 工具链：`rustup default stable-x86_64-pc-windows-msvc`)
- [Node.js](https://nodejs.org/) (v18+) 与 [pnpm](https://pnpm.io/)
- C++ 生成工具 (Visual Studio Build Tools，勾选 "C++ 桌面开发")

#### 执行构建：
```powershell
# 1. 安装前端依赖
pnpm install

# 2. 调试运行
pnpm tauri dev

# 3. 打包生成 Windows 安装包 (.exe / .msi)
pnpm tauri build
```
打包成功后，可在 `src-tauri/target/release/bundle/nsis/` 中找到安装程序。

---

### 方式三：在 Linux (Ubuntu / Debian / Arch / Fedora) 本地编译构建

#### 环境要求（以 Ubuntu / Debian 为例）：
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    curl \
    libwebkit2gtk-4.1-dev \
    libappindicator3-dev \
    librsvg2-dev \
    patchelf \
    libasound2-dev \
    libssl-dev \
    pkg-config
```

#### 执行构建：
```bash
# 1. 安装前端依赖
pnpm install

# 2. 调试运行
pnpm tauri dev

# 3. 打包生成 Linux 安装包 (.deb / .AppImage)
pnpm tauri build
```
打包生成的文件位于 `src-tauri/target/release/bundle/deb/` 与 `src-tauri/target/release/bundle/appimage/`。

---

### 方式四：在 macOS 上通过 Docker 构建 Linux 版本

如果你当前在 macOS 上开发，也可以直接运行 Docker 构建 Linux 原生包：
```bash
./scripts/build-linux.sh
```

---

## ⌨️ 快捷键

| 快捷键 | 功能 |
| :--- | :--- |
| <kbd>Space</kbd> | 播放 / 暂停 |
| <kbd>Ctrl / Cmd</kbd> + <kbd>→</kbd> | 下一首 |
| <kbd>Ctrl / Cmd</kbd> + <kbd>←</kbd> | 上一首 |
| <kbd>Ctrl / Cmd</kbd> + <kbd>↑</kbd> | 增加音量 (+5%) |
| <kbd>Ctrl / Cmd</kbd> + <kbd>↓</kbd> | 降低音量 (-5%) |

---

## 📄 开源许可

本项目遵循 [MIT License](LICENSE)。
网易云音乐 API 底层由 [ncm-api-rs](https://crates.io/crates/ncm-api-rs) 提供支持。
音乐版权归网易云音乐及各唱片公司所有，本项目仅供交流学习使用。
