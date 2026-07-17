# WorkBuddy Dream Skin

给腾讯 WorkBuddy 桌面端换一张会呼吸的脸。

这是一个 Windows MVP：通过仅绑定本机的 Chrome DevTools Protocol（CDP）向 WorkBuddy 主窗口动态注入背景和样式。它不修改 `WorkBuddy.exe`、`app.asar` 或官方安装目录。

> 非腾讯官方产品。WorkBuddy 及相关商标归其权利人所有。

## 当前能力

- 自动寻找当前用户安装的 WorkBuddy
- 启动 WorkBuddy 并打开仅限 `127.0.0.1` 的 CDP 端口
- 注入渐变或你自己的 JPG、PNG、WebP、GIF 背景
- 调节暗色蒙层、面板透明度、毛玻璃、饱和度和圆角
- 不修改安装包，支持移除当前主题
- 自带环境检查脚本

## 快速开始

要求：Windows 10/11、PowerShell 5.1 或更高版本、已安装 WorkBuddy。

1. 完全退出 WorkBuddy，包括托盘进程。
2. 双击 `Start Dream Skin.cmd`。
3. 要移除当前主题，双击 `Restore WorkBuddy.cmd`。

如果 WorkBuddy 是正常方式启动的，脚本不会强制关闭它，而是提示你先退出。这是为了避免打断正在执行的任务。

## 使用自己的背景图

把图片放进 `themes/dream/`，例如：

```text
themes/dream/my-background.jpg
```

然后修改 `themes/dream/theme.json`：

```json
{
  "name": "My Dream",
  "backgroundImage": "my-background.jpg",
  "backgroundFallback": "linear-gradient(145deg, #16132c, #101827)",
  "backgroundPosition": "center center",
  "backgroundSize": "cover",
  "overlayOpacity": 0.34,
  "panelOpacity": 0.76,
  "panelBlurPx": 20,
  "panelSaturation": 1.12,
  "radiusPx": 14
}
```

MVP 将图片转换为 data URL 后注入，图片大小限制为 12 MB。这避免了本地文件权限和额外 HTTP 服务。

## 参数化启动

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-dream-skin.ps1 `
  -ThemePath .\themes\dream\theme.json `
  -Port 19333
```

检查环境：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

运行不依赖 WorkBuddy 登录状态的 CDP 注入/恢复冒烟测试：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\smoke.ps1
```

## 安全边界

- CDP 只绑定 `127.0.0.1`，不监听局域网地址。
- 主题运行期间，本机其他程序理论上可以访问这个调试端口。不要同时运行来路不明的软件。
- 工具不读取或修改 WorkBuddy 的账号、模型、API Key、任务或工作区配置。
- WorkBuddy 更新后 DOM 结构可能变化。若主题局部失效，请先恢复外观并提交版本号和截图。
- 文档预览和第三方 `webview` 不在 MVP 换肤范围内。

## MVP 范围

第一版先验证完整闭环：启动、注入自定义背景、调整主界面、恢复。托盘主题管理、自动取色、主题商店和 macOS 支持留到后续版本。

## License

[MIT](LICENSE)
