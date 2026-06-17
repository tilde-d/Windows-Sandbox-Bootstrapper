# =========================================================
# install-oletools.ps1  (run ON DEMAND inside the sandbox)
# ---------------------------------------------------------
# Installs Python + oletools for Office / OLE / macro triage
# (olevba, oleid, mraptor, etc.).
#
# This is deliberately NOT part of bootstrap.ps1: Python pulls in
# the VC++ redistributable and adds ~10 minutes to startup, which
# defeats the "fast bootstrapper" goal. Run this only when you
# actually have a sample that needs it.
#
# Usage (inside the running sandbox, from an elevated PowerShell):
#     C:\WindowsSandbox\install-oletools.ps1
# =========================================================

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

Write-Host ""
Write-Host "========================================="
Write-Host " Installing Python + oletools (on demand)"
Write-Host "========================================="
Write-Host ""

# Ensure TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = `
    [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# --- Python via Chocolatey (installs VC++ redist as a dependency) ---
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Warning "[-] Chocolatey not found. Run bootstrap.ps1 first, or install choco."
    return
}

Write-Host "[+] Installing Python (this is the slow part)..."
try {
    choco install python -y --no-progress
}
catch {
    Write-Warning "[-] Python install FAILED: $($_.Exception.Message)"
    return
}

# Refresh PATH for this session so python/pip resolve without a new shell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

$pythonExe = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonExe) {
    Write-Warning "[-] Python not on PATH yet. Open a NEW PowerShell window and run:"
    Write-Warning "        python -m pip install oletools"
    return
}

Write-Host "[+] Installing oletools via pip..."
try {
    python -m pip install --upgrade pip --quiet
    python -m pip install oletools --quiet
    Write-Host ""
    Write-Host "[+] Done. Try:  olevba <suspicious-file>"
}
catch {
    Write-Warning "[-] oletools install FAILED: $($_.Exception.Message)"
}

Write-Host ""