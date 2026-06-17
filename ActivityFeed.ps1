#requires -Version 5.1

# ActivityFeed.ps1
# A terminal-style live Windows activity monitor.
# Run in Windows PowerShell as Administrator for best results.

param(
    [string[]]$WatchPaths = @(
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Downloads",
        "$env:TEMP"
    ),

    [int]$NetworkPollSeconds = 2,

    [switch]$NoFiles,
    [switch]$NoNetwork
)

$ErrorActionPreference = "Continue"

$subscriptions = @()
$watchers = @()
$seenConnections = @{}
$lastNetworkPoll = Get-Date

function Write-Feed {
    param(
        [string]$Type,
        [string]$Message,
        [ConsoleColor]$Color = "Gray"
    )

    $time = (Get-Date).ToString("HH:mm:ss.fff")
    Write-Host "[$time] [$Type] $Message" -ForegroundColor $Color
}

function Get-ProcessNameSafe {
    param(
        [Alias("Pid")]
        [int]$TargetProcessId
    )

    try {
        return (Get-Process -Id $TargetProcessId -ErrorAction Stop).ProcessName
    } catch {
        return "unknown"
    }
}

function Get-TcpSnapshot {
    $snapshot = @{}

    try {
        $connections = Get-NetTCPConnection -ErrorAction Stop |
            Where-Object {
                $_.State -in @("Established", "Listen", "SynSent", "SynReceived")
            }

        foreach ($conn in $connections) {
            $key = "$($conn.OwningProcess)|$($conn.LocalAddress):$($conn.LocalPort)|$($conn.RemoteAddress):$($conn.RemotePort)|$($conn.State)"
            $snapshot[$key] = $conn
        }
    } catch {
        Write-Feed "WARN" "Could not read TCP connections. Try running as Administrator." Yellow
    }

    return $snapshot
}

function Poll-Network {
    if ($NoNetwork) {
        return
    }

    $current = Get-TcpSnapshot

    foreach ($key in $current.Keys) {
        if (-not $seenConnections.ContainsKey($key)) {
            $conn = $current[$key]
            $procName = Get-ProcessNameSafe -Pid $conn.OwningProcess

            Write-Feed "NET+" "$procName PID=$($conn.OwningProcess) $($conn.LocalAddress):$($conn.LocalPort) -> $($conn.RemoteAddress):$($conn.RemotePort) $($conn.State)" Magenta
        }
    }

    foreach ($key in @($seenConnections.Keys)) {
        if (-not $current.ContainsKey($key)) {
            $conn = $seenConnections[$key]
            $procName = Get-ProcessNameSafe -Pid $conn.OwningProcess

            Write-Feed "NET-" "$procName PID=$($conn.OwningProcess) $($conn.LocalAddress):$($conn.LocalPort) -> $($conn.RemoteAddress):$($conn.RemotePort) closed" DarkMagenta
        }
    }

    $script:seenConnections = $current
}

function Handle-Event {
    param($Event)

    switch -Wildcard ($Event.SourceIdentifier) {
        "PROC_START" {
            $e = $Event.SourceEventArgs.NewEvent
            Write-Feed "PROC+" "$($e.ProcessName) PID=$($e.ProcessID) ParentPID=$($e.ParentProcessID)" Green
        }

        "PROC_STOP" {
            $e = $Event.SourceEventArgs.NewEvent
            Write-Feed "PROC-" "$($e.ProcessName) PID=$($e.ProcessID)" DarkGreen
        }

        "FILE_CREATED_*" {
            $e = $Event.SourceEventArgs
            Write-Feed "FILE+" "$($e.FullPath)" Cyan
        }

        "FILE_CHANGED_*" {
            $e = $Event.SourceEventArgs
            Write-Feed "FILE*" "$($e.FullPath)" DarkCyan
        }

        "FILE_DELETED_*" {
            $e = $Event.SourceEventArgs
            Write-Feed "FILE-" "$($e.FullPath)" Red
        }

        "FILE_RENAMED_*" {
            $e = $Event.SourceEventArgs
            Write-Feed "FILE>" "$($e.OldFullPath) -> $($e.FullPath)" Yellow
        }
    }
}

try {
    Clear-Host
    Write-Feed "BOOT" "Starting terminal activity feed..." White

    $subscriptions += Register-WmiEvent -Class Win32_ProcessStartTrace -SourceIdentifier "PROC_START"
    $subscriptions += Register-WmiEvent -Class Win32_ProcessStopTrace -SourceIdentifier "PROC_STOP"

    if (-not $NoFiles) {
        $index = 0

        foreach ($path in $WatchPaths) {
            if (Test-Path $path) {
                $resolved = (Resolve-Path $path).Path

                $watcher = New-Object System.IO.FileSystemWatcher
                $watcher.Path = $resolved
                $watcher.IncludeSubdirectories = $true
                $watcher.EnableRaisingEvents = $true
                $watcher.NotifyFilter = [System.IO.NotifyFilters]"FileName, DirectoryName, LastWrite, Size, CreationTime"

                $watchers += $watcher

                $subscriptions += Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier "FILE_CREATED_$index"
                $subscriptions += Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier "FILE_CHANGED_$index"
                $subscriptions += Register-ObjectEvent -InputObject $watcher -EventName Deleted -SourceIdentifier "FILE_DELETED_$index"
                $subscriptions += Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier "FILE_RENAMED_$index"

                Write-Feed "WATCH" "Watching files under: $resolved" Blue
                $index++
            } else {
                Write-Feed "SKIP" "Path not found: $path" DarkYellow
            }
        }
    }

    if (-not $NoNetwork) {
        $seenConnections = Get-TcpSnapshot
        Write-Feed "WATCH" "Watching TCP connection changes every $NetworkPollSeconds seconds" Blue
    }

    Write-Feed "READY" "Live feed running. Press Ctrl+C to stop." White

    while ($true) {
        $event = Wait-Event -Timeout 1

        if ($null -ne $event) {
            Handle-Event $event
            Remove-Event -EventIdentifier $event.EventIdentifier

            while ($queued = Get-Event | Select-Object -First 1) {
                Handle-Event $queued
                Remove-Event -EventIdentifier $queued.EventIdentifier
            }
        }

        if (-not $NoNetwork) {
            $now = Get-Date
            if (($now - $lastNetworkPoll).TotalSeconds -ge $NetworkPollSeconds) {
                Poll-Network
                $lastNetworkPoll = $now
            }
        }
    }
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Feed "STOP" "Cleaning up watchers..." Yellow

    foreach ($sub in $subscriptions) {
        Unregister-Event -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
    }

    foreach ($watcher in $watchers) {
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
    }

    Get-Event | Remove-Event -ErrorAction SilentlyContinue

    Write-Feed "DONE" "Activity feed stopped." White
}
