# Open Claude Now

在 Windows 右键菜单中添加 **"Open Claude Code Here"** 选项，一键在任意目录启动 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)。

## 前置要求

- **Windows 10 / 11**
- 已安装 **Claude Code** 并可在命令行中使用：
  ```
  npm install -g @anthropic-ai/claude-code
  ```

## 安装

打开 PowerShell，运行：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

如果你希望使用 **Windows Terminal** 而不是 cmd 来启动：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -UseWindowsTerminal
```

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## 使用方式

安装完成后：

- **在文件夹空白处右键** → **"Open Claude Code Here"** → 在当前目录启动 Claude Code
- **在文件夹上右键** → **"Open Claude Code Here"** → 在该文件夹中启动 Claude Code

### Windows 11 提示

在 Windows 11 上，该选项会出现在 **"显示更多选项"**（经典右键菜单）中。如果你希望恢复完整的经典右键菜单，可以运行：

```
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
```

然后重启资源管理器：

```
taskkill /f /im explorer.exe & start explorer.exe
```

## 工作原理

本工具通过向 Windows 注册表的 `HKEY_CURRENT_USER` 下添加条目来实现右键菜单，因此：

- **无需管理员权限**
- **仅对当前用户生效**，不影响同一台电脑上的其他用户
- **一条命令即可干净卸载**

创建的注册表项：

```
HKCU\SOFTWARE\Classes\Directory\Background\shell\ClaudeCode
HKCU\SOFTWARE\Classes\Directory\shell\ClaudeCode
```

## 许可证

MIT
