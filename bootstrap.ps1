# =========================================================
# Windows Sandbox Bootstrap Script
# ---------------------------------------------------------
# Purpose: Quickly provision a disposable Windows Sandbox for
#          light-touch triage tasks: detonating phishing links,
#          inspecting suspicious text-based files (JS, SVG, HTA,
#          scripts), decoding payloads, etc.
#
# NOT intended as a full malware reverse-engineering lab.
# =========================================================

# ---------------------------------------------------------
# Disable console QuickEdit mode
# ---------------------------------------------------------
# QuickEdit lets a stray click (or certain output) put the console
# into selection mode, which FREEZES the running process until the
# user presses Enter. That makes an unattended bootstrapper hang.
# Turn it off so installs run start-to-finish without intervention.
try {
    $sig = @'
using System;
using System.Runtime.InteropServices;
public static class ConsoleMode {
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr GetStdHandle(int handle);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool GetConsoleMode(IntPtr handle, out int mode);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool SetConsoleMode(IntPtr handle, int mode);
    public static void DisableQuickEdit() {
        IntPtr h = GetStdHandle(-10); // STD_INPUT_HANDLE
        int mode;
        if (GetConsoleMode(h, out mode)) {
            mode &= ~0x0040;          // clear ENABLE_QUICK_EDIT_MODE
            mode |=  0x0080;          // set ENABLE_EXTENDED_FLAGS
            SetConsoleMode(h, mode);
        }
    }
}
'@
    Add-Type -TypeDefinition $sig -ErrorAction SilentlyContinue
    [ConsoleMode]::DisableQuickEdit()
}
catch {
    # Non-fatal: if this fails (e.g. no console), just continue.
}

# ---------------------------------------------------------
# Logging / transcript
# ---------------------------------------------------------
$ErrorActionPreference = "Stop"
$logDir = "C:\Tools\logs"
$null = New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue
$transcript = Join-Path $logDir ("bootstrap_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
try { Start-Transcript -Path $transcript -Force | Out-Null } catch {}

Write-Host ""
Write-Host "========================================="
Write-Host " Windows Sandbox Bootstrap Starting..."
Write-Host "========================================="
Write-Host ""

# Track outcomes so the summary at the end is honest
$installed = @()
$failed    = @()

# Allow script execution for this session only
Set-ExecutionPolicy Bypass -Scope Process -Force

# Ensure TLS 1.2 for Chocolatey install
[System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# ---------------------------------------------------------
# Install Chocolatey (if not already installed)
# ---------------------------------------------------------
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Host "[+] Installing Chocolatey..."
    try {
        Invoke-Expression (
            (New-Object System.Net.WebClient).DownloadString(
                'https://community.chocolatey.org/install.ps1'
            )
        )
        $env:Path += ";C:\ProgramData\chocolatey\bin"
        Write-Host "[+] Chocolatey installed."
    }
    catch {
        Write-Warning "[-] Chocolatey install FAILED: $($_.Exception.Message)"
        Write-Warning "    Without Chocolatey, package installs below will be skipped."
    }
}
else {
    Write-Host "[+] Chocolatey already installed."
}

# ---------------------------------------------------------
# Install Applications
# ---------------------------------------------------------
# Tweak this list to taste. Kept lean on purpose.
$packages = @(
    "googlechrome",       # primary browser for detonation
    "firefox",            # second engine for comparing page behavior
    "vscode",             # JS/SVG deobfuscation, regex, syntax tooling
    "notepadplusplus",    # fast lightweight viewer/editor
    "7zip",               # archive extraction
    "sysinternals"        # procmon, procexp, autoruns, strings, etc.
)

if (Get-Command choco.exe -ErrorAction SilentlyContinue) {
    foreach ($pkg in $packages) {
        Write-Host ""
        Write-Host "[+] Installing $pkg ..."
        try {
            choco install $pkg -y --no-progress
            if ($LASTEXITCODE -eq 0) { $installed += $pkg }
            else { $failed += $pkg; Write-Warning "[-] $pkg exited with code $LASTEXITCODE" }
        }
        catch {
            $failed += $pkg
            Write-Warning "[-] $pkg FAILED: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Warning "[-] Skipping package installs (Chocolatey unavailable)."
    $failed += $packages
}

# ---------------------------------------------------------
# Optional: Python + oletools
# ---------------------------------------------------------
# Python is intentionally NOT installed here. It (and its VC++ redist
# dependency) add ~10 min to startup, which defeats the "fast" goal.
# For Office/macro/OLE samples that need olevba/oleid, run the
# companion script INSIDE the sandbox on demand:
#     C:\WindowsSandbox\install-oletools.ps1

# ---------------------------------------------------------
# Tools folder
# ---------------------------------------------------------
$toolsPath = "C:\Tools"
$null = New-Item -ItemType Directory -Path $toolsPath -Force -ErrorAction SilentlyContinue

# --- Sysinternals: copy into C:\Tools for convenience ---
$sysinternalsPath = "C:\ProgramData\chocolatey\lib\sysinternals\tools"
if (Test-Path $sysinternalsPath) {
    Copy-Item "$sysinternalsPath\*" $toolsPath -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------
# Finish — honest summary
# ---------------------------------------------------------
Write-Host ""
Write-Host "========================================="
Write-Host " Sandbox Setup Complete"
Write-Host "========================================="
Write-Host ""
Write-Host "Installed / succeeded:"
$installed | Sort-Object -Unique | ForEach-Object { Write-Host "   [+] $_" }
if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed / skipped:" -ForegroundColor Yellow
    $failed | Sort-Object -Unique | ForEach-Object { Write-Host "   [-] $_" -ForegroundColor Yellow }
}
Write-Host ""
Write-Host "Tools folder : $toolsPath"
Write-Host "Log file     : $transcript"
Write-Host ""
Write-Host "Need Office/macro tools (olevba etc.)? Run on demand:"
Write-Host "   C:\WindowsSandbox\install-oletools.ps1"
Write-Host ""

try { Stop-Transcript | Out-Null } catch {}

# Drop a visible completion marker (the launch window is minimized,
# so a Pause there can hang invisibly). Write a marker file AND
# leave a foreground prompt if run interactively.
$marker = Join-Path $toolsPath "SETUP_COMPLETE.txt"
"Sandbox bootstrap finished: $(Get-Date)" | Out-File -FilePath $marker -Encoding UTF8

Write-Host "Setup complete. You can close this window."
Write-Host ""