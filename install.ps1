# ============================================
# Open Here Menu - configuration-driven installer
# ============================================
# Registers a cascading context menu with one entry per enabled program plus a
# trailing "Apply config changes" entry that re-runs this installer hidden, so
# the menu can be refreshed after editing config.json without a terminal.

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Uninstall,
    [switch]$DryRun,
    # Used by the menu's own "Apply config changes" entry: run hidden and
    # report the outcome as a notification (or a dialog on failure).
    [switch]$MenuRefresh
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot "config.json"
}

$menuKeyName = "OpenHereMenu"
$registryRoots = @(
    "HKCU:\SOFTWARE\Classes\Directory\Background\shell\$menuKeyName",
    "HKCU:\SOFTWARE\Classes\Directory\shell\$menuKeyName"
)
$legacyRegistryRoots = @(
    "HKCU:\SOFTWARE\Classes\Directory\Background\shell\ClaudeCode",
    "HKCU:\SOFTWARE\Classes\Directory\shell\ClaudeCode"
)
# Files installed by earlier versions of this tool; no longer used.
$legacyInstallDir = Join-Path $env:LOCALAPPDATA "OpenHereMenu"

function Write-Status {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    Write-Host $Message -ForegroundColor $Color
}

function Remove-RegisteredMenu {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            if ($DryRun) {
                Write-Status "  [DRY RUN] Remove registry key: $path" Yellow
            } else {
                Remove-Item -LiteralPath $path -Recurse -Force
                Write-Status "  [OK] Removed registry key: $path" Green
            }
        }
    }
}

function Remove-LegacyInstallDir {
    if (Test-Path -LiteralPath $legacyInstallDir) {
        if ($DryRun) {
            Write-Status "  [DRY RUN] Remove legacy installed files: $legacyInstallDir" Yellow
        } else {
            Remove-Item -LiteralPath $legacyInstallDir -Recurse -Force
            Write-Status "  [OK] Removed legacy installed files: $legacyInstallDir" Green
        }
    }
}

function Get-RequiredProperty {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        throw "$Context is missing required property '$Name'."
    }

    $value = $Object.$Name
    if ($null -eq $value -or ([string]$value).Trim().Length -eq 0) {
        throw "$Context property '$Name' cannot be empty."
    }
    return $value
}

function Resolve-SourcePath {
    param(
        [string]$Path,
        [string]$BaseDirectory
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $Path))
}

function Set-RegistryString {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )

    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null
}

function Show-RefreshNotification {
    param([string]$Message, [string]$IconPath)

    # Best-effort toast; a suppressed notification never fails the refresh.
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        if ($IconPath -and [System.IO.Path]::GetExtension($IconPath) -eq ".ico") {
            $notifyIcon.Icon = New-Object System.Drawing.Icon($IconPath)
        } else {
            $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
        }
        $notifyIcon.Visible = $true
        $notifyIcon.ShowBalloonTip(2500, "Open Here", $Message, [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Sleep -Seconds 3
        $notifyIcon.Dispose()
    } catch { }
}

function Show-RefreshError {
    param([string]$Message)

    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($Message, "Open Here")
    } catch {
        Write-Error $Message
    }
}

function Invoke-Install {
    $resolvedConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
    if (-not (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf)) {
        $examplePath = Join-Path $PSScriptRoot "config.example.json"
        $defaultPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "config.json"))
        if ($resolvedConfigPath -ieq $defaultPath -and (Test-Path -LiteralPath $examplePath -PathType Leaf)) {
            throw "Configuration file was not found: $resolvedConfigPath. Create your local configuration from the template: Copy-Item `"$examplePath`" `"$defaultPath`""
        }
        throw "Configuration file was not found: $resolvedConfigPath"
    }

    $configDirectory = Split-Path -Parent $resolvedConfigPath
    $config = Get-Content -LiteralPath $resolvedConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $schemaVersion = [int](Get-RequiredProperty -Object $config -Name "schemaVersion" -Context "Configuration")
    if ($schemaVersion -ne 1) {
        throw "Unsupported schemaVersion '$schemaVersion'. This installer supports schemaVersion 1."
    }
    $menuTitle = [string](Get-RequiredProperty -Object $config -Name "menuTitle" -Context "Configuration")

    if (-not ($config.PSObject.Properties.Name -contains "programs")) {
        throw "Configuration is missing required property 'programs'."
    }

    # Every program disabled is a valid state: the menu then contains only
    # the "Apply config changes" entry.
    $programs = @($config.programs | Where-Object {
        -not ($_.PSObject.Properties.Name -contains "enabled") -or $_.enabled -eq $true
    })

    $supportedLaunchModes = @("cmd", "windowsTerminal", "direct", "webService")
    $seenIds = @{}
    foreach ($program in $programs) {
        $id = [string](Get-RequiredProperty -Object $program -Name "id" -Context "Program")
        $name = [string](Get-RequiredProperty -Object $program -Name "name" -Context "Program '$id'")
        $command = [string](Get-RequiredProperty -Object $program -Name "command" -Context "Program '$id'")
        $launchMode = [string](Get-RequiredProperty -Object $program -Name "launchMode" -Context "Program '$id'")

        if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            throw "Program id '$id' is invalid. Use letters, numbers, '.', '_' or '-'."
        }
        if ($seenIds.ContainsKey($id)) {
            throw "Program id '$id' is duplicated."
        }
        $seenIds[$id] = $true

        if ($supportedLaunchModes -notcontains $launchMode) {
            throw "Program '$id' has unsupported launchMode '$launchMode'."
        }
        if (($program.PSObject.Properties.Name -contains "arguments") -and
            $null -ne $program.arguments -and
            $program.arguments -is [string]) {
            throw "Program '$id' property 'arguments' must be a JSON array of strings."
        }
        foreach ($argument in @($program.arguments)) {
            if ($null -eq $argument -or $argument -isnot [string]) {
                throw "Every argument for program '$id' must be a JSON string."
            }
        }

        if ($launchMode -eq "webService") {
            $urlValue = [string](Get-RequiredProperty -Object $program -Name "url" -Context "Program '$id'")
            $url = $null
            if (-not [System.Uri]::TryCreate($urlValue, [System.UriKind]::Absolute, [ref]$url) -or
                $url.Scheme -notin @("http", "https")) {
                throw "Program '$id' property 'url' must be an absolute HTTP or HTTPS URL."
            }
            if ($url.DnsSafeHost -notin @("127.0.0.1", "localhost", "::1")) {
                throw "Program '$id' property 'url' must point to localhost."
            }
            if ($program.PSObject.Properties.Name -contains "startupTimeoutSeconds") {
                $startupTimeoutSeconds = [int]$program.startupTimeoutSeconds
                if ($startupTimeoutSeconds -lt 1 -or $startupTimeoutSeconds -gt 300) {
                    throw "Program '$id' property 'startupTimeoutSeconds' must be between 1 and 300."
                }
            }
        }

        if ($launchMode -eq "windowsTerminal" -and -not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
            Write-Status "  [WARN] Program '$name' uses Windows Terminal, but wt.exe is not currently in PATH." Yellow
        }
        if (-not (Get-Command $command -CommandType Application, ExternalScript -ErrorAction SilentlyContinue) -and
            -not (Test-Path -LiteralPath (Resolve-SourcePath -Path $command -BaseDirectory $configDirectory) -PathType Leaf)) {
            Write-Status "  [WARN] Command for '$name' cannot currently be resolved: $command" Yellow
        }

        if ($program.PSObject.Properties.Name -contains "icon" -and
            -not [string]::IsNullOrWhiteSpace([string]$program.icon)) {
            $iconPath = Resolve-SourcePath -Path ([string]$program.icon) -BaseDirectory $configDirectory
            if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
                throw "Icon for '$id' was not found: $iconPath"
            }
        }
    }

    # Submenu icons are baked into the registry when this installer runs; a
    # program's command, arguments, and launch mode are re-read live from the
    # config by the launcher on every click.
    $menuIcon = $null
    if ($config.PSObject.Properties.Name -contains "menuIcon" -and
        -not [string]::IsNullOrWhiteSpace([string]$config.menuIcon)) {
        $menuIcon = Resolve-SourcePath -Path ([string]$config.menuIcon) -BaseDirectory $configDirectory
        if (-not (Test-Path -LiteralPath $menuIcon -PathType Leaf)) {
            throw "Menu icon was not found: $menuIcon"
        }
    } elseif ($programs.Count -gt 0 -and
        $programs[0].PSObject.Properties.Name -contains "icon" -and
        -not [string]::IsNullOrWhiteSpace([string]$programs[0].icon)) {
        $menuIcon = Resolve-SourcePath -Path ([string]$programs[0].icon) -BaseDirectory $configDirectory
    }

    Write-Status "  Configuration: $resolvedConfigPath" Gray
    Write-Status "  Menu title:    $menuTitle" Gray
    Write-Status "  Programs:      $($programs.Count)" Gray
    foreach ($program in $programs) {
        Write-Status "    - $($program.name) [$($program.launchMode)] -> $($program.command)" Gray
    }

    $sourceLauncher = Join-Path $PSScriptRoot "launcher.ps1"
    if (-not (Test-Path -LiteralPath $sourceLauncher -PathType Leaf)) {
        throw "Launcher script was not found: $sourceLauncher"
    }

    if ($DryRun) {
        Write-Host ""
        Write-Status "  [DRY RUN] Configuration is valid. No files or registry keys were changed." Green
        return $null
    }

    # Remove the previous version (including its per-program entries) so
    # reinstalling is idempotent, and drop files copied by earlier versions.
    Remove-RegisteredMenu -Paths ($registryRoots + $legacyRegistryRoots)
    Remove-LegacyInstallDir

    $sourceInstaller = $PSCommandPath
    $powershellExe = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop).Source
    $launcherCommandTemplate = '"{0}" -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -ConfigPath "{2}" -ProgramId "{3}" -TargetPath "{4}"'
    $applyLabel = "Apply config changes"
    $applyIcon = Join-Path $PSScriptRoot "assets\refresh.ico"
    $applyCommandTemplate = '"{0}" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -ConfigPath "{2}" -MenuRefresh'

    try {
        foreach ($root in $registryRoots) {
            $isBackgroundMenu = $root -like "*\Directory\Background\*"
            $targetPlaceholder = if ($isBackgroundMenu) { "%V" } else { "%1" }
            $extendedSubcommandsReference = if ($isBackgroundMenu) {
                "Directory\Background\shell\$menuKeyName"
            } else {
                "Directory\shell\$menuKeyName"
            }
            $subcommandsPath = Join-Path $root "shell"
            New-Item -Path $subcommandsPath -Force | Out-Null
            Set-RegistryString -Path $root -Name "MUIVerb" -Value $menuTitle
            Set-RegistryString -Path $root -Name "ExtendedSubCommandsKey" -Value $extendedSubcommandsReference
            if ($menuIcon) {
                Set-RegistryString -Path $root -Name "Icon" -Value $menuIcon
            }

            for ($index = 0; $index -lt $programs.Count; $index++) {
                $program = $programs[$index]
                $id = [string]$program.id
                $verbName = "{0:D3}_{1}" -f ($index + 1), $id
                $verbPath = Join-Path $subcommandsPath $verbName
                $commandPath = Join-Path $verbPath "command"

                New-Item -Path $commandPath -Force | Out-Null
                Set-RegistryString -Path $verbPath -Name "MUIVerb" -Value ([string]$program.name)
                if ($program.PSObject.Properties.Name -contains "icon" -and
                    -not [string]::IsNullOrWhiteSpace([string]$program.icon)) {
                    $iconPath = Resolve-SourcePath -Path ([string]$program.icon) -BaseDirectory $configDirectory
                    Set-RegistryString -Path $verbPath -Name "Icon" -Value $iconPath
                }

                $launcherCommand = $launcherCommandTemplate -f $powershellExe, $sourceLauncher, $resolvedConfigPath, $id, $targetPlaceholder
                Set-Item -LiteralPath $commandPath -Value $launcherCommand
            }

            # Trailing entry that refreshes the whole menu from the config.
            # "zz_" sorts after the numbered program verbs.
            $applyVerbPath = Join-Path $subcommandsPath "zz_apply-config-changes"
            $applyCommandPath = Join-Path $applyVerbPath "command"
            New-Item -Path $applyCommandPath -Force | Out-Null
            Set-RegistryString -Path $applyVerbPath -Name "MUIVerb" -Value $applyLabel
            if (Test-Path -LiteralPath $applyIcon -PathType Leaf) {
                Set-RegistryString -Path $applyVerbPath -Name "Icon" -Value $applyIcon
            }
            $applyCommand = $applyCommandTemplate -f $powershellExe, $sourceInstaller, $resolvedConfigPath
            Set-Item -LiteralPath $applyCommandPath -Value $applyCommand
        }
    } catch {
        Remove-RegisteredMenu -Paths $registryRoots
        throw
    }

    return @{
        ProgramCount = $programs.Count
        MenuTitle    = $menuTitle
        MenuIcon     = $menuIcon
    }
}

Write-Host ""
Write-Status "  Open Here Menu" Cyan
Write-Status "  ==============" Cyan
Write-Host ""

if ($Uninstall) {
    Write-Status "  Removing menu entries and legacy leftovers..." Cyan
    Remove-RegisteredMenu -Paths ($registryRoots + $legacyRegistryRoots)
    Remove-LegacyInstallDir

    Write-Host ""
    Write-Status "  Uninstall complete." Green
    exit 0
}

if ($MenuRefresh) {
    try {
        $result = Invoke-Install
    } catch {
        Show-RefreshError $_.Exception.Message
        exit 1
    }
    if ($null -ne $result) {
        Show-RefreshNotification ("Menu updated: {0} programs" -f $result.ProgramCount) $result.MenuIcon
    }
    exit 0
}

$result = Invoke-Install

Write-Host ""
Write-Status "  [OK] Installation complete." Green
Write-Status "  Right-click a folder or folder background and open '$($result.MenuTitle)'." Gray
Write-Status "  After editing config.json, click '$($result.MenuTitle) -> Apply config changes' in the" Gray
Write-Status "  context menu to refresh entries. Commands and arguments of existing entries" Gray
Write-Status "  apply live without refreshing." Gray
Write-Host ""
