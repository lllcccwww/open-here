# ============================================
# Open Here Menu - configuration-driven installer
# ============================================

[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Uninstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot "config.json"
}

$menuKeyName = "OpenHereMenu"
$installDir = Join-Path $env:LOCALAPPDATA "OpenHereMenu"
$registryRoots = @(
    "HKCU:\SOFTWARE\Classes\Directory\Background\shell\$menuKeyName",
    "HKCU:\SOFTWARE\Classes\Directory\shell\$menuKeyName"
)
$legacyRegistryRoots = @(
    "HKCU:\SOFTWARE\Classes\Directory\Background\shell\ClaudeCode",
    "HKCU:\SOFTWARE\Classes\Directory\shell\ClaudeCode"
)

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

function Copy-MenuIcon {
    param(
        [string]$Icon,
        [string]$Id,
        [string]$ConfigDirectory,
        [string]$DestinationDirectory
    )

    if ([string]::IsNullOrWhiteSpace($Icon)) {
        return $null
    }

    $sourcePath = Resolve-SourcePath -Path $Icon -BaseDirectory $ConfigDirectory
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Icon for '$Id' was not found: $sourcePath"
    }

    $extension = [System.IO.Path]::GetExtension($sourcePath)
    $contentHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.Substring(0, 12).ToLowerInvariant()
    $destinationPath = Join-Path $DestinationDirectory ("{0}-{1}{2}" -f $Id, $contentHash, $extension)

    if (-not $DryRun) {
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    }
    return $destinationPath
}

function Set-RegistryString {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )

    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null
}

Write-Host ""
Write-Status "  Open Here Menu" Cyan
Write-Status "  ==============" Cyan
Write-Host ""

if ($Uninstall) {
    Write-Status "  Removing configurable and legacy menu entries..." Cyan
    Remove-RegisteredMenu -Paths ($registryRoots + $legacyRegistryRoots)

    if (Test-Path -LiteralPath $installDir) {
        if ($DryRun) {
            Write-Status "  [DRY RUN] Remove installed files: $installDir" Yellow
        } else {
            Remove-Item -LiteralPath $installDir -Recurse -Force
            Write-Status "  [OK] Removed installed files: $installDir" Green
        }
    }

    Write-Host ""
    Write-Status "  Uninstall complete." Green
    exit 0
}

$resolvedConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
if (-not (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf)) {
    throw "Configuration file was not found: $resolvedConfigPath"
}

$configDirectory = Split-Path -Parent $resolvedConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$schemaVersion = [int](Get-RequiredProperty -Object $config -Name "schemaVersion" -Context "Configuration")
if ($schemaVersion -ne 1) {
    throw "Unsupported schemaVersion '$schemaVersion'. This installer supports schemaVersion 1."
}
$menuTitle = [string](Get-RequiredProperty -Object $config -Name "menuTitle" -Context "Configuration")

if (-not ($config.PSObject.Properties.Name -contains "programs") -or $null -eq $config.programs) {
    throw "Configuration is missing required property 'programs'."
}

$programs = @($config.programs | Where-Object {
    -not ($_.PSObject.Properties.Name -contains "enabled") -or $_.enabled -eq $true
})
if ($programs.Count -eq 0) {
    throw "Configuration must contain at least one enabled program."
}

$supportedLaunchModes = @("cmd", "windowsTerminal", "direct")
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

    if ($launchMode -eq "windowsTerminal" -and -not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
        Write-Status "  [WARN] Program '$name' uses Windows Terminal, but wt.exe is not currently in PATH." Yellow
    }
    if (-not (Get-Command $command -CommandType Application, ExternalScript -ErrorAction SilentlyContinue) -and
        -not (Test-Path -LiteralPath (Resolve-SourcePath -Path $command -BaseDirectory $configDirectory) -PathType Leaf)) {
        Write-Status "  [WARN] Command for '$name' cannot currently be resolved: $command" Yellow
    }
}

Write-Status "  Configuration: $resolvedConfigPath" Gray
Write-Status "  Menu title:   $menuTitle" Gray
Write-Status "  Programs:     $($programs.Count)" Gray
foreach ($program in $programs) {
    Write-Status "    - $($program.name) [$($program.launchMode)] -> $($program.command)" Gray
}

$sourceLauncher = Join-Path $PSScriptRoot "launcher.ps1"
if (-not (Test-Path -LiteralPath $sourceLauncher -PathType Leaf)) {
    throw "Launcher script was not found: $sourceLauncher"
}

$iconsDirectory = Join-Path $installDir "icons"
if (-not $DryRun) {
    if (Test-Path -LiteralPath $iconsDirectory) {
        Remove-Item -LiteralPath $iconsDirectory -Recurse -Force
    }
    New-Item -ItemType Directory -Path $iconsDirectory -Force | Out-Null
}

$programIcons = @{}
foreach ($program in $programs) {
    $icon = if ($program.PSObject.Properties.Name -contains "icon") { [string]$program.icon } else { $null }
    $programIcons[[string]$program.id] = Copy-MenuIcon -Icon $icon -Id ([string]$program.id) -ConfigDirectory $configDirectory -DestinationDirectory $iconsDirectory
}

$menuIcon = $null
if ($config.PSObject.Properties.Name -contains "menuIcon" -and -not [string]::IsNullOrWhiteSpace([string]$config.menuIcon)) {
    $menuIcon = Copy-MenuIcon -Icon ([string]$config.menuIcon) -Id "menu" -ConfigDirectory $configDirectory -DestinationDirectory $iconsDirectory
} elseif ($programIcons.Count -gt 0) {
    $menuIcon = $programIcons[[string]$programs[0].id]
}

if ($DryRun) {
    Write-Host ""
    Write-Status "  [DRY RUN] Configuration is valid. No files or registry keys were changed." Green
    exit 0
}

Copy-Item -LiteralPath $sourceLauncher -Destination (Join-Path $installDir "launcher.ps1") -Force

# Store a self-contained snapshot. Relative executable paths are made absolute
# before the config is copied away from its source directory.
foreach ($program in @($config.programs)) {
    $command = [string]$program.command
    if (-not [System.IO.Path]::IsPathRooted($command) -and
        ($command.Contains("\") -or $command.Contains("/"))) {
        $relativeCommand = Resolve-SourcePath -Path $command -BaseDirectory $configDirectory
        if (Test-Path -LiteralPath $relativeCommand -PathType Leaf) {
            $program.command = $relativeCommand
        }
    }
}
$config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $installDir "config.json") -Encoding UTF8

# Remove the previous version and rebuild the namespaced menu so reinstalling is idempotent.
Remove-RegisteredMenu -Paths ($registryRoots + $legacyRegistryRoots)

$installedLauncher = Join-Path $installDir "launcher.ps1"
$installedConfig = Join-Path $installDir "config.json"
$powershellExe = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop).Source
$launcherCommandTemplate = '"{0}" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{1}" -ConfigPath "{2}" -ProgramId "{3}" -TargetPath "{4}"'

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
            if ($programIcons[$id]) {
                Set-RegistryString -Path $verbPath -Name "Icon" -Value $programIcons[$id]
            }

            $launcherCommand = $launcherCommandTemplate -f $powershellExe, $installedLauncher, $installedConfig, $id, $targetPlaceholder
            Set-Item -LiteralPath $commandPath -Value $launcherCommand
        }
    }
} catch {
    Remove-RegisteredMenu -Paths $registryRoots
    throw
}

Write-Host ""
Write-Status "  [OK] Installation complete." Green
Write-Status "  Right-click a folder or folder background and open '$menuTitle'." Gray
Write-Status "  Re-run this installer after changing config.json." Gray
Write-Host ""
