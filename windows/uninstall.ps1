#
# Command Code RTL fix - Windows uninstaller (restores the original renderer).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File uninstall.ps1
#
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Error $msg; exit 1 }

$candidates = @()
if ($env:COMMAND_CODE_APP) { $candidates += $env:COMMAND_CODE_APP }
if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA "Programs\Command Code\resources\app") }
if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "Command Code\resources\app") }
if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} "Command Code\resources\app") }

$appDir = $null
foreach ($c in $candidates) {
	if ($c -and (Test-Path (Join-Path $c "out\renderer\index.html"))) { $appDir = $c; break }
}

if (-not $appDir) { Fail "Could not find the Command Code install." }

$renderer = Join-Path $appDir "out\renderer"
$index = Join-Path $renderer "index.html"
$bak = Join-Path $renderer ".index.html.rtl-fix.bak"

if (Test-Path $bak) {
	Copy-Item -LiteralPath $bak -Destination $index -Force
	Remove-Item -LiteralPath $bak -Force
}
foreach ($f in @("rtl-fix.css", "rtl-fix.js")) {
	$p = Join-Path $renderer $f
	if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
}
$font = Join-Path $renderer "fonts\rtl-fix-font.woff2"
if (Test-Path $font) { Remove-Item -LiteralPath $font -Force }
$fontsDir = Join-Path $renderer "fonts"
if ((Test-Path $fontsDir) -and -not (Get-ChildItem -LiteralPath $fontsDir -Force)) {
	Remove-Item -LiteralPath $fontsDir -Force
}

Write-Host "RTL fix removed from: $renderer"
Write-Host "Restart Command Code."
