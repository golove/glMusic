use serde_json::Value;

pub async fn match_unblock_url(http_client: &reqwest::Client, id: i64, quality: &str) -> Option<String> {
    let br = if quality.ends_with("000") {
        &quality[..quality.len() - 3]
    } else {
        quality
    };

    let url = format!("https://music-api.gdstudio.xyz/api.php?types=url&id={}&br={}", id, br);

    let resp = http_client
        .get(&url)
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await
        .ok()?;

    if !resp.status().is_success() {
        return None;
    }

    let text = resp.text().await.ok()?;
    let text_trimmed = text.trim();

    if let Ok(json) = serde_json::from_str::<Value>(text_trimmed) {
        if let Some(url_str) = json.get("url").and_then(|v| v.as_str()) {
            if !url_str.is_empty() {
                return Some(normalize_url(url_str));
            }
        }
        if let Some(url_str) = json.get("data").and_then(|v| v.as_str()) {
            if !url_str.is_empty() {
                return Some(normalize_url(url_str));
            }
        }
        if let Some(url_str) = json.get("data").and_then(|d| d.get("url")).and_then(|v| v.as_str()) {
            if !url_str.is_empty() {
                return Some(normalize_url(url_str));
            }
        }
    }

    if text_trimmed.starts_with("http://") || text_trimmed.starts_with("https://") {
        return Some(normalize_url(text_trimmed));
    }

    None
}

pub fn normalize_url(url: &str) -> String {
    let trimmed = url.trim();
    if trimmed.starts_with("http://") {
        if let Ok(parsed) = url::Url::parse(trimmed) {
            if let Some(host) = parsed.host_str() {
                let host_lower = host.to_lowercase();
                if host_lower.ends_with(".music.126.net") || host_lower == "music.126.net" {
                    return trimmed.replace("http://", "https://");
                }
            }
        }
    }
    trimmed.to_string()
}
