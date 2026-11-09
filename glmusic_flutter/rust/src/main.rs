mod ncm;
mod unblock;

use std::sync::Arc;
use std::net::SocketAddr;
use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use tower_http::cors::CorsLayer;
use serde::Deserialize;
use serde_json::{json, Value};
use ncm::NcmService;

type AppState = Arc<NcmService>;

#[derive(Deserialize)]
struct SearchQuery {
    keywords: String,
    stype: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
}

#[derive(Deserialize)]
struct IdQuery {
    id: i64,
}

#[derive(Deserialize)]
struct IdsQuery {
    ids: String,
}

#[derive(Deserialize)]
struct SongUrlQuery {
    id: i64,
    level: Option<String>,
}

#[derive(Deserialize)]
struct LimitQuery {
    limit: Option<i64>,
}

#[derive(Deserialize)]
struct LimitOffsetQuery {
    id: i64,
    limit: Option<i64>,
    offset: Option<i64>,
}

#[derive(Deserialize)]
struct KeyQuery {
    key: String,
}

#[derive(Deserialize)]
struct UidQuery {
    uid: i64,
}

#[derive(Deserialize)]
struct LikeQuery {
    id: i64,
    like: Option<bool>,
}

#[derive(Deserialize)]
struct TopPlaylistQuery {
    cat: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
}

#[derive(Deserialize)]
struct UserPlaylistQuery {
    uid: i64,
    limit: Option<i64>,
    offset: Option<i64>,
}

#[tokio::main]
async fn main() {
    let ncm_service = Arc::new(NcmService::new());

    let app = Router::new()
        // Health check
        .route("/api/ping", get(|| async { Json(json!({ "status": "ok", "version": "0.1.0" })) }))
        // Search
        .route("/api/search", get(handle_search))
        .route("/api/search/hot", get(handle_search_hot))
        // Songs
        .route("/api/song/detail", get(handle_song_detail))
        .route("/api/song/url", get(handle_song_url))
        .route("/api/lyric", get(handle_lyric))
        // Home & Recommendations
        .route("/api/banner", get(handle_banner))
        .route("/api/personalized", get(handle_personalized))
        .route("/api/personalized/newsong", get(handle_personalized_newsong))
        .route("/api/recommend/songs", get(handle_recommend_songs))
        // Playlists & Charts
        .route("/api/playlist/detail", get(handle_playlist_detail))
        .route("/api/playlist/tracks", get(handle_playlist_tracks))
        .route("/api/toplist", get(handle_toplist))
        .route("/api/top/playlist", get(handle_top_playlist))
        .route("/api/top/artists", get(handle_top_artists))
        // Albums & Artists
        .route("/api/album", get(handle_album))
        .route("/api/album/new", get(handle_album_new))
        .route("/api/artist/detail", get(handle_artist_detail))
        .route("/api/artist/album", get(handle_artist_album))
        // DJ Radio
        .route("/api/dj/banner", get(handle_dj_banner))
        .route("/api/dj/recommend", get(handle_dj_recommend))
        .route("/api/dj/catelist", get(handle_dj_catelist))
        .route("/api/dj/detail", get(handle_dj_detail))
        // Login & Auth
        .route("/api/login/qr/key", get(handle_qr_key))
        .route("/api/login/qr/create", get(handle_qr_create))
        .route("/api/login/qr/check", get(handle_qr_check))
        .route("/api/login/status", get(handle_login_status))
        .route("/api/logout", post(handle_logout))
        // Likes & Library
        .route("/api/like", post(handle_like))
        .route("/api/likelist", get(handle_likelist))
        .route("/api/user/playlist", get(handle_user_playlist))
        // Local persistence
        .route("/api/history", get(handle_get_history).post(handle_save_history))
        .route("/api/favorites", get(handle_get_favorites).post(handle_save_favorites))
        .layer(CorsLayer::permissive())
        .with_state(ncm_service);

    let port = std::env::var("PORT").unwrap_or_else(|_| "19980".to_string()).parse::<u16>().unwrap_or(19980);
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    println!("GLMUSIC_CORE_READY port={}", port);

    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind to {}: {}", addr, e);
            // Try port 0 (dynamic available port)
            let fallback_addr = SocketAddr::from(([127, 0, 0, 1], 0));
            let l = tokio::net::TcpListener::bind(fallback_addr).await.expect("Failed to bind fallback port");
            let local_port = l.local_addr().unwrap().port();
            println!("GLMUSIC_CORE_READY port={}", local_port);
            l
        }
    };

    axum::serve(listener, app).await.unwrap();
}

async fn handle_search(
    State(ncm): State<AppState>,
    Query(q): Query<SearchQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let t = q.stype.unwrap_or_else(|| "1".to_string());
    let l = q.limit.unwrap_or(30);
    let o = q.offset.unwrap_or(0);
    ncm.search(&q.keywords, &t, l, o).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_search_hot(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.search_hot_detail().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_song_detail(
    State(ncm): State<AppState>,
    Query(q): Query<IdsQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.song_detail(&q.ids).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_song_url(
    State(ncm): State<AppState>,
    Query(q): Query<SongUrlQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let lvl = q.level.unwrap_or_else(|| "exhigh".to_string());
    ncm.song_url(q.id, &lvl).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_lyric(
    State(ncm): State<AppState>,
    Query(q): Query<IdQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.lyric(q.id).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_banner(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.banner().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_personalized(
    State(ncm): State<AppState>,
    Query(q): Query<LimitQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let l = q.limit.unwrap_or(12);
    ncm.personalized(l).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_personalized_newsong(
    State(ncm): State<AppState>,
    Query(q): Query<LimitQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let l = q.limit.unwrap_or(12);
    ncm.personalized_newsong(l).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_recommend_songs(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.recommend_songs().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_playlist_detail(
    State(ncm): State<AppState>,
    Query(q): Query<IdQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.playlist_detail(q.id).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_playlist_tracks(
    State(ncm): State<AppState>,
    Query(q): Query<LimitOffsetQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let l = q.limit.unwrap_or(50);
    let o = q.offset.unwrap_or(0);
    ncm.playlist_track_all(q.id, l, o).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_toplist(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.toplist().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_album(
    State(ncm): State<AppState>,
    Query(q): Query<IdQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.album(q.id).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_artist_detail(
    State(ncm): State<AppState>,
    Query(q): Query<IdQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.artist_detail(q.id).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_artist_album(
    State(ncm): State<AppState>,
    Query(q): Query<LimitOffsetQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let l = q.limit.unwrap_or(30);
    ncm.artist_album(q.id, l).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_qr_key(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.login_qr_key().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_qr_create(
    State(ncm): State<AppState>,
    Query(q): Query<KeyQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.login_qr_create(&q.key).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_qr_check(
    State(ncm): State<AppState>,
    Query(q): Query<KeyQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.login_qr_check(&q.key).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_login_status(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.login_status().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_logout(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.clear_cookie().await
        .map(|_| Json(json!({"status": "ok"})))
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_like(
    State(ncm): State<AppState>,
    Query(q): Query<LikeQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let lk = q.like.unwrap_or(true);
    ncm.like(q.id, lk).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_likelist(
    State(ncm): State<AppState>,
    Query(q): Query<UidQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.likelist(q.uid).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_get_history(State(ncm): State<AppState>) -> Json<Value> {
    Json(ncm.read_local_data("history.json"))
}

async fn handle_save_history(
    State(ncm): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.write_local_data("history.json", &body)
        .map(|_| Json(json!({"status": "ok"})))
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_get_favorites(State(ncm): State<AppState>) -> Json<Value> {
    Json(ncm.read_local_data("favorites.json"))
}

async fn handle_save_favorites(
    State(ncm): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.write_local_data("favorites.json", &body)
        .map(|_| Json(json!({"status": "ok"})))
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_top_playlist(
    State(ncm): State<AppState>,
    Query(q): Query<TopPlaylistQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let cat = q.cat.unwrap_or_else(|| "全部".to_string());
    let l = q.limit.unwrap_or(30);
    let o = q.offset.unwrap_or(0);
    ncm.top_playlist(&cat, l, o).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_top_artists(
    State(ncm): State<AppState>,
    Query(q): Query<LimitQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let l = q.limit.unwrap_or(30);
    ncm.top_artists(l).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_album_new(
    State(ncm): State<AppState>,
    Query(q): Query<LimitQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let l = q.limit.unwrap_or(30);
    ncm.album_new(l).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_dj_banner(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.dj_banner().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_dj_recommend(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.dj_recommend().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_dj_catelist(State(ncm): State<AppState>) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.dj_catelist().await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_dj_detail(
    State(ncm): State<AppState>,
    Query(q): Query<IdQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    ncm.dj_detail(q.id).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}

async fn handle_user_playlist(
    State(ncm): State<AppState>,
    Query(q): Query<UserPlaylistQuery>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let l = q.limit.unwrap_or(30);
    let o = q.offset.unwrap_or(0);
    ncm.user_playlist(q.uid, l, o).await
        .map(Json)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))
}
