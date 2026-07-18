# WorkBuddy Dream Skin

给腾讯 WorkBuddy 桌面端换一张会呼吸的脸。

当前版本：**V0.2.2**。通过仅绑定本机的 Chrome DevTools Protocol（CDP）向 WorkBuddy 主窗口动态注入背景和样式。它不修改 `WorkBuddy.exe`、`app.asar` 或官方安装目录。

> 非腾讯官方产品。WorkBuddy 及相关商标归其权利人所有。

## 平台支持

- **Windows 10/11：已支持并完成实机验收。** 下载文件名包含 `Windows`。
- **macOS：尚未发布。** macOS 需要独立启动器、安装路径、权限处理和真实 Mac 验收，不与 Windows 安装包混用。

## 当前能力

- 图形化主题中心：预览、导入图片、应用主题、恢复官方外观
- 当前用户一键安装，无需管理员权限
- 自动创建桌面和开始菜单快捷方式
- 自动寻找当前用户安装的 WorkBuddy
- 启动 WorkBuddy 并打开仅限 `127.0.0.1` 的 CDP 端口
- 注入渐变或你自己的 JPG、PNG、WebP、GIF 背景
- 调节暗色蒙层、面板透明度、毛玻璃、饱和度和圆角
- 不修改安装包，支持移除当前主题
- 自带环境检查脚本
- 自动发现 `themes/` 与 `themes-local/` 主题
- `Switch Theme.cmd` 交互式一键切换并记住当前主题
- 首页突出背景，进入任务页后自动加深蒙层
- 客户定制包生成器：选择照片、客户名称和基础配色后生成可直接交付的 ZIP

## 快速开始

要求：Windows 10/11、PowerShell 5.1 或更高版本、已安装 WorkBuddy。

1. 从 GitHub Releases 下载 ZIP 并解压。
2. 双击 `Install WorkBuddy Dream Skin.cmd`。
3. 以后从桌面打开 `WorkBuddy Dream Skin`。
4. 在主题中心选择主题，或点击“导入自己的图片”。
5. 完全退出 WorkBuddy（包括托盘进程），点击“应用主题”。

不想安装时，也可以直接双击 `Theme Studio.cmd` 使用便携模式。命令行入口 `Start Dream Skin.cmd`、`Switch Theme.cmd` 和 `Restore WorkBuddy.cmd` 仍然保留。

如果 WorkBuddy 是正常方式启动的，脚本不会强制关闭它，而是提示你先退出。这是为了避免打断正在执行的任务。

## 使用自己的背景图

在主题中心先选择一个基础样式，再点击“导入自己的图片”。图片会复制到本机 `themes-local/`，不会上传到 GitHub，也不会在重新安装时被覆盖。

支持 JPG、PNG、WebP 和 GIF，大小限制为 12 MB。工具将图片转换为 data URL 后注入，避免额外启动本地 HTTP 服务。

## 制作客户定制安装包

双击 `制作客户定制包.cmd`，填写客户名称并选择客户照片。默认的“自动匹配照片（推荐）”会在本机分析照片的主色、明暗、饱和度和对比度，自动生成侧栏、按钮、卡片、文字和边框的完整浅色或深色色板。你也可以切换到手动基础配色进行风格覆盖。然后点击“生成客户安装包”，工具会在指定文件夹生成：

- `WorkBuddy-定制皮肤-客户名-Windows-v0.2.2.zip`
- 对应的 `.sha256` 校验文件

客户只需要解压 ZIP，双击 `Install WorkBuddy Dream Skin.cmd`。安装完成后主题中心会自动选中该客户的专属主题。客户不需要 Git、GitHub Desktop、`gh` 或管理员权限。

客户照片只写入生成的本地 ZIP，不会上传到 GitHub。收费定制时请确认你拥有照片、人物形象和宣传素材的使用授权，不要把客户私人照片提交到公共仓库。

## V0.2 动漫主题壳

主题中心首次打开会自动在本机 `themes-local/` 准备以下配色壳：

- Wuthering Waves - Shorekeeper
- Wuthering Waves - Changli
- One Piece - Luffy Gear 5
- One Piece - Straw Hat Crew

这些主题不在公共仓库内置具体角色图片。没有图片时仍可使用专属渐变配色；要加入自己的背景：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-local-theme.ps1 `
  -ExampleId onepiece-luffy-gear5 `
  -BackgroundPath C:\Pictures\luffy-gear5.jpg
```

精确动漫人物属于相应权利方。公共仓库只提供配置壳；本机 `themes-local/` 已被 `.gitignore` 排除。

可直接复制的宽屏生图提示词见 [`docs/theme-generation-prompts.md`](docs/theme-generation-prompts.md)。

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

V0.2.2 验证普通用户闭环：下载、安装、预览、导入图片、切换、记忆、恢复和卸载；同时验证定制服务方从客户照片自动取色并生成独立安装 ZIP 的交付闭环。代码签名、支付、在线后台、自动更新和 macOS 支持留到后续版本。

发布前人工验收步骤见 [`docs/testing-guide.md`](docs/testing-guide.md)。

## License

[MIT](LICENSE)
