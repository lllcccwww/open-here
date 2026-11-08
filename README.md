# Open Here Menu

[中文文档](./README.zh-CN.md)

Create a configurable Windows folder context menu from JSON. The default config enables Claude Code, Reasonix, DeepSeek DSH Web, and Pi Agent, but the tool is not tied to any of them.

## How it works

The installer registers a cascading **Open Here** submenu with one entry per enabled program. Clicking an entry runs `launcher.ps1`, which re-reads `config.json` at that moment and starts the program in the clicked folder.

- Changes to an existing entry's `command`, `arguments`, `launchMode`, `url`, or `startupTimeoutSeconds` are live: they apply on the next click, no action needed.
- Adding, removing, renaming, reordering, or disabling programs — and changing `menuTitle`, `menuIcon`, or icons — rewrite registry data. After editing the config, click **Open Here → Apply config changes** once: the installer re-runs hidden and shows a confirmation notification. No terminal, no admin rights.
- Re-run `install.ps1` manually only after moving this folder.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- Each configured application must be installed or referenced by its executable path

On Windows 11, the menu appears under the classic **Show more options** menu.

## Configuration

`config.json` is your local configuration and is not tracked by git. Start by copying the template, then edit it freely — your changes never get committed. Changes to what an existing entry *runs* apply on the next click; changes to the menu *structure* need one click on **Apply config changes** (see above):

```powershell
Copy-Item config.example.json config.json
```

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

Program fields:

The top-level `schemaVersion` must currently be `1`; `menuTitle` and `menuIcon` control the parent menu entry and are applied when the installer or the **Apply config changes** entry runs.

| Field | Required | Description |
| --- | --- | --- |
| `id` | Yes | Unique ID using letters, numbers, dots, underscores, or hyphens |
| `name` | Yes | Context-menu label |
| `command` | Yes | A command in PATH, an absolute executable path, or a path relative to the config file |
| `arguments` | No | String array; `{path}` is replaced with the selected folder path |
| `launchMode` | Yes | `cmd`, `windowsTerminal`, `direct`, or `webService` |
| `icon` | No | Icon file path, relative to the config file when not absolute; applied when the menu is refreshed |
| `enabled` | No | Set to `false` to omit the program; defaults to enabled. If all programs are disabled, the menu shows only **Apply config changes** |
| `url` | For `webService` | Local HTTP(S) address to open when ready; host must be `localhost`, `127.0.0.1`, or `::1` |
| `startupTimeoutSeconds` | No | Seconds to wait for the local port, from 1 to 300; defaults to 90 |

Launch modes:

- `cmd`: open a persistent Command Prompt for terminal applications.
- `windowsTerminal`: open the application in Windows Terminal; requires `wt.exe`.
- `direct`: start a GUI application directly. Use `{path}` when it needs the selected folder as an argument.
- `webService`: probe the configured URL first. If its port is already listening, open it immediately; otherwise start the command and open the browser when the port becomes ready. Concurrent clicks do not start duplicate servers.

The default DeepSeek DSH Web item runs `npx @deepseek-ai/dsh web` and opens `http://127.0.0.1:3080/`. On first use, `npx` may ask for confirmation before downloading the package.

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

The installer writes per-user registry entries that point directly at `launcher.ps1` and the config file in this folder. Keep this folder in place; if you move or rename it, re-run the installer.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

Uninstall removes the menu registry entries, legacy `ClaudeCode` menu entries and `%LOCALAPPDATA%\OpenHereMenu` files from previous versions. All registry entries are per-user under `HKEY_CURRENT_USER`, so administrator privileges are not required.

## Registry keys

```text
HKCU\SOFTWARE\Classes\Directory\Background\shell\OpenHereMenu
HKCU\SOFTWARE\Classes\Directory\shell\OpenHereMenu
```

## License

MIT
