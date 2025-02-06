# Adobe Downloader

![preview](imgs/Adobe%20Downloader.png)

# **[English version](readme-en.md)**

## 使用须知

> ⚠️ 本仓库不支持任何 Pr 提交

**🍎仅支持 macOS 12.0+**

> **如果你也喜欢 Adobe Downloader, 或者对你有帮助, 请 Star 仓库吧 🌟, 你的支持是我更新的动力**
>
> 1. 在对Adobe产品进行安装前，系统必须存在 Adobe Setup 组件，否则无法使用安装功能，可通过程序内置的"设置"
     中进行下载，或前往[Adobe Creative Cloud](https://creativecloud.adobe.com/apps/download/creative-cloud)进行下载
> 2. 为了能够在下载后顺利安装，Adobe Downloader 需要对 Adobe 的 Setup
     程序做出修改，该过程由程序全自动，无需用户介入，非常感谢 [QiuChenly](https://github.com/QiuChenly)
     提供的解决方案
> 3. 如果在使用过程中遇到问题， 请通过 Telegram 联系我: [@X1a0He](https://t.me/X1a0He_bot) , 或者使用 Python
     版本，非常感谢 [Drovosek01](https://github.com/Drovosek01)
     的 [adobe-packager](https://github.com/Drovosek01/adobe-packager)
> 4. ⚠️⚠️⚠️ **Adobe Downloader 中的所有 Adobe 应用均来自 Adobe 官方渠道，并非破解版本。**
> 5. ❌❌❌ **不要将下载目录设置为外接移动硬盘或者USB设备，这会导致出现权限问题，我并没有时间也没有耐心处理任何权限问题**

## 常见问题

**这里会不定时更新一些 issues 出现过的，并且有意义的问题**

### **[NEW] 关于 错误代码 和 Helper 的问题**

在 1.3.0 版本以前，由于没有获取到 root 权限或者更高的权限，导致非常多的操作都需要用户输入密码

所以，我们在 1.3.0 版本中引入了 Helper 的机制，只需要安装了 Helper 后续的 Setup 组件处理，产品安装均不再需要输入密码

也许你会在右上角看到相关提示，请放心，你的系统非常安全，这是因为 macOS 的 Helper 机制和签名的弹窗

如果你还担心存在问题，请找专业人士查阅相关代码，尽管这是徒劳

### **相关错误代码解释**

- 2700: 不太可能会出现，除非 Setup 组件处理失败了
- 107: 所下载的文件架构与系统架构不一致或者安装文件被损坏
- 103: 出现权限问题，请确保 Helper 状态正常
- 182: 文件不齐全或文件被损坏，或者你的Setup组件不一致，请重新下载 X1a0He CC
- 133: 系统磁盘空间不足
- -1: Setup 组件未处理或处理失败，请联系开发者
- 195: 所下载的产品不支持你当前的系统
- 146: 请在 Mac 系统设置中给予 Adobe Downloader 全磁盘权限
- 255: Setup 组件需要更新，请联系开发者解决

### 关于 setup 组件的问题

> 使用须知中强调了，如果需要使用安装功能，那么就必须对 Adobe 的 setup 组件进行修改处理，你可以在代码中找到

为什么要处理，因为不处理无法安装，会出现2700错误代码

> **setup处理是否需要用户手动处理？**

并不需要，Adobe Downloader已完成了全自动处理且备份 setup 组件的功能

<a href="https://star-history.com/#X1a0He/Adobe-Downloader&Timeline">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=X1a0He/Adobe-Downloader&type=Timeline&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=X1a0He/Adobe-Downloader&type=Timeline" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=X1a0He/Adobe-Downloader&type=Timeline" />
 </picture>
</a>

## 📔 最新日志

- 更多关于 App 的更新日志，请查看 [Update Log](update-log.md)

- 2025-02-06 更新日志

```markdown
1. 修复了当任务下载完成后，退出程序重新进入时，状态显示非已完成的问题
2. 修复了某种情况下，任务会被多次添加的问题
3. 修复了 Acrobat 产品错误显示 "命令行安装" 按钮的问题
4. 修复了当本地存在了已下载的文件，但持久化数据被删除后，需要每次点击 "使用现有程序" 才会创建任务的问题
5. 修复了点击 "使用现有程序" 创建完任务后不会创建持久化文件的问题
6. 在 DEBUG 模式下，添加了 "查看持久化文件" 的按钮

PS: ⚠️ 1.5.x 版本将会是最后一个开源版本，请知晓
```

### 语言支持

- [x] 中文
- [x] English

## ⚠️ 注意

**对于各位 SwiftUI 前辈来说，我只是一个 SwiftUI 新手，部分代码来自 Claude、OpenAI 和 Apple 等**
\
**如果你对 Adobe Downloader 有任何优化建议或疑问，请提出 issue 或通过 Telegram 联系 [@X1a0He](https://t.me/X1a0He_bot)**

## ✨ 特点

- [x] 基本功能 📦
    - [x] Acrobat Pro 的下载
    - [x] 其他 Adobe 产品的下载
    - [x] 支持安装非 Acrobat 产品
    - [x] 支持多个产品同时下载
    - [x] 支持使用默认语言和默认目录
    - [x] 支持任务记录持久化
- [x] 安装功能 📦
- [x] 清理功能 🧹 (1.5.0新增)
    - [x] Adobe 应用程序
    - [x] Adobe Creative Cloud
    - [x] Adobe 偏好设置
    - [x] Adobe 缓存文件
    - [x] Adobe 许可文件
    - [x] Adobe 日志文件
    - [x] Adobe 服务
    - [x] Adobe 钥匙串
    - [x] Adobe 正版验证服务
    - [x] Adobe Hosts

## 👀 预览

### 浅色模式 & 深色模式

![light](imgs/preview-light.png)
![dark](imgs/preview-dark.png)

### 版本选择

![version picker](imgs/version.png)

### 语言选择

![language picker](imgs/language.png)

### 下载任务管理

![download management](imgs/download.png)

## 🔗 引用

- [Drovosek01/adobe-packager](https://github.com/Drovosek01/adobe-packager/)
- [QiuChenly/InjectLib](https://github.com/QiuChenly/InjectLib/)

## 👨🏻‍💻作者

Adobe Downloader © X1a0He

Released under GPLv3. Created on 2024.11.05.

> GitHub [@X1a0He](https://github.com/X1a0He/) \
> Telegram [@X1a0He](https://t.me/X1a0He_bot)
