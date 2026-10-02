#
# Command Code RTL fix - Windows installer (PowerShell 5+).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1
#   $env:COMMAND_CODE_APP = "C:\path\to\resources\app"   # optional override
#
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$Src = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Assets = Join-Path $Src "assets"

function Fail($msg) { Write-Error $msg; exit 1 }

# --- locate the app ---------------------------------------------------------
$candidates = @()
if ($env:COMMAND_CODE_APP) { $candidates += $env:COMMAND_CODE_APP }
if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA "Programs\Command Code\resources\app") }
if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "Command Code\resources\app") }
if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} "Command Code\resources\app") }

$appDir = $null
foreach ($c in $candidates) {
	if ($c -and (Test-Path (Join-Path $c "out\renderer\index.html"))) { $appDir = $c; break }
}

if (-not $appDir) {
	Fail "Could not find an unpacked Command Code install. Set `$env:COMMAND_CODE_APP to ...\resources\app."
}
if (Test-Path (Join-Path $appDir "app.asar")) {
	Fail "This install is packaged as app.asar. Extract it first (see README) or use an unpacked build."
}

$renderer = Join-Path $appDir "out\renderer"
$index = Join-Path $renderer "index.html"
$bak = Join-Path $renderer ".index.html.rtl-fix.bak"

# --- back up, copy, inject --------------------------------------------------
if (-not (Test-Path $bak)) { Copy-Item -LiteralPath $index -Destination $bak }
Copy-Item -LiteralPath (Join-Path $Assets "rtl-fix.css") -Destination (Join-Path $renderer "rtl-fix.css") -Force
Copy-Item -LiteralPath (Join-Path $Assets "rtl-fix.js") -Destination (Join-Path $renderer "rtl-fix.js") -Force
$fontsDir = Join-Path $renderer "fonts"
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
Copy-Item -LiteralPath (Join-Path $Assets "fonts\rtl-fix-font.woff2") -Destination (Join-Path $fontsDir "rtl-fix-font.woff2") -Force

$html = Get-Content -LiteralPath $index -Raw
if ($html -notmatch "\./rtl-fix\.css") {
	$html = $html -replace "</head>", "<link rel=`"stylesheet`" href=`"./rtl-fix.css`" />`r`n</head>"
}
if ($html -notmatch "\./rtl-fix\.js") {
	$html = $html -replace "</body>", "<script src=`"./rtl-fix.js`"></script>`r`n</body>"
}
Set-Content -LiteralPath $index -Value $html -NoNewline -Encoding UTF8

Write-Host ""
Write-Host "RTL fix installed into: $renderer"
Write-Host "Fully quit Command Code and open it again."
Write-Host "An update replaces the renderer, so re-run this script after updating."
