Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$command = Get-Command godot -ErrorAction SilentlyContinue
if (-not $command) { $command = Get-Command godot_console -ErrorAction SilentlyContinue }
if (-not $command) {
    $packageRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $command = Get-ChildItem -LiteralPath $packageRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -Like "GodotEngine.GodotEngine_*" |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter "Godot*.exe" } |
        Where-Object Name -NotLike "*_console.exe" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}
if (-not $command) { throw "Godot 4 not found. Install GodotEngine.GodotEngine with winget." }
$godotPath = if ($command -is [System.IO.FileInfo]) { $command.FullName } else { $command.Source }
& $godotPath --path $projectRoot
