param(
    [string]$GodotPath = "",
    [int]$Port = 24677,
    [int]$TimeoutMs = 45000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot console executable not found: $GodotPath" }

$logRoot = Join-Path $projectRoot ".tools\network_four_player_logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$processes = @()
$logs = @()
$roles = @("host", "client1", "client2", "client3", "client4")
$common = @("--headless", "--path", $projectRoot, "--script", "res://tests/network_four_player_peer.gd", "--", "--port=$Port")

try {
    for ($index = 0; $index -lt $roles.Count; $index++) {
        $role = $roles[$index]
        $outLog = Join-Path $logRoot "${stamp}_${role}.out.log"
        $errLog = Join-Path $logRoot "${stamp}_${role}.err.log"
        $roleArg = if ($index -eq 0) { "--role=host" } else { "--role=client" }
        $arguments = $common + $roleArg + "--client-index=$index"
        $processes += Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
        $logs += @{ Role = $role; Out = $outLog; Err = $errLog }
        Start-Sleep -Milliseconds 220
    }

    $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
    foreach ($process in $processes) {
        $remaining = [Math]::Max(1, [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds)
        if (-not $process.WaitForExit($remaining)) {
            throw "Four-player capacity test timed out. Logs: $logRoot"
        }
        $process.WaitForExit()
        $process.Refresh()
    }
} finally {
    foreach ($process in $processes) {
        if (-not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
        }
    }
}

$failed = $false
foreach ($log in $logs) {
    $text = (Get-Content -LiteralPath $log.Out -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $log.Err -Raw -ErrorAction SilentlyContinue)
    Write-Host $text
    $marker = "NETWORK_FOUR_PLAYER_$($log.Role.ToUpper())_PASS"
    if ($text -notmatch [regex]::Escape($marker)) { $failed = $true }
}
if ($failed) { throw "Four-player capacity test failed. Logs: $logRoot" }
Write-Host "Four-player localhost capacity test passed."
