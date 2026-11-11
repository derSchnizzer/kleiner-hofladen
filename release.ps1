# Veröffentlicht die gebaute Version als Update auf GitHub.
# Vorher: build.ps1 ausführen. Danach finden alle installierten Apps das Update beim nächsten Start.
param([string]$Notes = "Neue Version von Kleiner Hofladen")
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding $false
$conf = Get-Content "$root\src-tauri\tauri.conf.json" -Raw | ConvertFrom-Json
$v = $conf.version
$endpoint = $conf.plugins.updater.endpoints[0]
if ($endpoint -notmatch 'github\.com/([^/]+)/([^/]+)/releases') { throw "Update-Adresse in tauri.conf.json ist nicht gesetzt: $endpoint" }
$repo = "$($Matches[1])/$($Matches[2])"
$name = "Kleiner-Hofladen_${v}_x64-setup.exe"
$exe = "$root\dist\$name"
if (-not (Test-Path $exe) -or -not (Test-Path "$exe.sig")) { throw "Erst build.ps1 ausführen – $name fehlt in dist\" }

$latest = [ordered]@{
  version  = $v
  notes    = $Notes
  pub_date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  platforms = [ordered]@{
    'windows-x86_64' = [ordered]@{
      signature = (Get-Content "$exe.sig" -Raw).Trim()
      url       = "https://github.com/$repo/releases/download/v$v/$name"
    }
  }
}
[IO.File]::WriteAllText("$root\dist\latest.json", ($latest | ConvertTo-Json -Depth 5), $utf8)

$env:PATH = "$env:ProgramFiles\GitHub CLI;$env:PATH"
gh release create "v$v" "$exe" "$root\dist\latest.json" --repo $repo --title "Version $v" --notes $Notes
if ($LASTEXITCODE -ne 0) { throw "Hochladen fehlgeschlagen" }
Write-Host "Veröffentlicht: https://github.com/$repo/releases/tag/v$v"
