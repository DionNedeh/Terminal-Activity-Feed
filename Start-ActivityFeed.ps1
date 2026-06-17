#requires -Version 5.1

$scriptPath = Join-Path $PSScriptRoot "ActivityFeed.ps1"

& $scriptPath -WatchPaths "$env:USERPROFILE\OneDrive\Desktop","$env:USERPROFILE\Downloads","$env:TEMP"
