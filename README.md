# Windows Sandbox Triage Bootstrapper

A lightweight, disposable [Windows Sandbox](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview) setup for fast, everyday security triage. Double-click one file and you get a clean, throwaway Windows environment with a handful of useful tools already installed.

It is built for **quick, simple tasks** — detonating phishing links, inspecting suspicious text-based files (JavaScript, SVG, HTA, scripts), and decoding small payloads. It is intentionally **not** a full malware reverse-engineering lab. The whole point is speed: spin up, look at the thing, throw the sandbox away.

## Why this exists

Windows Sandbox gives you a fresh, isolated Windows install that is completely discarded when you close it — perfect for handling untrusted files and links. The catch is that a fresh sandbox has *nothing* in it, so every single time you start one you find yourself re-installing the same handful of tools by hand. This project automates that first five minutes so you can get straight to the actual work.

## What you get

On launch, the sandbox automatically installs:

| Tool | Why it's here |
|------|---------------|
| Google Chrome | Primary browser for detonating links |
| Mozilla Firefox | A second engine for comparing how a page behaves |
| Visual Studio Code | Reading and de-obfuscating JS/SVG, regex, syntax highlighting |
| Notepad++ | Fast, lightweight viewer/editor for quick looks |
| 7-Zip | Extracting archives |
| Sysinternals Suite | Procmon, Process Explorer, Autoruns, Strings, etc. |

Sysinternals tools are also copied into `C:\Tools` for convenience, and a setup log is written to `C:\Tools\logs`.

> Office / macro / OLE tooling (Python + `oletools`) is **not** installed by default — see [Optional: Office & macro tooling](#optional-office--macro-tooling) below.

## Requirements

- Windows 10 Pro/Enterprise/Education or Windows 11 Pro/Enterprise/Education (Windows Sandbox is not available on Home editions)
- Windows Sandbox feature enabled:
  - **Settings → Turn Windows features on or off → check "Windows Sandbox"**, or run in an elevated PowerShell:
    ```powershell
    Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online
    ```
  - A reboot is required after enabling.
- Virtualization enabled in BIOS/UEFI.

## Setup

1. Create the folder `C:\WindowsSandbox` on your host machine.
2. Copy `bootstrap.ps1` into it. (Optionally also copy `install-oletools.ps1` — see below.)
3. Save `Sandbox.wsb` wherever you like (Desktop is handy).
4. Double-click `Sandbox.wsb`.

The sandbox boots, runs the bootstrapper minimized, and installs the tools. When `C:\Tools\SETUP_COMPLETE.txt` appears, it's done.

## Design decisions

These are deliberate trade-offs, not accidents:

- **Read-only host mapping.** The host folder `C:\WindowsSandbox` is mapped into the sandbox **read-only**, so nothing running inside can write back to your host. Samples and tools go *in*; nothing comes *out*.
- **Networking is on by default.** You usually *want* network access to detonate a phishing link and watch the redirects. If you are instead looking at a file you don't want phoning home, networking can be disabled with a one-line toggle (see below). Note that with networking off, the bootstrapper can't download anything, so you'd need to pre-stage tools.
- **vGPU disabled.** Reduces the guest-to-host attack surface; not needed for this kind of triage.
- **Fast by default, heavier tools on demand.** Python and `oletools` add ~10 minutes to startup because of their dependencies, so they are kept out of the default path and available via a separate script when you actually need them.
- **Honest, unattended runs.** The script disables console QuickEdit mode (so a stray click can't freeze it), wraps every install in error handling, prints a truthful success/failure summary, and logs a transcript to `C:\Tools\logs`.

## Toggling networking off

Open `Sandbox.wsb` in a text editor and uncomment this line:

```xml
<!-- <Networking>Disable</Networking> -->
```

so it reads:

```xml
<Networking>Disable</Networking>
```

Remember: with networking disabled the bootstrapper cannot download tools, so either run it online first or pre-stage what you need in the mapped folder.

## Optional: Office & macro tooling

If you need to triage Office documents or macros (`olevba`, `oleid`, `mraptor`), copy `install-oletools.ps1` into `C:\WindowsSandbox` as well, then run it **inside the running sandbox** from an elevated PowerShell:

```powershell
C:\WindowsSandbox\install-oletools.ps1
```

It installs Python (via Chocolatey) and `oletools`. This is kept separate on purpose — it's the slow part, and most quick jobs never need it.

## Files

| File | Purpose |
|------|---------|
| `Sandbox.wsb` | The Windows Sandbox configuration you double-click to launch |
| `bootstrap.ps1` | Runs automatically on launch; installs the default tools |
| `install-oletools.ps1` | Optional, on-demand; adds Python + oletools when needed |

## Notes & caveats

- First launch downloads everything fresh, so it depends on your connection. The default tool set is intentionally small to keep this quick.
- Chocolatey packages always pull the latest version, so exact versions aren't pinned.
- Everything in the sandbox is destroyed when you close it — that's the point. Save anything you want to keep before closing.

## Disclaimer

This is a convenience tool for handling potentially malicious content inside an isolated, disposable environment. Windows Sandbox provides strong isolation but no sandbox is perfect. Use good judgment, keep your host patched, and understand what you're doing before detonating live malicious content. Provided as-is, with no warranty.

## License

MIT — see [LICENSE](LICENSE).