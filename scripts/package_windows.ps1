$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotExe = Join-Path $projectRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$releaseTemplate = Join-Path $projectRoot ".tools\godot-4.7.2\editor_data\export_templates\4.7.2.stable\windows_release_x86_64.exe"
$outputDir = Join-Path $projectRoot "dist\BrawlDemo-v0.4.3"
$outputExe = Join-Path $outputDir "BrawlDemo.exe"
$outputPck = Join-Path $outputDir "BrawlDemo.pck"
$guideSource = Join-Path $projectRoot "PLAYTEST_README_zh-CN.txt"
$guideTarget = Join-Path $outputDir "README_zh-CN.txt"
$archivePath = Join-Path $projectRoot "dist\BrawlDemo-v0.4.3-windows-x86_64.zip"

if (-not (Test-Path -LiteralPath $godotExe)) {
    throw "Godot executable not found: $godotExe"
}
if (-not (Test-Path -LiteralPath $releaseTemplate)) {
    throw "Godot 4.7.2 Windows export template not found: $releaseTemplate"
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
& $godotExe --headless --path $projectRoot --export-release "Windows Desktop" $outputExe
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $outputExe)) {
    throw "Godot reported success but did not create $outputExe"
}

Copy-Item -LiteralPath $guideSource -Destination $guideTarget -Force
$packagePaths = @($outputExe, $outputPck, $guideTarget)
Compress-Archive -LiteralPath $packagePaths -DestinationPath $archivePath -CompressionLevel Optimal -Force

$packageFiles = Get-Item -LiteralPath $packagePaths
$packageSize = ($packageFiles | Measure-Object -Property Length -Sum).Sum
Write-Host "Windows playtest package created:"
Write-Host "  Folder:  $outputDir"
Write-Host "  Archive: $archivePath"
Write-Host ("  Files:   {0}, unpacked size: {1:N1} MB" -f $packageFiles.Count, ($packageSize / 1MB))
