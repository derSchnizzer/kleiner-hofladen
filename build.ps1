# Baut die Windows-App "Kleiner Hofladen".
# 1) Spieldatei offline-fähig nach web\ kopieren (Three.js und Schriften lokal)
# 2) App + Installationsprogramm bauen und für Updates unterschreiben
# Ergebnis: dist\Kleiner-Hofladen_<Version>_x64-setup.exe (+ .sig)
param(
  [string]$Source = "E:\Firefox Downloads\Kleiner-Hofladen.html",
  [string]$KeyFile = "E:\Firefox Downloads\hofladen-app-SCHLUESSEL\updater.key",
  [switch]$NoBundle
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding $false

# --- 1) Spiel vorbereiten ---
$html = [IO.File]::ReadAllText($Source, $utf8)
$html = $html.Replace('<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>', '<script src="three.min.js"></script>')
$html = [regex]::Replace($html, '<link rel="preconnect"[^>]*>\r?\n?', '')
$html = $html.Replace('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@600;700;800&display=swap">', '<link rel="stylesheet" href="fonts/fonts.css">')
if ($html -match 'https://(cdnjs|fonts\.g)') { throw "Im Spiel stehen noch Internet-Adressen für Three.js oder Schriften." }
if ($html -notmatch "APP = \(window\.__TAURI__") { throw "Die Spieldatei hat noch keine App-Anbindung (ab Spiel-Version 12)." }
Remove-Item -Recurse -Force "$root\web" -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$root\web\fonts" | Out-Null
[IO.File]::WriteAllText("$root\web\index.html", $html, $utf8)
Copy-Item "$root\vendor\three.min.js" "$root\web\"
Copy-Item "$root\vendor\fonts.css", "$root\vendor\*.woff2" "$root\web\fonts\"
Write-Host "Spiel vorbereitet: web\index.html"

# --- 2) Bauen ---
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
$ErrorActionPreference = 'Continue'   # cargo schreibt Fortschritt nach stderr, das ist kein Fehler
Push-Location "$root\src-tauri"
try {
  if ($NoBundle) {
    cargo tauri build --no-bundle
  } else {
    if (-not (Test-Path $KeyFile)) { throw "Update-Schlüssel fehlt: $KeyFile" }
    $env:TAURI_SIGNING_PRIVATE_KEY = (Get-Content $KeyFile -Raw).Trim()
    $env:TAURI_SIGNING_PRIVATE_KEY_PASSWORD = ""
    cargo tauri build
  }
  if ($LASTEXITCODE -ne 0) { throw "Bauen fehlgeschlagen (Code $LASTEXITCODE)" }
} finally {
  Remove-Item Env:TAURI_SIGNING_PRIVATE_KEY -ErrorAction SilentlyContinue
  Pop-Location
}
if ($NoBundle) { Write-Host "Fertig (nur exe): src-tauri\target\release\Kleiner-Hofladen.exe"; return }

# --- 3) Ergebnis mit Namen ohne Leerzeichen nach dist\ ---
$conf = Get-Content "$root\src-tauri\tauri.conf.json" -Raw | ConvertFrom-Json
$v = $conf.version
$nsis = "$root\src-tauri\target\release\bundle\nsis"
$setup = Get-ChildItem $nsis -Filter "*_${v}_x64-setup.exe" | Select-Object -First 1
if (-not $setup) { throw "Installationsprogramm nicht gefunden in $nsis" }
New-Item -ItemType Directory -Force "$root\dist" | Out-Null
$name = "Kleiner-Hofladen_${v}_x64-setup.exe"
Copy-Item $setup.FullName "$root\dist\$name" -Force
Copy-Item "$($setup.FullName).sig" "$root\dist\$name.sig" -Force
Write-Host "Fertig: dist\$name"
