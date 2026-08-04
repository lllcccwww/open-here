# Open Here Menu

[中文文档](./README.zh-CN.md)

Create a configurable Windows folder context menu from JSON. The default config enables Claude Code and Reasonix, but the installer is not tied to either program.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Each configured application must be installed or referenced by its executable path

On Windows 11, the menu appears under the classic **Show more options** menu.

## Configuration

Edit `config.json`:

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

Program fields:

The top-level `schemaVersion` must currently be `1`; `menuTitle` and `menuIcon` control the parent cascading menu.

| Field | Required | Description |
| --- | --- | --- |
| `id` | Yes | Unique ID using letters, numbers, dots, underscores, or hyphens |
| `name` | Yes | Context-menu label |
| `command` | Yes | A command in PATH, an absolute executable path, or a path relative to the config file |
| `arguments` | No | String array; `{path}` is replaced with the selected folder path |
| `launchMode` | Yes | `cmd`, `windowsTerminal`, or `direct` |
| `icon` | No | Icon file path, relative to the config file when not absolute |
| `enabled` | No | Set to `false` to omit the program; defaults to enabled |

Launch modes:

- `cmd`: open a persistent Command Prompt for terminal applications.
- `windowsTerminal`: open the application in Windows Terminal; requires `wt.exe`.
- `direct`: start a GUI application directly. Use `{path}` when it needs the selected folder as an argument.

The config is trusted local input. Do not install commands or arguments from an untrusted source.

## Validate and install

Validate without changing files or the registry:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
```

Install:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Use another config file:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -ConfigPath D:\Configs\my-menu.json
```

The installer copies the launcher, a config snapshot, and icons to `%LOCALAPPDATA%\OpenHereMenu`. Re-run it after changing the config.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

Uninstall removes the configurable menu, legacy `ClaudeCode` menu entries from the previous version, and the installed files. All registry entries are per-user under `HKEY_CURRENT_USER`, so administrator privileges are not required.

## Registry keys

```text
HKCU\SOFTWARE\Classes\Directory\Background\shell\OpenHereMenu
HKCU\SOFTWARE\Classes\Directory\shell\OpenHereMenu
```

## License

MIT
