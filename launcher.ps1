[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$ProgramId,

    [Parameter(Mandatory = $true)]
    [string]$TargetPath
)

$ErrorActionPreference = "Stop"

function Resolve-ProgramCommand {
    param(
        [string]$Command,
        [string]$BaseDirectory
    )

    $resolvedCommand = Get-Command $Command -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($resolvedCommand) {
        return $resolvedCommand.Source
    }

    $candidate = if ([System.IO.Path]::IsPathRooted($Command)) {
        $Command
    } else {
        Join-Path $BaseDirectory $Command
    }
    $candidate = [System.IO.Path]::GetFullPath($candidate)

    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Program command was not found: $Command"
    }
    return $candidate
}

function ConvertTo-WindowsCommandLineArgument {
    param([AllowEmptyString()][string]$Value)

    # Quote according to the CommandLineToArgvW escaping rules.
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function ConvertTo-CmdToken {
    param([AllowEmptyString()][string]$Value)

    # Keep ordinary CLI tokens unchanged so cmd receives the same command a
    # user would type. Only add cmd-style quotes when a token needs them.
    if ($Value -match '^[A-Za-z0-9_.:\\/@=+,\-]+$') {
        return $Value
    }
    return '"' + $Value.Replace('"', '""') + '"'
}

$resolvedConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
$configDirectory = Split-Path -Parent $resolvedConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$program = @($config.programs | Where-Object { [string]$_.id -eq $ProgramId }) | Select-Object -First 1

if (-not $program) {
    throw "Program id '$ProgramId' does not exist in configuration."
}
if (($program.PSObject.Properties.Name -contains "enabled") -and $program.enabled -ne $true) {
    throw "Program '$ProgramId' is disabled."
}
if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    throw "Target folder does not exist: $TargetPath"
}

$launchMode = [string]$program.launchMode
$configuredCommand = [string]$program.command
$command = if ($launchMode -eq "cmd") {
    $configuredCommand
} else {
    Resolve-ProgramCommand -Command $configuredCommand -BaseDirectory $configDirectory
}
$arguments = @()
if ($program.PSObject.Properties.Name -contains "arguments" -and $null -ne $program.arguments) {
    $arguments = @($program.arguments | ForEach-Object { ([string]$_).Replace('{path}', $TargetPath) })
}

switch ($launchMode) {
    "direct" {
        $startParameters = @{
            FilePath = $command
            WorkingDirectory = $TargetPath
        }
        if ($arguments.Count -gt 0) {
            $startParameters.ArgumentList = (@($arguments | ForEach-Object {
                ConvertTo-WindowsCommandLineArgument ([string]$_)
            }) -join " ")
        }
        Start-Process @startParameters
    }

    "cmd" {
        $parts = @((ConvertTo-CmdToken $command))
        $parts += @($arguments | ForEach-Object { ConvertTo-CmdToken ([string]$_) })
        $commandLine = $parts -join " "
        $cmdArguments = '/d /s /k "' + $commandLine + '"'
        Start-Process -FilePath $env:ComSpec -ArgumentList $cmdArguments -WorkingDirectory $TargetPath
    }

    "windowsTerminal" {
        $wt = Resolve-ProgramCommand -Command "wt.exe" -BaseDirectory $configDirectory
        $wtArguments = @("-w", "new", "new-tab", "-d", $TargetPath, $command) + $arguments
        $wtArguments = $wtArguments |
            ForEach-Object { ConvertTo-WindowsCommandLineArgument ([string]$_) }
        Start-Process -FilePath $wt -ArgumentList ($wtArguments -join " ")
    }

    default {
        throw "Unsupported launchMode '$($program.launchMode)' for program '$ProgramId'."
    }
}
