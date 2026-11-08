# scripts/setup_poll_task.ps1 -- register the Steam poll in Windows Task Scheduler (run ONCE).
# It runs scripts/poll_players.R every 3 hours, hidden, until December 1, 2026.
# From Git Bash, in the project folder:
#   powershell.exe -ExecutionPolicy Bypass -File scripts/setup_poll_task.ps1
# To remove it later:   Unregister-ScheduledTask -TaskName "DATA220 Steam poll" -Confirm:$false
# The computer must be on (or asleep -- the task wakes it) and you must be logged in.

$ErrorActionPreference = "Stop"
$TaskName = "DATA220 Steam poll"

$project = Split-Path -Parent $PSScriptRoot
$script  = Join-Path $project "scripts\poll_players.R"
$logFile = Join-Path $project "logs\poll_task.log"
New-Item -ItemType Directory -Force -Path (Join-Path $project "logs") | Out-Null

# Find Rscript.exe: on the PATH, or in the usual install folder (newest version).
$rscript = (Get-Command Rscript.exe -ErrorAction SilentlyContinue).Source
if (-not $rscript) {
  $rscript = Get-ChildItem "C:\Program Files\R\R-*\bin\Rscript.exe" -ErrorAction SilentlyContinue |
             Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $rscript) { throw "Rscript.exe not found. Is R installed?" }

# Hidden PowerShell runs Rscript, so no window pops up every 3 hours; all output goes to the log.
$command  = "& '$rscript' '$script' *>> '$logFile'"
$action   = New-ScheduledTaskAction -Execute "powershell.exe" `
              -Argument "-NoProfile -WindowStyle Hidden -Command `"$command`"" `
              -WorkingDirectory $project

# First run at the next whole hour divisible by 3 (local time), then every 3 hours to Dec 1.
$now   = Get-Date
$start = $now.Date.AddHours([math]::Ceiling(($now.Hour + $now.Minute / 60 + 0.01) / 3) * 3)
$end   = Get-Date "2026-12-01 00:00"
$trigger = New-ScheduledTaskTrigger -Once -At $start `
             -RepetitionInterval (New-TimeSpan -Hours 3) -RepetitionDuration ($end - $start)

# Catch up after a missed start, wake the computer, run on battery, never two at once.
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun `
              -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
              -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
  -Description "DATA 220 Team 4: Steam player counts every 3 h, store prices daily" -Force | Out-Null

Write-Host "Registered '$TaskName'"
Write-Host "  Rscript:   $rscript"
Write-Host "  Script:    $script"
Write-Host "  First run: $start, then every 3 hours until $end"
Write-Host "  Log:       $logFile"
