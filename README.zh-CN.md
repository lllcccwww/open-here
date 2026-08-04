# Open Here Menu

通过一个 JSON 配置文件，自定义 Windows 文件夹右键菜单中可以启动的程序。项目默认附带 Claude Code 示例，但安装逻辑不再依赖或写死 Claude Code。

安装完成后，在文件夹空白处或文件夹上右键，可以从 **Open Here** 级联菜单中选择已配置的程序。程序会以该文件夹作为工作目录启动。

## 环境要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1 或更高版本
- 需要启动的程序已经安装，或者在配置中填写了可执行文件的完整路径

Windows 11 默认会把菜单放在“显示更多选项”的经典右键菜单中。

## 配置程序

编辑项目根目录中的 `config.json`：

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
    }
  ]
}
```

每个程序支持以下字段：

顶层的 `schemaVersion` 当前必须为 `1`；`menuTitle` 是级联菜单名称；`menuIcon` 是级联菜单图标。

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 程序的唯一标识，只能使用字母、数字、点、下划线和连字符 |
| `name` | 是 | 右键菜单中显示的名称 |
| `command` | 是 | PATH 中的命令、可执行文件完整路径，或相对 `config.json` 的路径 |
| `arguments` | 否 | 字符串数组；参数中的 `{path}` 会替换为右键选中的文件夹路径 |
| `launchMode` | 是 | `cmd`、`windowsTerminal` 或 `direct` |
| `icon` | 否 | `.ico`、`.exe` 等图标文件路径；相对路径以 `config.json` 所在目录为准 |
| `enabled` | 否 | 设为 `false` 时不安装该程序，默认启用 |

三种启动方式：

- `cmd`：打开传统命令提示符，并保持窗口不关闭，适合 Claude Code 等终端程序。
- `windowsTerminal`：在新的 Windows Terminal 窗口中直接打开程序，需要 `wt.exe`。
- `direct`：直接启动程序，适合 VS Code 等图形界面程序。可通过 `{path}` 把目录作为参数传给程序。

可以在 `programs` 数组中添加任意数量的程序。仓库默认启用 Claude Code 和 Reasonix。

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

安装器会把启动器、配置快照和图标复制到：

```text
%LOCALAPPDATA%\OpenHereMenu
```

因此安装后可以移动或删除源码目录。修改配置后需要重新运行安装命令，以更新菜单和已安装的配置快照。

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

卸载会删除：

- 新版 `OpenHereMenu` 右键菜单注册表项
- 旧版项目使用的 `ClaudeCode` 注册表项
- `%LOCALAPPDATA%\OpenHereMenu` 中安装的文件

所有注册表项都位于 `HKEY_CURRENT_USER`，不需要管理员权限，只影响当前 Windows 用户。

## 注册表结构

安装器会在下面两个位置创建同样的级联菜单：

```text
HKCU\SOFTWARE\Classes\Directory\Background\shell\OpenHereMenu
HKCU\SOFTWARE\Classes\Directory\shell\OpenHereMenu
```

## 许可证

MIT
