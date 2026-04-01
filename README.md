# Open Claude Now

[中文文档](./README.zh-CN.md)

Add **"Open Claude Code Here"** to the Windows right-click context menu. Launch [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in any directory with a single click.

## Prerequisites

- **Windows 10 / 11**
- **Claude Code** installed and available in PATH:
  ```
  npm install -g @anthropic-ai/claude-code
  ```

## Install

Open PowerShell and run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

To use **Windows Terminal** instead of cmd:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -UseWindowsTerminal
```

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## Usage

After installation:

- **Right-click on empty space** inside any folder → **"Open Claude Code Here"**
- **Right-click on a folder** → **"Open Claude Code Here"**

### Windows 11 Note

On Windows 11, the option appears under **"Show more options"** (the classic context menu). To restore the full classic right-click menu system-wide:

```
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
```

Then restart Explorer:

```
taskkill /f /im explorer.exe & start explorer.exe
```

## How It Works

The tool adds entries to the Windows registry under `HKEY_CURRENT_USER`, so:

- **No admin privileges required**
- **Per-user installation** (does not affect other users on the same machine)
- **Clean uninstall** with a single command

Registry keys created:

```
HKCU\SOFTWARE\Classes\Directory\Background\shell\ClaudeCode
HKCU\SOFTWARE\Classes\Directory\shell\ClaudeCode
```

## License

MIT
