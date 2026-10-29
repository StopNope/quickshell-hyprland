#!/usr/bin/env python3
"""
Live Lyrics Fetcher for Quickshell & MediaPopout
Fetches synced lyrics from LRCLIB API with smart caching and title cleaning.
"""
import sys
import os
import re
import json
import hashlib
import urllib.request
import urllib.parse

CACHE_DIR = "/tmp/quickshell_lyrics"
os.makedirs(CACHE_DIR, exist_ok=True)

def clean_title(title):
    if not title:
        return ""
    # Remove (feat. ...), [Official Video], (Remastered 2021), etc.
    t = re.sub(r"[\(\[\{](feat\.|ft\.|with|official|video|audio|remaster|lyric|live)[\s\S]*?[\)\]\}]", "", title, flags=re.IGNORECASE)
    t = re.sub(r"[\(\[\{][\s\S]*?[\)\]\}]", "", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t if t else title.strip()

def clean_artist(artist):
    if not artist:
        return ""
    # Remove "feat.", ", " extra artists
    a = re.split(r",|\s+feat\.|\s+ft\.", artist, flags=re.IGNORECASE)[0]
    return a.strip() if a.strip() else artist.strip()

def parse_lrc(lrc_text):
    lines = []
    # Pattern: [mm:ss.xx] or [mm:ss]
    pattern = re.compile(r"\[(\d{1,2}):(\d{2}(?:\.\d+)?)\](.*)")
    for raw_line in lrc_text.splitlines():
        raw_line = raw_line.strip()
        if not raw_line:
            continue
        m = pattern.match(raw_line)
        if m:
            minutes = int(m.group(1))
            seconds = float(m.group(2))
            total_sec = round(minutes * 60 + seconds, 2)
            text = m.group(3).strip()
            lines.append({"time": total_sec, "text": text})
    return lines

def fetch_from_lrclib(artist, title, duration=None):
    c_art = clean_artist(artist)
    c_tit = clean_title(title)

    # 1. Direct GET
    params = {"artist_name": c_art, "track_name": c_tit}
    if duration and duration > 0:
        params["duration"] = str(int(duration))
    
    url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "Quickshell-Lyrics/1.0"})
    
    try:
        with urllib.request.urlopen(req, timeout=2.5) as r:
            if r.status == 200:
                data = json.loads(r.read().decode("utf-8"))
                if data.get("syncedLyrics"):
                    parsed = parse_lrc(data["syncedLyrics"])
                    if parsed:
                        return {"found": True, "synced": True, "lines": parsed}
                elif data.get("plainLyrics"):
                    raw_lines = [l.strip() for l in data["plainLyrics"].splitlines() if l.strip()]
                    return {"found": True, "synced": False, "lines": [{"time": 0, "text": l} for l in raw_lines]}
    except Exception:
        pass

    # 2. Fallback: Search API
    try:
        q = f"{c_art} {c_tit}".strip()
        search_url = "https://lrclib.net/api/search?" + urllib.parse.urlencode({"q": q})
        req_s = urllib.request.Request(search_url, headers={"User-Agent": "Quickshell-Lyrics/1.0"})
        with urllib.request.urlopen(req_s, timeout=2.5) as r:
            if r.status == 200:
                res_list = json.loads(r.read().decode("utf-8"))
                if isinstance(res_list, list) and len(res_list) > 0:
                    for item in res_list:
                        if item.get("syncedLyrics"):
                            parsed = parse_lrc(item["syncedLyrics"])
                            if parsed:
                                return {"found": True, "synced": True, "lines": parsed}
                    # plain fallback
                    if res_list[0].get("plainLyrics"):
                        raw_lines = [l.strip() for l in res_list[0]["plainLyrics"].splitlines() if l.strip()]
                        return {"found": True, "synced": False, "lines": [{"time": 0, "text": l} for l in raw_lines]}
    except Exception:
        pass

    return {"found": False, "synced": False, "lines": []}

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"found": False, "synced": False, "lines": []}))
        sys.exit(0)

    artist = sys.argv[1].strip()
    title = sys.argv[2].strip()
    duration = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].replace(".", "", 1).isdigit() else 0

    if not title or title == "Музыка не играет":
        print(json.dumps({"found": False, "synced": False, "lines": []}))
        sys.exit(0)

    cache_key = hashlib.md5(f"{artist}_{title}".encode("utf-8")).hexdigest()
    cache_file = os.path.join(CACHE_DIR, f"{cache_key}.json")

    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                if data.get("found"):
                    print(json.dumps(data, ensure_ascii=False))
                    sys.exit(0)
        except Exception:
            pass

    result = fetch_from_lrclib(artist, title, duration)

    if result.get("found"):
        try:
            with open(cache_file, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False)
        except Exception:
            pass

    print(json.dumps(result, ensure_ascii=False))

if __name__ == "__main__":
    main()
