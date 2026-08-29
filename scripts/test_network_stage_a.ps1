param(
    [string]$GodotPath = "",
    [string]$PeerScript = "res://tests/network_stage_a_peer.gd",
    [int]$Port = 24607,
    [string]$HostMarker = "NETWORK_STAGE_C_HOST_PASS",
    [string]$ClientMarker = "NETWORK_STAGE_C_CLIENT_PASS",
    [string]$Label = "Stage C localhost host/client integration",
    [int]$TimeoutMs = 20000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not $GodotPath) {
    $GodotPath = Join-Path $projectRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot console executable not found: $GodotPath" }

$logRoot = Join-Path $projectRoot ".tools\network_stage_c_logs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$hostOut = Join-Path $logRoot "${stamp}_host.out.log"
$hostErr = Join-Path $logRoot "${stamp}_host.err.log"
$clientOut = Join-Path $logRoot "${stamp}_client.out.log"
$clientErr = Join-Path $logRoot "${stamp}_client.err.log"
$common = @("--headless", "--path", $projectRoot, "--script", $PeerScript, "--", "--port=$Port")
$hostProcess = Start-Process -FilePath $GodotPath -ArgumentList ($common + "--role=host") -WorkingDirectory $projectRoot -RedirectStandardOutput $hostOut -RedirectStandardError $hostErr -PassThru
Start-Sleep -Milliseconds 350
$clientProcess = Start-Process -FilePath $GodotPath -ArgumentList ($common + "--role=client") -WorkingDirectory $projectRoot -RedirectStandardOutput $clientOut -RedirectStandardError $clientErr -PassThru
$hostCompleted = $hostProcess.WaitForExit($TimeoutMs)
$clientCompleted = $clientProcess.WaitForExit($TimeoutMs)
if (-not $hostCompleted) {
    $hostProcess.Kill()
    $hostProcess.WaitForExit()
} else {
    # With redirected output, the parameterless overload also waits for the
    # asynchronous stream readers and refreshes the final exit state.
    $hostProcess.WaitForExit()
}
if (-not $clientCompleted) {
    $clientProcess.Kill()
    $clientProcess.WaitForExit()
} else {
    $clientProcess.WaitForExit()
}
$hostProcess.Refresh()
$clientProcess.Refresh()
$hostText = (Get-Content -LiteralPath $hostOut -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $hostErr -Raw -ErrorAction SilentlyContinue)
$clientText = (Get-Content -LiteralPath $clientOut -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $clientErr -Raw -ErrorAction SilentlyContinue)
Write-Host $hostText
Write-Host $clientText
$hostPassed = $hostText -match [regex]::Escape($HostMarker)
$clientPassed = $clientText -match [regex]::Escape($ClientMarker)
if (-not $hostCompleted -or -not $clientCompleted -or -not $hostPassed -or -not $clientPassed) {
    throw "$Label test failed (host completed $hostCompleted, client completed $clientCompleted, host marker $hostPassed, client marker $clientPassed). Logs: $logRoot"
}
Write-Host "$Label test passed."
