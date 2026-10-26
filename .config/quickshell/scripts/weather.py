#!/usr/bin/env bash
#!/usr/bin/env python3
import sys
import json
import urllib.request
import urllib.parse

def get_location():
    try:
        req = urllib.request.Request("http://ip-api.com/json/?lang=ru", headers={"User-Agent": "curl/7.68.0"})
        with urllib.request.urlopen(req, timeout=3) as res:
            data = json.loads(res.read().decode())
            if data.get("status") == "success":
                city_ru = data.get("city")
                if city_ru:
                    return city_ru
    except Exception:
        pass
    return None

def get_icon(desc):
    d = (desc or "").lower()
    if any(w in d for w in ["ясно", "солнечн", "clear", "sunny"]):
        return "󰖙"
    if any(w in d for w in ["гроз", "молни", "thunder"]):
        return "󰖓"
    if any(w in d for w in ["снег", "метел", "буран", "snow"]):
        return "󰖘"
    if any(w in d for w in ["дожд", "ливен", "морос", "rain", "drizzle", "shower"]):
        return "󰖗"
    if any(w in d for w in ["туман", "мгла", "дым", "fog", "mist", "haze"]):
        return "󰖑"
    if any(w in d for w in ["перемен", "част", "partly"]):
        return "󰖕"
    if any(w in d for w in ["облачн", "пасмурн", "overcast", "cloudy"]):
        return "󰖐"
    return "󰖐"

def main():
    city = None
    force_auto = False

    args = sys.argv[1:]
    if "--auto" in args:
        force_auto = True
    for i, a in enumerate(args):
        if a == "--city" and i + 1 < len(args):
            city = args[i + 1].strip()

    if force_auto or not city or city.lower() in ["", "auto", "авто"]:
        detected = get_location()
        if detected:
            city = detected
        else:
            city = "Тюмень"

    # Запрос погоды через wttr.in с расширенными метеоданными
    temp = "+8°C"
    desc = "Ясно"
    feels_like = "+8°C"
    humidity = "45%"
    wind = "9 км/ч"
    precip = "0%"

    try:
        encoded_city = urllib.parse.quote(city)
        url = f"https://wttr.in/{encoded_city}?format=%t|%C|%f|%h|%w|%p&lang=ru"
        req = urllib.request.Request(url, headers={"User-Agent": "curl/7.68.0"})
        with urllib.request.urlopen(req, timeout=4) as res:
            raw = res.read().decode("utf-8", errors="ignore").strip()
            if "|" in raw:
                parts = [p.strip() for p in raw.split("|")]
                if len(parts) >= 2:
                    t = parts[0].replace("+", "")
                    if t and not t.startswith("-") and not t.startswith("+"):
                        t = "+" + t
                    temp = t
                    desc = parts[1]
                if len(parts) >= 3 and parts[2]:
                    fl = parts[2].replace("+", "")
                    if fl and not fl.startswith("-") and not fl.startswith("+"):
                        fl = "+" + fl
                    feels_like = fl
                if len(parts) >= 4 and parts[3]:
                    humidity = parts[3]
                if len(parts) >= 5 and parts[4]:
                    w = parts[4]
                    # Упрощаем стрелки ветра для аккуратности
                    w_clean = "".join(ch for ch in w if ch.isalnum() or ch in ["/", "."])
                    if "km/h" in w_clean.lower():
                        wind = w_clean.lower().replace("km/h", " км/ч")
                    else:
                        wind = w_clean
                if len(parts) >= 6 and parts[5]:
                    precip = parts[5]
    except Exception:
        pass

    out = {
        "city": city,
        "temp": temp,
        "desc": desc,
        "icon": get_icon(desc),
        "feels_like": feels_like,
        "humidity": humidity,
        "wind": wind,
        "precip": precip
    }
    print(json.dumps(out, ensure_ascii=False))

if __name__ == "__main__":
    main()
