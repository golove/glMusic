use serde_json::Value;

const NEGATIVE_KEYWORDS: &[&str] = &[
    "翻唱", "cover", "伴奏", "伴奏带", "伴奏版", "ktv", "KTV",
    "片段", "试听", "截取", "剪辑", "原声带",
    "dj", "DJ", "慢摇", "电音", "remix", "Remix",
    "3d", "3D", "环绕", "变速", "变调", "降调", "升调",
    "女声版", "男声版", "儿童版", "纯音乐", "铃声", "抖音",
];

pub fn clean_text(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut in_paren = 0;
    for c in s.chars() {
        match c {
            '(' | '（' | '[' | '【' | '{' | '<' | '《' => in_paren += 1,
            ')' | '）' | ']' | '】' | '}' | '>' | '》' => {
                if in_paren > 0 {
                    in_paren -= 1;
                }
            }
            _ => {
                if in_paren == 0 && (c.is_alphanumeric() || ('\u{4e00}'..='\u{9fa5}').contains(&c)) {
                    for lc in c.to_lowercase() {
                        out.push(lc);
                    }
                }
            }
        }
    }
    out
}

pub fn has_negative_keyword(s: &str) -> bool {
    let lower = s.to_lowercase();
    for kw in NEGATIVE_KEYWORDS {
        if lower.contains(kw) {
            return true;
        }
    }
    false
}

pub fn is_match(
    cand_title: &str,
    cand_artist: &str,
    cand_duration_sec: i64,
    target_title: &str,
    target_artist: &str,
    target_duration_sec: i64,
) -> bool {
    // 1. Negative filter (reject covers, instrumentals, clips, remixes)
    if has_negative_keyword(cand_title) || has_negative_keyword(cand_artist) {
        return false;
    }

    let cand_artist_clean = clean_text(cand_artist);
    let target_artist_clean = clean_text(target_artist);

    // 2. Artist verification
    if !target_artist_clean.is_empty() && !cand_artist_clean.is_empty() {
        if !cand_artist_clean.contains(&target_artist_clean)
            && !target_artist_clean.contains(&cand_artist_clean)
        {
            return false;
        }
    }

    // 3. Title verification
    let cand_title_clean = clean_text(cand_title);
    let target_title_clean = clean_text(target_title);
    if !target_title_clean.is_empty() && !cand_title_clean.is_empty() {
        if cand_title_clean != target_title_clean
            && !cand_title_clean.starts_with(&target_title_clean)
            && !target_title_clean.starts_with(&cand_title_clean)
        {
            return false;
        }
    }

    // 4. Duration verification (within 12 seconds tolerance)
    if target_duration_sec > 0 && cand_duration_sec > 0 {
        let diff = (cand_duration_sec - target_duration_sec).abs();
        if diff > 12 {
            return false;
        }
    }

    true
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

pub async fn resolve_kuwo_rid(http_client: &reqwest::Client, rid: &str, quality: &str) -> Option<String> {
    let br = match quality {
        "flac" | "lossless" | "hires" => "2000kflac",
        "128" | "128000" | "standard" => "128kmp3",
        _ => "320kmp3",
    };
    let clean_rid = rid.trim_start_matches("MUSIC_");

    // Primary Kuwo mobile APK conversion API
    let url = format!(
        "http://nmobi.kuwo.cn/mobi.s?f=web&user=0&source=kwplayerhd_ar_1.1.4.5_tianbao_T1A_qirui.apk&type=convert_url_with_sign&rid={clean_rid}&br={br}"
    );

    if let Ok(resp) = http_client
        .get(&url)
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        .timeout(std::time::Duration::from_secs(4))
        .send()
        .await
    {
        if resp.status().is_success() {
            if let Ok(val) = resp.json::<Value>().await {
                if val.get("code").and_then(|c| c.as_i64()) == Some(200) {
                    if let Some(play_url) = val.get("data").and_then(|d| d.get("url")).and_then(|u| u.as_str()) {
                        if !play_url.is_empty() && (play_url.starts_with("http://") || play_url.starts_with("https://")) {
                            return Some(normalize_url(play_url));
                        }
                    }
                }
            }
        }
    }

    // Secondary Kuwo anti.s conversion API
    let legacy_url = format!(
        "http://antiserver.kuwo.cn/anti.s?type=convert_url&rid=MUSIC_{clean_rid}&format=mp3&response=url"
    );
    if let Ok(lresp) = http_client
        .get(&legacy_url)
        .header("User-Agent", "Mozilla/5.0")
        .timeout(std::time::Duration::from_secs(3))
        .send()
        .await
    {
        if lresp.status().is_success() {
            if let Ok(text) = lresp.text().await {
                let trimmed = text.trim();
                if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
                    return Some(normalize_url(trimmed));
                }
            }
        }
    }

    // Tertiary ikun conversion API
    let q = match quality {
        "flac" | "lossless" | "hires" => "flac",
        "128" | "128000" | "standard" => "128k",
        _ => "320k",
    };
    let body = serde_json::json!({
        "source": "kw",
        "musicId": clean_rid,
        "quality": q
    });
    if let Ok(iresp) = http_client
        .post("https://c.wwwweb.top/music/url")
        .header("Content-Type", "application/json")
        .header("User-Agent", "Mozilla/5.0")
        .json(&body)
        .timeout(std::time::Duration::from_secs(4))
        .send()
        .await
    {
        if let Ok(val) = iresp.json::<Value>().await {
            if val.get("code").and_then(|c| c.as_i64()) == Some(200) {
                if let Some(u) = val.get("url").and_then(|v| v.as_str()) {
                    if !u.is_empty() && (u.starts_with("http://") || u.starts_with("https://")) {
                        return Some(normalize_url(u));
                    }
                }
            }
        }
    }

    None
}

async fn try_match_oiapi(
    http_client: &reqwest::Client,
    title: &str,
    artist: &str,
    expected_duration_sec: i64,
    quality: &str,
) -> Option<String> {
    let kw = format!("{title} {artist}").trim().to_string();
    let encoded_kw = urlencoding::encode(&kw);

    let br = match quality {
        "flac" | "lossless" | "hires" => "1", // flac
        "128" | "128000" | "standard" => "7", // mp3 128k
        _ => "5",                             // mp3 320k
    };

    for n in 1..=5 {
        let api_url = format!("https://oiapi.net/api/Kuwo?msg={encoded_kw}&n={n}&br={br}");
        let Ok(resp) = http_client
            .get(&api_url)
            .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            .timeout(std::time::Duration::from_secs(4))
            .send()
            .await
        else {
            continue;
        };

        if !resp.status().is_success() {
            continue;
        }

        let Ok(json) = resp.json::<Value>().await else {
            continue;
        };

        let data = json.get("data");
        if data.is_none() || data.unwrap().is_null() {
            continue;
        }
        let data = data.unwrap();

        let cand_song = data.get("song").and_then(|v| v.as_str()).unwrap_or_default();
        let cand_singer = data.get("singer").and_then(|v| v.as_str()).unwrap_or_default();
        let cand_time: i64 = data
            .get("time")
            .and_then(|v| {
                if let Some(num) = v.as_i64() {
                    Some(num)
                } else if let Some(s) = v.as_str() {
                    s.parse::<i64>().ok()
                } else {
                    None
                }
            })
            .unwrap_or(0);

        if is_match(cand_song, cand_singer, cand_time, title, artist, expected_duration_sec) {
            // Priority 1: resolve genuine studio track via rid with requested quality (320k / flac)
            let rid_val = data.get("id").or_else(|| data.get("rid"));
            if let Some(rid_str) = rid_val.and_then(|v| {
                if let Some(num) = v.as_i64() {
                    Some(num.to_string())
                } else if let Some(s) = v.as_str() {
                    Some(s.to_string())
                } else {
                    None
                }
            }) {
                if let Some(resolved) = resolve_kuwo_rid(http_client, &rid_str, quality).await {
                    return Some(resolved);
                }
            }

            // Priority 2: direct audio stream url provided by oiapi
            if let Some(direct_url) = data.get("url").and_then(|v| v.as_str()) {
                if !direct_url.is_empty()
                    && (direct_url.starts_with("http://") || direct_url.starts_with("https://"))
                {
                    return Some(normalize_url(direct_url));
                }
            }
        }
    }

    None
}

async fn try_match_kuwo_search(
    http_client: &reqwest::Client,
    title: &str,
    artist: &str,
    expected_duration_sec: i64,
    quality: &str,
) -> Option<String> {
    let kw = format!("{title} {artist}").trim().to_string();
    let encoded_kw = urlencoding::encode(&kw);
    let search_url = format!(
        "http://search.kuwo.cn/r.s?client=kt&all={encoded_kw}&pn=0&rn=12&ft=music&encoding=utf8&rformat=json"
    );

    let Ok(resp) = http_client
        .get(&search_url)
        .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        .timeout(std::time::Duration::from_secs(4))
        .send()
        .await
    else {
        return None;
    };

    let Ok(text) = resp.text().await else {
        return None;
    };

    let fixed_json = text
        .replace('\'', "\"")
        .replace("&nbsp;", " ")
        .replace("&apos;", "'");

    let Ok(json) = serde_json::from_str::<Value>(&fixed_json) else {
        return None;
    };

    let Some(abslist) = json.get("abslist").and_then(|a| a.as_array()) else {
        return None;
    };

    for item in abslist {
        let cand_song = item.get("SONGNAME").and_then(|v| v.as_str()).unwrap_or_default();
        let cand_singer = item.get("ARTIST").and_then(|v| v.as_str()).unwrap_or_default();
        let cand_time: i64 = item
            .get("DURATION")
            .and_then(|v| {
                if let Some(num) = v.as_i64() {
                    Some(num)
                } else if let Some(s) = v.as_str() {
                    s.parse::<i64>().ok()
                } else {
                    None
                }
            })
            .unwrap_or(0);

        if is_match(cand_song, cand_singer, cand_time, title, artist, expected_duration_sec) {
            let rid = item.get("MUSICRID").and_then(|v| v.as_str()).unwrap_or_default();
            if !rid.is_empty() {
                if let Some(url) = resolve_kuwo_rid(http_client, rid, quality).await {
                    return Some(url);
                }
            }
        }
    }

    None
}

async fn try_match_outer_cdn(http_client: &reqwest::Client, id: i64) -> Option<String> {
    let outer_url = format!("https://music.163.com/song/media/outer/url?id={id}.mp3");
    let resp = http_client
        .head(&outer_url)
        .header("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")
        .send()
        .await
        .ok()?;

    let final_url = resp.url().as_str();
    if !final_url.contains("/404") && resp.status().is_success() {
        return Some(normalize_url(final_url));
    }
    None
}

async fn try_match_gdstudio(http_client: &reqwest::Client, id: i64, quality: &str) -> Option<String> {
    let br = if quality.ends_with("000") {
        &quality[..quality.len() - 3]
    } else {
        quality
    };

    let url = format!("https://music-api.gdstudio.xyz/api.php?types=url&id={id}&br={br}");
    let resp = http_client
        .get(&url)
        .header(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        )
        .timeout(std::time::Duration::from_secs(3))
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
    }

    None
}

/// Match clean, authentic, original-artist audio stream for VIP / copyright restricted songs.
/// Eliminates cover versions, karaoke accompaniments, DJ remixes, and partial clips.
pub async fn match_unblock_url(
    http_client: &reqwest::Client,
    id: i64,
    title: &str,
    artist: &str,
    expected_duration_sec: i64,
    quality: &str,
) -> Option<String> {
    // 1. Precision match via high-quality multi-source resolver (oiapi.net + anti-cover + duration check)
    if !title.is_empty() {
        if let Some(url) = try_match_oiapi(http_client, title, artist, expected_duration_sec, quality).await {
            return Some(url);
        }
    }

    // 2. Direct search match on Kuwo with strict anti-cover filter
    if !title.is_empty() {
        if let Some(url) = try_match_kuwo_search(http_client, title, artist, expected_duration_sec, quality).await {
            return Some(url);
        }
    }

    // 3. Check official NetEase outer CDN 302 redirect
    if let Some(url) = try_match_outer_cdn(http_client, id).await {
        return Some(url);
    }

    // 4. GDStudio direct fallback (if responsive)
    if let Some(url) = try_match_gdstudio(http_client, id, quality).await {
        return Some(url);
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clean_text() {
        assert_eq!(clean_text("晴天 (Live)"), "晴天");
        assert_eq!(clean_text("晴天（吉他弹唱）"), "晴天");
        assert_eq!(clean_text("孤勇者-《英雄联盟：双城之战》主题曲"), "孤勇者主题曲");
        assert_eq!(clean_text("G.E.M.邓紫棋"), "gem邓紫棋");
    }

    #[test]
    fn test_negative_keywords() {
        assert!(has_negative_keyword("晴天 (KTV版伴奏)"));
        assert!(has_negative_keyword("晴天（吉他弹唱）Cover 周杰伦 Jay"));
        assert!(has_negative_keyword("晴天 (片段)"));
        assert!(has_negative_keyword("晴天 (DJ版)"));
        assert!(!has_negative_keyword("晴天"));
    }

    #[test]
    fn test_matching_logic() {
        // Authentic match
        assert!(is_match("晴天", "周杰伦", 269, "晴天", "周杰伦", 269));
        // Reject cover singer
        assert!(!is_match("晴天", "暂停白昼", 261, "晴天", "周杰伦", 269));
        // Reject KTV
        assert!(!is_match("晴天 (KTV版伴奏)", "周杰伦", 269, "晴天", "周杰伦", 269));
        // Reject clip (duration diff 240s)
        assert!(!is_match("晴天", "周杰伦", 25, "晴天", "周杰伦", 269));
    }

    #[tokio::test]
    async fn test_vip_unblock_live() {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(10))
            .build()
            .unwrap();

        let list = [
            (186016, "晴天", "周杰伦", 269),
            (108242, "美人鱼", "林俊杰", 254),
            (168091, "蓝莲花", "许巍", 270),
            (29775505, "尘埃", "王菲", 301),
            (1901371647, "孤勇者", "陈奕迅", 256),
        ];

        for (id, title, artist, dur) in list {
            println!("Testing unblock for {title} - {artist} ({id})...");
            let res = match_unblock_url(&client, id, title, artist, dur, "320").await;
            assert!(res.is_some(), "Failed to unblock {title} - {artist}");
            let url = res.unwrap();
            println!("✅ Unblocked {title}: {url}");
            assert!(url.starts_with("http"), "Invalid URL: {url}");
        }
    }
}
