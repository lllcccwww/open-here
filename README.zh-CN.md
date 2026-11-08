# Open Here Menu

通过一个 JSON 配置文件，自定义 Windows 文件夹右键菜单中可以启动的程序。默认配置包含 Claude Code、Reasonix 和 DeepSeek DSH Web，但工具本身不绑定任何程序。

## 工作原理

安装器注册一个 **Open Here** 级联子菜单，每个启用的程序一个菜单项。点击菜单项时运行 `launcher.ps1`：它实时读取 `config.json`，以该文件夹为工作目录启动对应程序。

- 修改已有菜单项的 `command`、`arguments`、`launchMode`、`url`、`startupTimeoutSeconds` 是实时生效的，下次点击即按新配置运行，无需任何操作。
- 增删程序、改名、调顺序、改图标、改 `menuTitle`/`menuIcon` 需要重写注册表：改完配置后点一次 **Open Here → Apply config changes** 即可，安装器会在后台静默重跑并弹通知确认，无需开终端、无需管理员权限。
- 只有移动项目目录后才需要手动重新运行 `install.ps1`。

## 环境要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1 或更高版本
- 需要启动的程序已经安装，或者在配置中填写了可执行文件的完整路径

Windows 11 默认会把菜单放在“显示更多选项”的经典右键菜单中。

## 配置程序

编辑项目根目录中的 `config.json`。修改已有菜单项"运行什么"下次点击即生效；改动菜单"结构"则需点一次 **Apply config changes**（见上文）：

```json
{
  "schemaVersion": 1,
  "menuTitle": "Open Here",
  "menuIcon": "assets/terminal.ico",
  "programs": [
    {
      "id": "claude-code",
      "name": "Claude Code",
      "command": "claude",
      "arguments": [],
      "launchMode": "cmd",
      "icon": "assets/claude.ico",
      "enabled": true
    },
    {
      "id": "reasonix",
      "name": "Reasonix",
      "command": "reasonix",
      "arguments": [],
      "launchMode": "cmd",
      "icon": "assets/reasonix.ico",
      "enabled": true
    },
    {
      "id": "deepseek-dsh-web",
      "name": "DeepSeek DSH Web",
      "command": "npx",
      "arguments": ["@deepseek-ai/dsh", "web"],
      "launchMode": "webService",
      "url": "http://127.0.0.1:3080/",
      "startupTimeoutSeconds": 120,
      "icon": "assets/deepseek.ico",
      "enabled": true
    },
    {
      "id": "pi",
      "name": "Pi Agent",
      "command": "pi",
      "arguments": [],
      "launchMode": "cmd",
      "icon": "assets/pi.ico",
      "enabled": true
    }
  ]
}
```

每个程序支持以下字段：

顶层的 `schemaVersion` 当前必须为 `1`；`menuTitle` 是级联菜单名称，`menuIcon` 是级联菜单图标，两者在安装器或菜单中的 **Apply config changes** 运行时写入注册表。

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 程序的唯一标识，只能使用字母、数字、点、下划线和连字符 |
| `name` | 是 | 右键菜单中显示的名称 |
| `command` | 是 | PATH 中的命令、可执行文件完整路径，或相对 `config.json` 的路径 |
| `arguments` | 否 | 字符串数组；参数中的 `{path}` 会替换为右键选中的文件夹路径 |
| `launchMode` | 是 | `cmd`、`windowsTerminal`、`direct` 或 `webService` |
| `icon` | 否 | 图标文件路径，相对路径以 `config.json` 所在目录为准；刷新菜单时应用 |
| `enabled` | 否 | 设为 `false` 时该程序不出现在菜单中，默认启用；全部禁用时菜单只剩 **Apply config changes** |
| `url` | `webService` 必填 | 本地服务就绪后打开的 HTTP(S) 地址，仅支持 `localhost`、`127.0.0.1` 或 `::1` |
| `startupTimeoutSeconds` | 否 | 等待本地服务监听端口的秒数，范围 1–300，默认 90 |

四种启动方式：

- `cmd`：打开传统命令提示符，并保持窗口不关闭，适合 Claude Code 等终端程序。
- `windowsTerminal`：在新的 Windows Terminal 窗口中直接打开程序，需要 `wt.exe`。
- `direct`：直接启动程序，适合 VS Code 等图形界面程序。可通过 `{path}` 把目录作为参数传给程序。
- `webService`：先探测 `url` 的端口；服务已运行时直接用默认浏览器打开，未运行时启动命令，等待端口就绪后再打开。并发点击同一菜单项不会重复启动服务。

可以在 `programs` 数组中添加任意数量的程序。仓库默认启用 Claude Code、Reasonix、DeepSeek DSH Web 和 Pi Agent。首次启动 DeepSeek DSH 时，`npx` 可能会询问是否下载该包；确认后服务会在 `http://127.0.0.1:3080/` 就绪并自动打开浏览器。

配置文件会作为可信的本地配置执行，请不要使用来源不明的 `command` 或参数。

## 预览与安装

先验证配置，不修改文件或注册表：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
```

确认无误后安装：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

也可以指定其他配置文件：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -ConfigPath D:\Configs\my-menu.json
```

安装器会写入仅针对当前用户的注册表项，直接指向本项目目录中的 `launcher.ps1` 和配置文件。请保持项目目录位置不变；如果移动或重命名了目录，重新运行一次安装器即可。

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

卸载会删除：

- `OpenHereMenu` 右键菜单注册表项
- 旧版项目使用的 `ClaudeCode` 注册表项
- 旧版安装到 `%LOCALAPPDATA%\OpenHereMenu` 的文件

所有注册表项都位于 `HKEY_CURRENT_USER`，不需要管理员权限，只影响当前 Windows 用户。

## 注册表结构

安装器会在下面两个位置创建同样的级联子菜单（文件夹空白处 / 文件夹上右键）：

```text
HKCU\SOFTWARE\Classes\Directory\Background\shell\OpenHereMenu
HKCU\SOFTWARE\Classes\Directory\shell\OpenHereMenu
```

## 许可证

MIT
