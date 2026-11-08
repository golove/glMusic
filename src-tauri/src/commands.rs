use tauri::State;
use serde_json::Value;
use crate::ncm::NcmService;

#[tauri::command]
pub async fn ncm_search(
    state: State<'_, NcmService>,
    keywords: String,
    stype: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<Value, String> {
    let t = stype.unwrap_or_else(|| "1".to_string());
    let l = limit.unwrap_or(30);
    let o = offset.unwrap_or(0);
    state.search(&keywords, &t, l, o).await
}

#[tauri::command]
pub async fn ncm_search_hot(state: State<'_, NcmService>) -> Result<Value, String> {
    state.search_hot_detail().await
}

#[tauri::command]
pub async fn ncm_song_detail(state: State<'_, NcmService>, ids: String) -> Result<Value, String> {
    state.song_detail(&ids).await
}

#[tauri::command]
pub async fn ncm_song_url(
    state: State<'_, NcmService>,
    id: i64,
    level: Option<String>,
) -> Result<Value, String> {
    let lvl = level.unwrap_or_else(|| "exhigh".to_string());
    state.song_url(id, &lvl).await
}

#[tauri::command]
pub async fn ncm_lyric(state: State<'_, NcmService>, id: i64) -> Result<Value, String> {
    state.lyric(id).await
}

#[tauri::command]
pub async fn ncm_banner(state: State<'_, NcmService>) -> Result<Value, String> {
    state.banner().await
}

#[tauri::command]
pub async fn ncm_personalized(
    state: State<'_, NcmService>,
    limit: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(12);
    state.personalized(l).await
}

#[tauri::command]
pub async fn ncm_personalized_newsong(
    state: State<'_, NcmService>,
    limit: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(12);
    state.personalized_newsong(l).await
}

#[tauri::command]
pub async fn ncm_playlist_detail(state: State<'_, NcmService>, id: i64) -> Result<Value, String> {
    state.playlist_detail(id).await
}

#[tauri::command]
pub async fn ncm_playlist_tracks(
    state: State<'_, NcmService>,
    id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(50);
    let o = offset.unwrap_or(0);
    state.playlist_track_all(id, l, o).await
}

#[tauri::command]
pub async fn ncm_top_playlist(
    state: State<'_, NcmService>,
    cat: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<Value, String> {
    let c = cat.unwrap_or_else(|| "全部".to_string());
    let l = limit.unwrap_or(50);
    let o = offset.unwrap_or(0);
    state.top_playlist(&c, l, o).await
}

#[tauri::command]
pub async fn ncm_toplist(state: State<'_, NcmService>) -> Result<Value, String> {
    state.toplist().await
}

#[tauri::command]
pub async fn ncm_recommend_songs(state: State<'_, NcmService>) -> Result<Value, String> {
    state.recommend_songs().await
}

#[tauri::command]
pub async fn ncm_top_artists(
    state: State<'_, NcmService>,
    limit: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(30);
    state.top_artists(l).await
}

#[tauri::command]
pub async fn ncm_artist_detail(state: State<'_, NcmService>, id: i64) -> Result<Value, String> {
    state.artist_detail(id).await
}

#[tauri::command]
pub async fn ncm_artist_album(
    state: State<'_, NcmService>,
    id: i64,
    limit: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(30);
    state.artist_album(id, l).await
}

#[tauri::command]
pub async fn ncm_album(state: State<'_, NcmService>, id: i64) -> Result<Value, String> {
    state.album(id).await
}

#[tauri::command]
pub async fn ncm_album_new(
    state: State<'_, NcmService>,
    limit: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(30);
    state.album_new(l).await
}

#[tauri::command]
pub async fn ncm_dj_banner(state: State<'_, NcmService>) -> Result<Value, String> {
    state.dj_banner().await
}

#[tauri::command]
pub async fn ncm_dj_recommend(state: State<'_, NcmService>) -> Result<Value, String> {
    state.dj_recommend().await
}

#[tauri::command]
pub async fn ncm_dj_catelist(state: State<'_, NcmService>) -> Result<Value, String> {
    state.dj_catelist().await
}

#[tauri::command]
pub async fn ncm_dj_recommend_type(
    state: State<'_, NcmService>,
    cate_id: i64,
) -> Result<Value, String> {
    state.dj_recommend_type(cate_id).await
}

#[tauri::command]
pub async fn ncm_dj_detail(state: State<'_, NcmService>, rid: i64) -> Result<Value, String> {
    state.dj_detail(rid).await
}

#[tauri::command]
pub async fn ncm_dj_program(
    state: State<'_, NcmService>,
    rid: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(30);
    let o = offset.unwrap_or(0);
    state.dj_program(rid, l, o).await
}

#[tauri::command]
pub async fn ncm_login_qr_key(state: State<'_, NcmService>) -> Result<Value, String> {
    state.login_qr_key().await
}

#[tauri::command]
pub async fn ncm_login_qr_create(state: State<'_, NcmService>, key: String) -> Result<Value, String> {
    state.login_qr_create(&key).await
}

#[tauri::command]
pub async fn ncm_login_qr_check(state: State<'_, NcmService>, key: String) -> Result<Value, String> {
    state.login_qr_check(&key).await
}

#[tauri::command]
pub async fn ncm_login_status(state: State<'_, NcmService>) -> Result<Value, String> {
    state.login_status().await
}

#[tauri::command]
pub async fn ncm_logout(state: State<'_, NcmService>) -> Result<(), String> {
    state.clear_cookie().await
}

#[tauri::command]
pub async fn ncm_like(
    state: State<'_, NcmService>,
    id: i64,
    like: bool,
) -> Result<Value, String> {
    state.like(id, like).await
}

#[tauri::command]
pub async fn ncm_likelist(state: State<'_, NcmService>, uid: i64) -> Result<Value, String> {
    state.likelist(uid).await
}

#[tauri::command]
pub async fn ncm_user_playlist(
    state: State<'_, NcmService>,
    uid: i64,
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<Value, String> {
    let l = limit.unwrap_or(50);
    let o = offset.unwrap_or(0);
    state.user_playlist(uid, l, o).await
}

#[tauri::command]
pub async fn ncm_get_cookie(state: State<'_, NcmService>) -> Result<Option<String>, String> {
    Ok(state.get_cookie().await)
}

#[tauri::command]
pub async fn ncm_save_cookie(state: State<'_, NcmService>, cookie: String) -> Result<(), String> {
    state.save_cookie(&cookie).await
}

#[tauri::command]
pub fn get_local_history(state: State<'_, NcmService>) -> Result<Value, String> {
    Ok(state.read_local_data("history.json"))
}

#[tauri::command]
pub fn save_local_history(state: State<'_, NcmService>, data: Value) -> Result<(), String> {
    state.write_local_data("history.json", &data)
}

#[tauri::command]
pub fn get_local_favorites(state: State<'_, NcmService>) -> Result<Value, String> {
    Ok(state.read_local_data("favorites.json"))
}

#[tauri::command]
pub fn save_local_favorites(state: State<'_, NcmService>, data: Value) -> Result<(), String> {
    state.write_local_data("favorites.json", &data)
}

#[tauri::command]
pub fn window_minimize(window: tauri::Window) -> Result<(), String> {
    window.minimize().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn window_toggle_maximize(window: tauri::Window) -> Result<bool, String> {
    let is_max = window.is_maximized().map_err(|e| e.to_string())?;
    if is_max {
        window.unmaximize().map_err(|e| e.to_string())?;
        Ok(false)
    } else {
        window.maximize().map_err(|e| e.to_string())?;
        Ok(true)
    }
}

#[tauri::command]
pub fn window_close(window: tauri::Window) -> Result<(), String> {
    window.close().map_err(|e| e.to_string())
}

#[tauri::command]
pub fn window_is_maximized(window: tauri::Window) -> Result<bool, String> {
    window.is_maximized().map_err(|e| e.to_string())
}
