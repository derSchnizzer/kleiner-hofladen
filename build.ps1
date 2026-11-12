# Baut die Windows-App "Kleiner Hofladen".
# 1) Spieldatei offline-fähig nach web\ kopieren (Three.js und Schriften lokal)
# 2) App + Installationsprogramm bauen und für Updates unterschreiben
# Ergebnis: dist\Kleiner-Hofladen_<Version>_x64-setup.exe (+ .sig)
param(
  [string]$Source = "E:\Kleiner Hofladen\Kleiner-Hofladen.html",
  [string]$KeyFile = "E:\Kleiner Hofladen\SCHLUESSEL\updater.key",
  [string]$Previous = "",   # leer = neueste Datei in E:\Kleiner Hofladen\Sicherungen (Kleiner-Hofladen-vN.html)
  [switch]$NoBundle
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding $false

# --- 1) Spiel vorbereiten ---
function Make-Offline([string]$text, [string]$prefix) {
  $text = $text.Replace('<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>', "<script src=""${prefix}three.min.js""></script>")
  $text = [regex]::Replace($text, '<link rel="preconnect"[^>]*>\r?\n?', '')
  $text = $text.Replace('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@600;700;800&display=swap">', "<link rel=""stylesheet"" href=""${prefix}fonts/fonts.css"">")
  if ($text -match 'https://(cdnjs|fonts\.g)') { throw "Im Spiel stehen noch Internet-Adressen für Three.js oder Schriften." }
  if ($text -notmatch "APP = \(window\.__TAURI__") { throw "Die Spieldatei hat noch keine App-Anbindung (ab Spiel-Version 12)." }
  return $text
}
$html = Make-Offline ([IO.File]::ReadAllText($Source, $utf8)) ''
Remove-Item -Recurse -Force "$root\web" -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$root\web\fonts" | Out-Null

# Vorherige Version mitliefern (Startmenü: „Vorherige Version starten“), falls etwas mit einem Update nicht stimmt
if (-not $Previous) {
  $Previous = Get-ChildItem "E:\Kleiner Hofladen\Sicherungen" -Filter "Kleiner-Hofladen-v*.html" -ErrorAction SilentlyContinue |
    Sort-Object { [int]([regex]::Match($_.Name, 'v(\d+)').Groups[1].Value) } | Select-Object -Last 1 | ForEach-Object FullName
}
$prevVer = $null
if ($Previous -and (Test-Path $Previous)) {
  $prevVer = [regex]::Match([IO.Path]::GetFileName($Previous), 'v(\d+)').Groups[1].Value
  $old = [IO.File]::ReadAllText($Previous, $utf8)
  if ($old -match "APP = \(window\.__TAURI__") {
    $old = Make-Offline $old '../'
    $banner = "<div style=""position:fixed;left:50%;bottom:10px;transform:translateX(-50%);z-index:99;background:#e8505b;color:#fff;padding:7px 14px;border-radius:12px;font:700 14px/1.2 sans-serif;box-shadow:0 3px 0 rgba(0,0,0,.25)"">Ältere Spiel-Version $prevVer &middot; <a href=""../index.html"" style=""color:#fff"">zurück zur aktuellen Version</a></div>"
    $old = $old.Insert($old.IndexOf('<body>') + 6, $banner)
    New-Item -ItemType Directory -Force "$root\web\vorher" | Out-Null
    [IO.File]::WriteAllText("$root\web\vorher\index.html", $old, $utf8)
    if ($html -notmatch 'const PREV_VERSION = null;') { Write-Host "Hinweis: Spiel kennt PREV_VERSION noch nicht – Knopf erscheint nicht." }
    $html = $html.Replace('const PREV_VERSION = null;', "const PREV_VERSION = ""$prevVer"";")
    Write-Host "Vorherige Version $prevVer mitgeliefert: web\vorher\index.html"
  } else { Write-Host "Vorherige Version $prevVer hat keine App-Anbindung – wird nicht mitgeliefert." }
}
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
Copy-Item "$root\dist\$name" "E:\Kleiner Hofladen\Kleiner-Hofladen-Setup.exe" -Force   # zum Verschicken
Write-Host "Fertig: dist\$name (auch als E:\Kleiner Hofladen\Kleiner-Hofladen-Setup.exe)"
