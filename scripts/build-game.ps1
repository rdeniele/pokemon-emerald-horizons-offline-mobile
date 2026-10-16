param([switch]$WebOnly,[switch]$AndroidOnly)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$engine = Join-Path (Get-Location) 'tools/godot/Godot_v4.7.1-stable_win64_console.exe'
if (!(Test-Path $engine)) { throw 'Missing portable Godot 4.7.1. See README.md.' }
New-Item -ItemType Directory -Force public/game,build/apk,reference/prototype | Out-Null
node scripts/adapt-prototype.mjs
if ($LASTEXITCODE -ne 0) { throw 'Mobile adaptation failed.' }
& $engine --headless --editor --path game --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
if (!$AndroidOnly) {
  & $engine --headless --path game --export-release Web '../public/game/index.html'
  if ($LASTEXITCODE -ne 0) { throw 'Web export failed.' }
}
if (!$WebOnly) {
  & $engine --headless --path game --export-debug Android '../build/apk/pokemon-prototype-mobile.apk'
  if ($LASTEXITCODE -ne 0) { throw 'Android export failed.' }
}
