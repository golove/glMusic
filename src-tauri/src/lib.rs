pub mod ncm;
pub mod unblock;
pub mod commands;

use ncm::NcmService;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let ncm_service = NcmService::new();

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(ncm_service)
        .invoke_handler(tauri::generate_handler![
            commands::ncm_search,
            commands::ncm_search_hot,
            commands::ncm_song_detail,
            commands::ncm_song_url,
            commands::ncm_lyric,
            commands::ncm_banner,
            commands::ncm_personalized,
            commands::ncm_personalized_newsong,
            commands::ncm_playlist_detail,
            commands::ncm_playlist_tracks,
            commands::ncm_top_playlist,
            commands::ncm_toplist,
            commands::ncm_recommend_songs,
            commands::ncm_top_artists,
            commands::ncm_artist_detail,
            commands::ncm_artist_album,
            commands::ncm_album,
            commands::ncm_album_new,
            commands::ncm_dj_banner,
            commands::ncm_dj_recommend,
            commands::ncm_dj_catelist,
            commands::ncm_dj_recommend_type,
            commands::ncm_dj_detail,
            commands::ncm_dj_program,
            commands::ncm_login_qr_key,
            commands::ncm_login_qr_create,
            commands::ncm_login_qr_check,
            commands::ncm_login_status,
            commands::ncm_logout,
            commands::ncm_like,
            commands::ncm_likelist,
            commands::ncm_user_playlist,
            commands::ncm_get_cookie,
            commands::ncm_save_cookie,
            commands::get_local_history,
            commands::save_local_history,
            commands::get_local_favorites,
            commands::save_local_favorites
        ])
        .run(tauri::generate_context!())
        .expect("error while running glmusic tauri application");
}
