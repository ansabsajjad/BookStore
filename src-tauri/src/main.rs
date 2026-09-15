// Bookstore Manager — desktop shell.
//
// The window loads the exact same files that Vercel serves, so there is one
// codebase for web and desktop. On launch it quietly asks GitHub Releases
// whether a newer version exists and installs it if so; with no connection the
// check fails silently and the app carries on offline.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri_plugin_updater::UpdaterExt;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .setup(|app| {
            let handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                // Never fatal: a failed check just means we run the version we have.
                if let Err(e) = update(handle).await {
                    eprintln!("update check skipped: {e}");
                }
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("failed to start Bookstore Manager");
}

async fn update(app: tauri::AppHandle) -> tauri_plugin_updater::Result<()> {
    if let Some(update) = app.updater()?.check().await? {
        println!("installing update {}", update.version);
        let mut downloaded = 0;
        update
            .download_and_install(
                |chunk, total| {
                    downloaded += chunk;
                    println!("downloaded {downloaded} of {total:?}");
                },
                || println!("download finished"),
            )
            .await?;
        app.restart();
    }
    Ok(())
}
