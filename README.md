# Kleiner Hofladen

Ein kleines 3D-Aufbauspiel: Ernten, Regale füllen, kassieren, ausbauen.

## Spielen

Lade unter [Releases](../../releases/latest) die Datei `Kleiner-Hofladen_..._x64-setup.exe` herunter und starte sie.

- Windows zeigt eventuell „Der Computer wurde durch Windows geschützt“. Dann auf **Weitere Informationen** und **Trotzdem ausführen** klicken. Die App ist nicht mit einem kostenpflichtigen Zertifikat signiert.
- Neue Versionen meldet das Spiel beim Start von selbst.
- Die Spielstände liegen in `Dokumente\Kleiner Hofladen`.

## Technik

- Das Spiel ist eine einzelne HTML-Datei mit Three.js. Für die App baut `build.ps1` daraus `web/index.html`.
- Die Windows-App ist eine Hülle aus Rust und [Tauri 2](https://tauri.app) (`src-tauri/`).
- `release.ps1` veröffentlicht eine neue Version als GitHub-Release, mit `latest.json` für die Update-Funktion.
- Drittanbieter-Bausteine in `vendor/`: Three.js r128 (MIT-Lizenz), Schriften Lilita One und Nunito (SIL Open Font License).
