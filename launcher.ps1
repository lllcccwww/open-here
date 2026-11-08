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

function Test-TcpEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [System.Uri]$Uri,

        [int]$TimeoutMilliseconds = 500
    )

    $port = if ($Uri.IsDefaultPort) {
        if ($Uri.Scheme -eq "https") { 443 } else { 80 }
    } else {
        $Uri.Port
    }

    $client = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $null
    try {
        $asyncResult = $client.BeginConnect($Uri.DnsSafeHost, $port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }
        $client.EndConnect($asyncResult)
        return $true
    } catch {
        return $false
    } finally {
        if ($null -ne $asyncResult) {
            $asyncResult.AsyncWaitHandle.Close()
        }
        $client.Close()
    }
}

function Open-WebAddress {
    param([Parameter(Mandatory = $true)][System.Uri]$Uri)

    Start-Process -FilePath $Uri.AbsoluteUri
}

function Start-ConfiguredProgram {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Program,

        [Parameter(Mandatory = $true)]
        [string]$ConfigDirectory,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $launchMode = [string]$Program.launchMode
    $command = Resolve-ProgramCommand -Command ([string]$Program.command) -BaseDirectory $ConfigDirectory
    $arguments = @()
    if ($Program.PSObject.Properties.Name -contains "arguments" -and $null -ne $Program.arguments) {
        $arguments = @($Program.arguments | ForEach-Object { ([string]$_).Replace('{path}', $TargetPath) })
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
            $wt = Resolve-ProgramCommand -Command "wt.exe" -BaseDirectory $ConfigDirectory
            $wtArguments = @("-w", "new", "new-tab", "-d", $TargetPath, $command) + $arguments
            $wtArguments = $wtArguments |
                ForEach-Object { ConvertTo-WindowsCommandLineArgument ([string]$_) }
            Start-Process -FilePath $wt -ArgumentList ($wtArguments -join " ")
        }

        "webService" {
            $url = [System.Uri]([string]$Program.url)
            $startupTimeoutSeconds = if ($Program.PSObject.Properties.Name -contains "startupTimeoutSeconds") {
                [int]$Program.startupTimeoutSeconds
            } else {
                90
            }

            if (Test-TcpEndpoint -Uri $url) {
                Open-WebAddress -Uri $url
                return
            }

            # Serialize launches for the same menu item. A second click waits for
            # the first invocation instead of starting another server process.
            $mutex = New-Object System.Threading.Mutex($false, "Local\OpenHereMenu-$($Program.id)")
            $hasMutex = $false
            try {
                try {
                    $hasMutex = $mutex.WaitOne([TimeSpan]::FromSeconds($startupTimeoutSeconds))
                } catch [System.Threading.AbandonedMutexException] {
                    $hasMutex = $true
                }
                if (-not $hasMutex) {
                    throw "Timed out waiting to launch web service '$($Program.id)'."
                }

                if (-not (Test-TcpEndpoint -Uri $url)) {
                    $parts = @((ConvertTo-CmdToken $command))
                    $parts += @($arguments | ForEach-Object { ConvertTo-CmdToken ([string]$_) })
                    $commandLine = $parts -join " "
                    $cmdArguments = '/d /s /c "' + $commandLine + '"'
                    Start-Process -FilePath $env:ComSpec -ArgumentList $cmdArguments -WorkingDirectory $TargetPath | Out-Null
                }

                $deadline = [DateTime]::UtcNow.AddSeconds($startupTimeoutSeconds)
                while ([DateTime]::UtcNow -lt $deadline) {
                    if (Test-TcpEndpoint -Uri $url) {
                        Open-WebAddress -Uri $url
                        return
                    }
                    Start-Sleep -Milliseconds 250
                }

                throw "Web service '$($Program.id)' did not listen at $($url.AbsoluteUri) within $startupTimeoutSeconds seconds."
            } finally {
                if ($hasMutex) {
                    $mutex.ReleaseMutex()
                }
                $mutex.Dispose()
            }
        }

        default {
            throw "Unsupported launchMode '$launchMode' for program '$($Program.id)'."
        }
    }
}

try {
    $resolvedConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
    if (-not (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf)) {
        throw "Configuration file was not found: $resolvedConfigPath"
    }
    $configDirectory = Split-Path -Parent $resolvedConfigPath
    $config = Get-Content -LiteralPath $resolvedConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
        throw "Target folder does not exist: $TargetPath"
    }

    $program = @($config.programs | Where-Object { [string]$_.id -eq $ProgramId }) | Select-Object -First 1
    if (-not $program) {
        throw "Program id '$ProgramId' does not exist in configuration."
    }
    if (($program.PSObject.Properties.Name -contains "enabled") -and $program.enabled -ne $true) {
        throw "Program '$ProgramId' is disabled."
    }

    Start-ConfiguredProgram -Program $program -ConfigDirectory $configDirectory -TargetPath $TargetPath
} catch {
    # The launcher runs from a hidden window; surface problems in a dialog so a
    # failed click is never silent.
    $message = $_.Exception.Message
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($message, "Open Here")
    } catch {
        Write-Error $message
    }
    exit 1
}
