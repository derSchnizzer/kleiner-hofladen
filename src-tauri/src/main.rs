// Kleiner Hofladen – Windows-App-Hülle.
// Zeigt das Spiel (web/index.html) in einem eigenen Fenster, speichert Spielstände
// zusätzlich als Dateien in „Dokumente\Kleiner Hofladen“ und holt Updates von GitHub.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::{collections::HashMap, fs, path::PathBuf, thread, time::Duration};
use tauri::{AppHandle, Emitter, Manager, WindowEvent};
use tauri_plugin_updater::UpdaterExt;

fn save_dir(app: &AppHandle) -> Result<PathBuf, String> {
    let dir = app
        .path()
        .document_dir()
        .map_err(|e| e.to_string())?
        .join("Kleiner Hofladen");
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir)
}

fn slot_file(dir: &PathBuf, n: u8) -> PathBuf {
    dir.join(format!("Spielstand {n}.json"))
}

fn check_slot(n: u8) -> Result<(), String> {
    if (1..=3).contains(&n) { Ok(()) } else { Err("ungültiger Slot".into()) }
}

/// Erst in eine Hilfsdatei schreiben, dann umbenennen – so bleibt bei einem Absturz die alte Datei heil.
fn write_safe(path: &PathBuf, text: &str) -> Result<(), String> {
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, text).map_err(|e| e.to_string())?;
    fs::rename(&tmp, path).map_err(|e| e.to_string())
}

#[tauri::command]
fn save_slot(app: AppHandle, n: u8, data: String) -> Result<(), String> {
    check_slot(n)?;
    let dir = save_dir(&app)?;
    write_safe(&slot_file(&dir, n), &data)
}

#[tauri::command]
fn load_slots(app: AppHandle) -> Result<HashMap<String, String>, String> {
    let dir = save_dir(&app)?;
    let mut out = HashMap::new();
    for n in 1..=3u8 {
        if let Ok(text) = fs::read_to_string(slot_file(&dir, n)) {
            out.insert(n.to_string(), text);
        }
    }
    Ok(out)
}

#[tauri::command]
fn delete_slot(app: AppHandle, n: u8) -> Result<(), String> {
    check_slot(n)?;
    let file = slot_file(&save_dir(&app)?, n);
    if file.exists() {
        fs::remove_file(file).map_err(|e| e.to_string())?;
    }
    Ok(())
}

/// „Spielstand als Datei sichern“: landet in Dokumente\Kleiner Hofladen\Sicherungen
#[tauri::command]
fn save_export(app: AppHandle, name: String, text: String) -> Result<String, String> {
    let safe: String = name
        .chars()
        .map(|c| if c.is_alphanumeric() || "-_.".contains(c) { c } else { '_' })
        .collect();
    let dir = save_dir(&app)?.join("Sicherungen");
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let mut path = dir.join(&safe);
    let mut i = 2;
    while path.exists() {
        path = dir.join(safe.replace(".txt", &format!(" ({i}).txt")));
        i += 1;
    }
    write_safe(&path, &text)?;
    Ok(path.to_string_lossy().into_owned())
}

#[tauri::command]
fn app_version(app: AppHandle) -> String {
    app.package_info().version.to_string()
}

#[tauri::command]
fn app_exit(app: AppHandle) {
    app.exit(0);
}

#[derive(serde::Serialize)]
struct UpdateInfo {
    version: String,
}

#[tauri::command]
async fn check_update(app: AppHandle) -> Result<Option<UpdateInfo>, String> {
    let update = app.updater().map_err(|e| e.to_string())?.check().await.map_err(|e| e.to_string())?;
    Ok(update.map(|u| UpdateInfo { version: u.version.clone() }))
}

#[tauri::command]
async fn install_update(app: AppHandle) -> Result<(), String> {
    let update = app
        .updater()
        .map_err(|e| e.to_string())?
        .check()
        .await
        .map_err(|e| e.to_string())?
        .ok_or("Kein Update gefunden")?;
    let mut done: u64 = 0;
    let progress = app.clone();
    update
        .download_and_install(
            move |chunk, total| {
                done += chunk as u64;
                if let Some(t) = total.filter(|t| *t > 0) {
                    let _ = progress.emit("upd-progress", done * 100 / t);
                }
            },
            || {},
        )
        .await
        .map_err(|e| e.to_string())?;
    // Unter Windows beendet sich die App beim Installieren selbst und das Installationsprogramm startet sie neu.
    app.restart();
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_updater::Builder::new().build())
        .invoke_handler(tauri::generate_handler![
            save_slot, load_slots, delete_slot, save_export, app_version, app_exit, check_update, install_update
        ])
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                // Erst das Spiel speichern lassen, dann beenden (spätestens nach 3 Sekunden)
                api.prevent_close();
                let app = window.app_handle().clone();
                if let Some(w) = app.get_webview_window("main") {
                    let _ = w.eval("window.__appClose ? window.__appClose() : window.__TAURI__.core.invoke('app_exit')");
                }
                thread::spawn(move || {
                    thread::sleep(Duration::from_secs(3));
                    app.exit(0);
                });
            }
        })
        .run(tauri::generate_context!())
        .expect("Kleiner Hofladen konnte nicht gestartet werden");
}
