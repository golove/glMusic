use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::RwLock;
use directories::ProjectDirs;
use ncm_api_rs::{create_client, ApiClient, Query};
use serde_json::{json, Value};
use crate::unblock::{match_unblock_url, normalize_url};

pub struct NcmService {
    client: Arc<RwLock<ApiClient>>,
    http: reqwest::Client,
    data_dir: PathBuf,
    cookie: Arc<RwLock<Option<String>>>,
}

impl NcmService {
    pub fn new() -> Self {
        let proj_dirs = ProjectDirs::from("com", "glMusic", "glMusic")
            .unwrap_or_else(|| ProjectDirs::from("com", "glMusic", "glMusic").unwrap());
        let data_dir = proj_dirs.data_dir().to_path_buf();
        let _ = std::fs::create_dir_all(&data_dir);

        let cookie_path = data_dir.join("cookie.txt");
        let initial_cookie = if cookie_path.exists() {
            std::fs::read_to_string(&cookie_path).ok().filter(|s| !s.trim().is_empty())
        } else {
            None
        };

        let client = create_client(initial_cookie.clone());
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(10))
            .build()
            .unwrap_or_default();

        Self {
            client: Arc::new(RwLock::new(client)),
            http,
            data_dir,
            cookie: Arc::new(RwLock::new(initial_cookie)),
        }
    }

    #[allow(dead_code)]
    pub async fn get_cookie(&self) -> Option<String> {
        self.cookie.read().await.clone()
    }

    pub async fn save_cookie(&self, new_cookie: &str) -> Result<(), String> {
        let cookie_path = self.data_dir.join("cookie.txt");
        std::fs::write(&cookie_path, new_cookie).map_err(|e| e.to_string())?;

        let mut cookie_lock = self.cookie.write().await;
        *cookie_lock = Some(new_cookie.to_string());

        let mut client_lock = self.client.write().await;
        *client_lock = create_client(Some(new_cookie.to_string()));
        Ok(())
    }

    pub async fn clear_cookie(&self) -> Result<(), String> {
        let cookie_path = self.data_dir.join("cookie.txt");
        let _ = std::fs::remove_file(cookie_path);

        let mut cookie_lock = self.cookie.write().await;
        *cookie_lock = None;

        let mut client_lock = self.client.write().await;
        *client_lock = create_client(None);
        Ok(())
    }

    pub async fn search(&self, keywords: &str, stype: &str, limit: i64, offset: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("keywords", keywords)
            .param("type", stype)
            .param("limit", &limit.to_string())
            .param("offset", &offset.to_string());
        let resp = client.cloudsearch(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn search_hot_detail(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.search_hot_detail(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn song_detail(&self, ids: &str) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("ids", ids);
        let resp = client.song_detail(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn song_url(&self, id: i64, level: &str) -> Result<Value, String> {
        let client = self.client.read().await;
        let ids_param = format!("[{}]", id);
        let query = Query::new()
            .param("ids", &ids_param)
            .param("level", level);

        let resp_result = client.song_url_v1(&query).await;
        let mut final_url: Option<String> = None;
        let mut resp_body = json!({ "code": 200, "data": [] });

        if let Ok(resp) = resp_result {
            resp_body = resp.body.clone();
            if let Some(data_list) = resp.body.get("data").and_then(|d| d.as_array()) {
                if let Some(first) = data_list.first() {
                    let raw_url = first.get("url").and_then(|u| u.as_str()).unwrap_or("");
                    let free_trial = first.get("freeTrialInfo").is_some() && !first.get("freeTrialInfo").unwrap().is_null();
                    let remain_time = first.get("freeTimeTrialPrivilege")
                        .and_then(|p| p.get("remainTime"))
                        .and_then(|r| r.as_i64())
                        .unwrap_or(0);

                    let is_snippet = (remain_time > 0) || free_trial || raw_url.is_empty();
                    if !is_snippet && !raw_url.is_empty() {
                        final_url = Some(normalize_url(raw_url));
                    }
                }
            }
        }

        // Smart unblock fallback if trial or empty
        if final_url.is_none() {
            if let Some(unblocked) = match_unblock_url(&self.http, id, "320").await {
                final_url = Some(unblocked);
            }
        }

        // Standard song_url fallback
        if final_url.is_none() {
            let fallback_q = Query::new()
                .param("ids", &ids_param)
                .param("br", "320000");
            if let Ok(fallback_resp) = client.song_url(&fallback_q).await {
                if let Some(data_list) = fallback_resp.body.get("data").and_then(|d| d.as_array()) {
                    if let Some(first) = data_list.first() {
                        if let Some(url_str) = first.get("url").and_then(|u| u.as_str()) {
                            if !url_str.is_empty() {
                                final_url = Some(normalize_url(url_str));
                            }
                        }
                    }
                }
            }
        }

        if let Some(url) = final_url {
            Ok(json!({
                "code": 200,
                "data": [{
                    "id": id,
                    "url": url,
                    "level": level
                }]
            }))
        } else {
            Ok(resp_body)
        }
    }

    pub async fn lyric(&self, id: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let id_str = id.to_string();
        let query = Query::new().param("id", &id_str);

        if let Ok(resp) = client.lyric_new(&query).await {
            if resp.status == 200 {
                return Ok(resp.body);
            }
        }

        let resp = client.lyric(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn banner(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("type", "0");
        let resp = client.banner(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn personalized(&self, limit: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("limit", &limit.to_string());
        let resp = client.personalized(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn personalized_newsong(&self, limit: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("limit", &limit.to_string());
        let resp = client.personalized_newsong(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn playlist_detail(&self, id: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("id", &id.to_string());
        let resp = client.playlist_detail(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn playlist_track_all(&self, id: i64, limit: i64, offset: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("id", &id.to_string())
            .param("limit", &limit.to_string())
            .param("offset", &offset.to_string());
        let resp = client.playlist_track_all(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn top_playlist(&self, cat: &str, limit: i64, offset: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("cat", cat)
            .param("limit", &limit.to_string())
            .param("offset", &offset.to_string());
        let resp = client.top_playlist(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn toplist(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.toplist(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn recommend_songs(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.recommend_songs(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn top_artists(&self, limit: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("limit", &limit.to_string());
        let resp = client.top_artists(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn artist_detail(&self, id: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("id", &id.to_string());
        let resp = client.artists(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn artist_album(&self, id: i64, limit: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("id", &id.to_string())
            .param("limit", &limit.to_string());
        let resp = client.artist_album(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn album(&self, id: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("id", &id.to_string());
        let resp = client.album(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn album_new(&self, limit: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("limit", &limit.to_string())
            .param("area", "zh");
        let resp = client.album_new(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn dj_banner(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.dj_banner(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn dj_recommend(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.dj_recommend(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn dj_catelist(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.dj_catelist(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    #[allow(dead_code)]
    pub async fn dj_recommend_type(&self, cate_id: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("cateId", &cate_id.to_string());
        let resp = client.dj_recommend_type(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn dj_detail(&self, rid: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("rid", &rid.to_string());
        let resp = client.dj_detail(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    #[allow(dead_code)]
    pub async fn dj_program(&self, rid: i64, limit: i64, offset: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("rid", &rid.to_string())
            .param("limit", &limit.to_string())
            .param("offset", &offset.to_string());
        let resp = client.dj_program(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn login_qr_key(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.login_qr_key(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn login_qr_create(&self, key: &str) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("key", key)
            .param("qrimg", "true");
        let resp = client.login_qr_create(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn login_qr_check(&self, key: &str) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("key", key);
        let resp = client.login_qr_check(&query).await.map_err(|e| e.to_string())?;

        let code = resp.body.get("code").and_then(|c| c.as_i64()).unwrap_or(0);
        if code == 803 {
            // Login successful, extract cookie
            let cookie_str = if let Some(c) = resp.body.get("cookie").and_then(|c| c.as_str()) {
                c.to_string()
            } else if !resp.cookie.is_empty() {
                resp.cookie.join("; ")
            } else {
                String::new()
            };

            if !cookie_str.is_empty() {
                drop(client);
                let _ = self.save_cookie(&cookie_str).await;
            }
        }

        Ok(resp.body)
    }

    pub async fn login_status(&self) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new();
        let resp = client.login_status(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn like(&self, id: i64, like_bool: bool) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("id", &id.to_string())
            .param("like", if like_bool { "true" } else { "false" });
        let resp = client.like(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn likelist(&self, uid: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new().param("uid", &uid.to_string());
        let resp = client.likelist(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    pub async fn user_playlist(&self, uid: i64, limit: i64, offset: i64) -> Result<Value, String> {
        let client = self.client.read().await;
        let query = Query::new()
            .param("uid", &uid.to_string())
            .param("limit", &limit.to_string())
            .param("offset", &offset.to_string());
        let resp = client.user_playlist(&query).await.map_err(|e| e.to_string())?;
        Ok(resp.body)
    }

    // Local storage helpers
    pub fn get_storage_file(&self, filename: &str) -> PathBuf {
        self.data_dir.join(filename)
    }

    pub fn read_local_data(&self, filename: &str) -> Value {
        let path = self.get_storage_file(filename);
        if path.exists() {
            if let Ok(content) = std::fs::read_to_string(path) {
                if let Ok(val) = serde_json::from_str(&content) {
                    return val;
                }
            }
        }
        json!([])
    }

    pub fn write_local_data(&self, filename: &str, data: &Value) -> Result<(), String> {
        let path = self.get_storage_file(filename);
        let content = serde_json::to_string_pretty(data).map_err(|e| e.to_string())?;
        std::fs::write(path, content).map_err(|e| e.to_string())?;
        Ok(())
    }
}
