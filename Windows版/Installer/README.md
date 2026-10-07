# “是否认同”标准安装包

这是“是否认同”64 位 Windows 桌面程序的标准 Inno Setup 安装工程，发布者为 TGLab。

## 用户安装

用户只需运行 `Output\Setup.exe`，不需要安装 Inno Setup，也不需要手工复制任何文件。安装器会请求管理员权限并默认写入 `%ProgramFiles%\TGLab\是否认同`，用户配置始终写入 `%LOCALAPPDATA%\TGLab\是否认同`。

安装包不内置 .NET。启动安装时会检测 64 位 Microsoft .NET 8 Desktop Runtime；如果缺失，会先征得用户同意，再从微软官方地址下载并安装。用户拒绝、下载失败或取消运行时的 UAC 时，主程序安装会安全取消。

## 构建

开发电脑需要 .NET 8 SDK 和 Inno Setup 6；目标用户电脑不需要 Inno Setup。

```powershell
.\Build-Setup.ps1
```

脚本执行 framework-dependent、多文件的 `dotnet publish Release`，运行应用自检，编译 `Setup.exe`，扫描开发电脑路径泄漏，并生成 `Output\SHA256SUMS.txt`。

## 安装与卸载行为

- 固定 AppId：`{4D229622-C3A1-4EF6-AC43-7B28EF7B47F1}`，后续版本必须保持不变以支持覆盖升级。
- 安装前由 Windows Restart Manager 关闭正在运行的 `是否认同.exe`。
- 创建开始菜单快捷方式，桌面快捷方式由用户选择。
- 在 Windows“已安装的应用”登记名称、版本、发布者、图标、安装位置和卸载命令。
- 卸载器只删除本产品的安装目录、快捷方式和登记项。
- 交互卸载提供“保留配置 / 删除配置 / 取消卸载”三种选择；删除配置仅针对 `%LOCALAPPDATA%\TGLab\是否认同`。

## 测试

普通隔离路径测试：

```powershell
.\Test-Setup.ps1
```

Program Files 管理员路径测试：

```powershell
.\Test-Setup.ps1 -ProgramFilesTest
```

脚本覆盖全新安装、覆盖升级、安装登记、保留配置卸载、删除配置卸载以及中文空格路径。`D:\Program Files` 需在具有 D 盘的测试机上将 `-TestRoot` 指向该路径执行。UAC 取消必须交互测试：在首次安装或缺少运行时的环境中取消 UAC，确认安装器不留下程序文件。

## 交付文件

- `Output\Setup.exe`
- `是否认同.iss`
- `Build-Setup.ps1`
- `Test-Setup.ps1`
- `README.md`
- `Output\SHA256SUMS.txt`

