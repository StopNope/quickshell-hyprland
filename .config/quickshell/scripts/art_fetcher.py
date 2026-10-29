#!/usr/bin/env python3
import sys
import os
import glob
import hashlib
import urllib.request
import urllib.parse
import json

CACHE_DIR = "/tmp/quickshell_covers"
os.makedirs(CACHE_DIR, exist_ok=True)

artist = sys.argv[1].strip() if len(sys.argv) > 1 else ""
title = sys.argv[2].strip() if len(sys.argv) > 2 else ""

if not title:
    sys.exit(0)

# 1. Проверяем кэш загруженных обложек
cache_key = hashlib.md5(f"{artist}_{title}".encode("utf-8")).hexdigest()
cached_file = os.path.join(CACHE_DIR, f"{cache_key}.jpg")

if os.path.exists(cached_file) and os.path.getsize(cached_file) > 100:
    print(f"file://{cached_file}")
    sys.exit(0)

# 2. Мгновенно проверяем локальный кэш обложек Firefox/Браузера (0 мс, без сети!)
firefox_dir = os.path.expanduser("~/.config/mozilla/firefox/firefox-mpris")
if os.path.isdir(firefox_dir):
    pngs = glob.glob(os.path.join(firefox_dir, "*.png"))
    if pngs:
        latest = max(pngs, key=os.path.getmtime)
        if os.path.getsize(latest) > 100:
            print(f"file://{latest}")
            sys.exit(0)

# 3. Если локальной обложки нет — быстрый поиск в iTunes (с коротким таймаутом 0.8с)
query = f"{artist} {title}".strip()
try:
    url = "https://itunes.apple.com/search?" + urllib.parse.urlencode({"term": query, "entity": "song", "limit": 1})
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=0.8) as r:
        data = json.loads(r.read())
        if data.get("resultCount", 0) > 0:
            art_url = data["results"][0].get("artworkUrl100", "").replace("100x100bb", "600x600bb")
            if art_url:
                urllib.request.urlretrieve(art_url, cached_file)
                print(f"file://{cached_file}")
                sys.exit(0)
except Exception:
    pass
