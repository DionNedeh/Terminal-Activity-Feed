# Terminal Activity Feed

A terminal-style live Windows activity monitor for processes, file changes, and TCP connection changes.

It prints a color-coded feed in Windows PowerShell:

- `PROC+` and `PROC-` for process starts and stops
- `FILE+`, `FILE*`, `FILE-`, and `FILE>` for file creation, changes, deletion, and renames
- `NET+` and `NET-` for TCP connection opens and closes

## Requirements

- Windows
- Windows PowerShell 5.1
- Administrator mode recommended for the most complete process and network feed

PowerShell 7 is not recommended for this script because the process watcher uses `Register-WmiEvent`, which is available in Windows PowerShell 5.1.

## Quick Start

Open Windows PowerShell as Administrator, then run:

```powershell
.\ActivityFeed.ps1 -WatchPaths "$env:USERPROFILE\OneDrive\Desktop","$env:USERPROFILE\Downloads","$env:TEMP"
```

That watches:

- OneDrive Desktop
- Downloads
- Temp

Press `Ctrl+C` to stop the feed.

## One-Command Starter

The repo also includes `Start-ActivityFeed.ps1`, which runs the same working command:

```powershell
.\Start-ActivityFeed.ps1
```

## Download From GitHub

### Option 1: Download ZIP

1. Open the repo on GitHub.
2. Click `Code`.
3. Click `Download ZIP`.
4. Extract the ZIP.
5. Open Windows PowerShell as Administrator in the extracted folder.
6. Run:

```powershell
.\Start-ActivityFeed.ps1
```

### Option 2: Download With PowerShell

Run this in Windows PowerShell:

```powershell
$dest = Join-Path $env:USERPROFILE "Terminal-Activity-Feed"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Invoke-WebRequest "https://raw.githubusercontent.com/DionNedeh/Terminal-Activity-Feed/main/ActivityFeed.ps1" -OutFile (Join-Path $dest "ActivityFeed.ps1")
Invoke-WebRequest "https://raw.githubusercontent.com/DionNedeh/Terminal-Activity-Feed/main/Start-ActivityFeed.ps1" -OutFile (Join-Path $dest "Start-ActivityFeed.ps1")

Set-Location $dest
.\Start-ActivityFeed.ps1
```

If Windows blocks the downloaded script, unblock it:

```powershell
Unblock-File .\ActivityFeed.ps1
Unblock-File .\Start-ActivityFeed.ps1
```

Then run:

```powershell
.\Start-ActivityFeed.ps1
```

## Options

Watch custom folders:

```powershell
.\ActivityFeed.ps1 -WatchPaths "$env:USERPROFILE\Desktop","$env:USERPROFILE\Downloads"
```

Disable file watching:

```powershell
.\ActivityFeed.ps1 -NoFiles
```

Disable network watching:

```powershell
.\ActivityFeed.ps1 -NoNetwork
```

Change network polling speed:

```powershell
.\ActivityFeed.ps1 -NetworkPollSeconds 5
```

## Notes

- The feed is live and keeps running until stopped.
- Some TCP/process details may show as `unknown` without Administrator mode.
- File watching includes subdirectories under each watched path.
- Very busy folders can produce a lot of events quickly.
