# ============================================
# Open Claude Now - Install Script
# Adds "Open Claude Code Here" to Windows right-click context menu
# ============================================

param(
    [switch]$UseWindowsTerminal,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$regPathBg  = "HKCU:\SOFTWARE\Classes\Directory\Background\shell\ClaudeCode"
$regPathDir = "HKCU:\SOFTWARE\Classes\Directory\shell\ClaudeCode"

# --- Uninstall ---
if ($Uninstall) {
    $removed = $false
    if (Test-Path $regPathBg) {
        Remove-Item -Path $regPathBg -Recurse -Force
        $removed = $true
    }
    if (Test-Path $regPathDir) {
        Remove-Item -Path $regPathDir -Recurse -Force
        $removed = $true
    }
    if ($removed) {
        Write-Host "[OK] Claude Code context menu has been removed." -ForegroundColor Green
    } else {
        Write-Host "[INFO] Claude Code context menu was not installed. Nothing to remove." -ForegroundColor Yellow
    }
    exit 0
}

# --- Pre-flight checks ---
Write-Host ""
Write-Host "  Open Claude Now - Installer" -ForegroundColor Cyan
Write-Host "  ============================" -ForegroundColor Cyan
Write-Host ""

# Check if claude is available
$claudePath = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudePath) {
    Write-Host "[ERROR] 'claude' command not found in PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please install Claude Code first:" -ForegroundColor Yellow
    Write-Host "    npm install -g @anthropic-ai/claude-code" -ForegroundColor White
    Write-Host ""
    Write-Host "  Then re-run this script." -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] Found claude at: $($claudePath.Source)" -ForegroundColor Green

# Locate the icon file (claude.ico next to this script)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$iconFile  = Join-Path $scriptDir "assets\claude.ico"
if (Test-Path $iconFile) {
    Write-Host "  [OK] Found icon: $iconFile" -ForegroundColor Green
} else {
    Write-Host "  [WARN] claude.ico not found next to script, using default icon." -ForegroundColor Yellow
    $iconFile = "cmd.exe"
}

# Determine the launch command
if ($UseWindowsTerminal) {
    $wtPath = Get-Command wt -ErrorAction SilentlyContinue
    if (-not $wtPath) {
        Write-Host "[ERROR] Windows Terminal (wt.exe) not found." -ForegroundColor Red
        Write-Host "  Re-run without -UseWindowsTerminal to use cmd.exe instead." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [OK] Using Windows Terminal" -ForegroundColor Green
    $launchCmd = 'wt.exe -d "%V" cmd /k claude'
} else {
    Write-Host "  [OK] Using cmd.exe (add -UseWindowsTerminal for Windows Terminal)" -ForegroundColor Green
    $launchCmd = 'cmd.exe /k cd /d "%V" && claude'
}

# --- Install registry entries ---
Write-Host ""
Write-Host "  Installing context menu entries..." -ForegroundColor Cyan

# Right-click on folder background (inside a folder)
New-Item -Path "$regPathBg\command" -Force | Out-Null
Set-ItemProperty -Path $regPathBg -Name "(Default)" -Value "Open Claude Code Here"
Set-ItemProperty -Path $regPathBg -Name "Icon" -Value $iconFile
Set-ItemProperty -Path "$regPathBg\command" -Name "(Default)" -Value $launchCmd

# Right-click on a folder
New-Item -Path "$regPathDir\command" -Force | Out-Null
Set-ItemProperty -Path $regPathDir -Name "(Default)" -Value "Open Claude Code Here"
Set-ItemProperty -Path $regPathDir -Name "Icon" -Value $iconFile
Set-ItemProperty -Path "$regPathDir\command" -Name "(Default)" -Value $launchCmd

Write-Host ""
Write-Host "  [OK] Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Usage:" -ForegroundColor White
Write-Host "    - Right-click inside any folder  -> 'Open Claude Code Here'" -ForegroundColor Gray
Write-Host "    - Right-click on any folder      -> 'Open Claude Code Here'" -ForegroundColor Gray
Write-Host ""
Write-Host "  Note for Windows 11:" -ForegroundColor Yellow
Write-Host "    The option appears under 'Show more options' (classic menu)." -ForegroundColor Gray
Write-Host "    To restore the classic right-click menu system-wide, run:" -ForegroundColor Gray
Write-Host '    reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve' -ForegroundColor Gray
Write-Host ""
Write-Host "  To uninstall, run:" -ForegroundColor White
Write-Host "    powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall" -ForegroundColor Gray
Write-Host ""
