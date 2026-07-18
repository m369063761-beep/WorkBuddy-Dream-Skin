# 平台支持与交付边界

## Windows

V0.2.2 的正式交付目标是 Windows 10/11。公开安装包和客户定制包的文件名都会包含 `Windows`。客户解压后双击安装器即可，不需要 Git、GitHub Desktop、`gh`、管理员权限、账号系统或支付系统。

## macOS

macOS 必须作为独立安装包交付，不能直接复用 PowerShell、Windows 快捷方式、WorkBuddy.exe 查找逻辑或 Windows CDP 启动参数。

发布 macOS 版本前至少需要验证：

- WorkBuddy.app 的实际安装位置与版本差异
- 独立用户数据目录和本机 CDP 端口绑定
- `.command`/应用启动器的执行权限与 Gatekeeper 提示
- Intel 与 Apple Silicon
- 首页、任务页、主题切换、恢复和卸载
- 客户照片打包与本机隐私边界

在真实 Mac 验收完成前，公开页面和收费说明只能承诺 Windows 支持。
