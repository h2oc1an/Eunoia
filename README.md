<p align="center">
  <img src="Resources/logo.png" alt="讲英格力士" width="200"/>
</p>

<h1 align="center">讲英格力士</h1>

一款帮助用户通过视频学习英语的 **macOS 原生应用**，支持本地视频播放、视频语音转录（多语言识别->字幕文件）、字幕翻译（多语言->中文）、字幕生词本等功能。

## 功能特性

### 视频下载
- 支持 **YouTube** 视频下载（自动解析直链）
- 支持 **Bilibili** 视频下载（原生 API + WBI 签名）
- 支持直接视频 URL 下载（MP4/MKV/MOV 等）
- URLSession 后台下载，支持暂停/恢复
- 下载完成后可选生成字幕（WhisperKit 转录 + 翻译）
- 画质/格式选择（多格式时）

### 视频学习
- 支持本地 MP4 视频播放
- 支持 SRT/ASS 格式外挂字幕
- 字幕与视频同步显示
- 点击字幕中的单词添加到生词本
- **播放速度控制**：0.5x ~ 2.0x 倍速播放
- **记忆播放位置**：自动跳转到上次观看进度
- **书签/笔记**：在任意时间点添加书签和备注
- **播放器内生成字幕**：无字幕视频可一键转录

### 视频语音转录（多语言识别->字幕文件）
- 使用 WhisperKit 本地 AI 模型转录
- 支持三种字幕模式：原语言/中文字幕/双语字幕
- 本地运行，无需网络
- 后台执行，关闭页面不影响
- 支持查看任务列表、取消、删除
- 转录完成的视频和字幕支持导入到视频库

### 字幕翻译（多语言->中文）
- 支持两种字幕模式：中文字幕/双语字幕
- 选择 SRT/ASS 字幕文件翻译为中文
- 后台执行，关闭页面不影响
- 支持下载/分享翻译后的字幕文件

### 生词本
- 自动提取字幕中的单词
- 支持手动添加单词和例句
- SM-2 间隔重复算法安排复习

### 复习系统
- 基于 SM-2 间隔重复算法
- 科学安排复习时间
- 支持六档评分：完全忘记/困难/困难+/良好/简单/完美
- 复习完成后可再复习

### 设置与复习
整合在同一个页面：
- **设置**：学习统计、关于应用、使用帮助、重置数据
- **复习**：单词复习卡片流程

## 项目结构

```
SpeakingEnglish/
├── App/                    # 应用入口
│   ├── SpeakingEnglishApp.swift
│   ├── ContentView.swift          # NavigationSplitView + 自定义 Sidebar
│   └── macOS/
│       └── MenuBarCommands.swift   # macOS 菜单栏
├── Core/
│   ├── Models/            # 数据模型
│   │   ├── Video.swift
│   │   ├── SubtitleEntry.swift
│   │   ├── VocabularyEntry.swift
│   │   ├── VideoBookmark.swift
│   │   ├── DownloadTask.swift
│   │   └── ReviewRecord.swift
│   ├── Services/          # 核心服务
│   │   ├── DownloadService.swift           # HTTP 下载服务
│   │   ├── VideoExtractor.swift            # 视频提取器协议
│   │   ├── YouTubeExtractor.swift          # YouTube 提取器
│   │   ├── BilibiliExtractor.swift         # Bilibili 提取器
│   │   ├── TranscriptionService.swift      # WhisperKit 转录
│   │   ├── TranscriptionTaskManager.swift   # 转录任务管理
│   │   ├── TranslationService.swift        # Bing 翻译
│   │   ├── TranslationTaskManager.swift    # 翻译任务管理
│   │   ├── SubtitleParser/                # 字幕解析（SRT/ASS）
│   │   ├── SM2Algorithm.swift              # 间隔重复算法
│   │   ├── VocabularyService.swift
│   │   ├── ThumbnailService.swift           # 缩略图生成
│   │   ├── ImageCacheService.swift         # 图片缓存
│   │   └── WordExtractionService.swift
│   └── Persistence/       # 数据持久化
│       ├── DatabaseManager.swift
│       ├── VideoRepository.swift
│       ├── DownloadTaskRepository.swift
│       ├── VocabularyRepository.swift
│       └── VideoBookmarkRepository.swift
├── Features/
│   ├── Home/              # 首页视频列表
│   ├── VideoPlayer/       # 视频播放（AVPlayerView + 字幕叠加）
│   │   └── Subviews/      # 播放器子组件
│   ├── Download/          # 视频下载页面
│   ├── Transcription/     # 转录页面 + 任务列表
│   ├── Translation/       # 翻译页面 + 任务列表
│   ├── Vocabulary/        # 生词本列表/详情
│   └── Settings/          # 设置与复习整合页面
├── Shared/                # 共享组件
│   ├── SubtitleModePickerView.swift
│   ├── DocumentPicker.swift
│   ├── SubtitleListView.swift
│   ├── CachedAsyncImage.swift
│   ├── TimeFormatter.swift
│   ├── ToastView.swift
│   └── Extensions/
├── Resources/
│   ├── Assets.xcassets/   # App Icon
│   ├── Info-macOS.plist
│   ├── WhisperModels/     # WhisperKit 本地模型
│   ├── logo.png
│   └── SampleVideos/      # 示例视频目录
└── project.yml            # XcodeGen 配置
```

## 技术栈

| 类别 | 技术 |
|-----|------|
| 平台 | macOS 13.0+ 原生应用 |
| UI 框架 | SwiftUI + NavigationSplitView |
| 视频播放 | AVPlayerView (macOS 原生) |
| 视频下载 | URLSession + YouTubeKit |
| 语音识别 | WhisperKit (openai_whisper-tiny) |
| 字幕翻译 | Microsoft Translator API |
| 数据持久化 | SQLite.swift |
| 项目生成 | XcodeGen |
| 包管理 | Swift Package Manager |

## 环境要求

- Xcode 15.0+
- macOS 13.0+
- Swift 5.9

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/h2oc1an/SpeakingEnglish.git
cd SpeakingEnglish
```

### 2. 生成 Xcode 项目

```bash
# 安装 XcodeGen（如果未安装）
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate
```

### 3. 配置签名（可选）

在 Xcode 中打开生成的 `SpeakingEnglish.xcodeproj`，选择 Signing & Capabilities 配置团队账号。

> **注意**：需要开发者账号。

### 4. 添加示例视频（可选）

将 MP4 视频和对应的 SRT/ASS 字幕文件放入 `Resources/SampleVideos/` 目录。

### 5. 构建运行

```bash
# 使用 xcodebuild 构建 macOS 版本
xcodebuild -project SpeakingEnglish.xcodeproj -scheme SpeakingEnglish-macOS -configuration Debug build CODE_SIGNING_ALLOWED=NO

# 或在 Xcode 中打开项目并运行
open SpeakingEnglish.xcodeproj
```

> **注意**：运行时请选择 `SpeakingEnglish-macOS` scheme，不要选择 `My Mac (Designed for iPad)`。

## 使用说明

### 下载视频

1. 首页点击「上传」或「下载」按钮
2. 粘贴视频链接（支持 YouTube、Bilibili、直链）
3. 点击「解析并下载」，多格式时可选择画质
4. 下载完成后点击「导入」将视频添加到首页
5. 导入后可点击「转录」生成字幕（后台执行，可前往转录页面查看进度）

### 转录视频

1. 进入「转录」页面
2. 选择本地 MP4 视频文件
3. 选择字幕模式：原语言/中文字幕/双语字幕
4. 点击「开始转录」
5. 页面显示任务列表和进度
6. 转录完成后可选择：
   - 查看详情和字幕预览
   - 导入到视频库
   - 下载字幕文件

### 翻译字幕

1. 进入「翻译」页面
2. 选择 SRT/ASS 字幕文件
3. 选择字幕模式：中文字幕/双语字幕
4. 点击「开始翻译」
5. 可查看任务进度
6. 翻译完成后可下载/分享

### 观看视频学习

1. 在首页选择已上传的视频
2. 视频播放时字幕同步显示
3. 点击任意单词添加到生词本
4. 在生词本中查看释义和例句

### 复习记忆

1. 进入「设置」页面
2. 切换到「复习」标签
3. 根据记忆情况选择评分
4. 系统使用 SM-2 算法安排下次复习时间
5. 定期复习直到完全掌握

### 设置

- **学习统计**：查看总单词数、待复习数、今日已学
- **关于应用**：应用介绍和版本信息
- **使用帮助**：使用说明和常见问题
- **数据重置**：清除所有本地数据

## 其他

1. **转录模型**：使用 openai_whisper-tiny，已预置在 `Resources/WhisperModels/` 目录，无需下载
2. **翻译API**：使用 Microsoft Translator API，需要网络连接

## License

See [LICENSE](LICENSE) for details.
