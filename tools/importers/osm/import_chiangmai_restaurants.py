#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, time, json, re, argparse, requests
from pathlib import Path

# ======= ENV / CONFIG =======
APP_BASE_URL    = os.environ.get("APP_BASE_URL", "http://localhost:8082").strip().strip("'\"")
APP_CREATE_PATH = os.environ.get("APP_CREATE_PATH", "/restaurantsJson").strip() or "/restaurantsJson"
CREATE_URL      = f"{APP_BASE_URL.rstrip('/')}{APP_CREATE_PATH}"

APP_TOKEN  = os.environ.get("APP_TOKEN", "")
HEADERS    = {"Content-Type": "application/json"}
if APP_TOKEN.strip():
    HEADERS["Authorization"] = APP_TOKEN

OVERPASS_URL = os.environ.get("OVERPASS_URL", "https://overpass-api.de/api/interpreter")

# ======= Utils =======
def pick_name(tags: dict) -> str:
    """เลือกชื่อไทย/อังกฤษ/ชื่อทั่วไป"""
    for k in ("name:th", "name:en", "name"):
        v = tags.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return "ไม่ทราบชื่อ"

def pick_phone(tags: dict) -> str:
    for k in ("contact:phone", "phone"):
        v = tags.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return ""

def pick_admin(tags: dict):
    province = (tags.get("addr:province") or "เชียงใหม่").strip()
    district = (tags.get("addr:district")
                or tags.get("addr:city_district")
                or tags.get("addr:county")
                or tags.get("addr:city")
                or "").strip()
    subdistrict = (tags.get("addr:subdistrict")
                   or tags.get("addr:suburb")
                   or tags.get("addr:neighbourhood")
                   or tags.get("addr:village")
                   or "").strip()
    return province, district, subdistrict

def pick_desc(tags: dict) -> str:
    parts = []
    if tags.get("cuisine"):       parts.append(f"cuisine={tags['cuisine']}")
    if tags.get("opening_hours"): parts.append(f"hours={tags['opening_hours']}")
    if tags.get("website"):       parts.append(f"web={tags['website']}")
    return " | ".join(parts)

_TIME_RE = re.compile(r"(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})")

def parse_opening_hours_to_times(oh: str):
    """
    คืน ('HH:mm','HH:mm') แบบง่าย:
    - '24/7' -> ('00:00','23:59')
    - เจอช่วงแรก '09:00-18:00' -> ('09:00','18:00')
    - หาไม่ได้ -> (None, None)
    """
    if not isinstance(oh, str) or not oh.strip():
        return None, None
    t = oh.strip()
    if "24/7" in t:
        return "00:00", "23:59"
    m = _TIME_RE.search(t)
    if m:
        return m.group(1), m.group(2)
    return None, None

def get_latlon(el: dict):
    if "lat" in el and "lon" in el:
        return float(el["lat"]), float(el["lon"])
    c = el.get("center") or {}
    if "lat" in c and "lon" in c:
        return float(c["lat"]), float(c["lon"])
    return None, None

def make_dupe_key(name, lat, lon):
    return f"{name}|{round(lat, 6)}|{round(lon, 6)}"

def load_query(path: Path) -> str:
    return path.read_text(encoding="utf-8")

def call_overpass(query: str) -> dict:
    r = requests.post(OVERPASS_URL, data={"data": query}, timeout=180)
    r.raise_for_status()
    return r.json()

def save_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def pick_type_name(tags: dict) -> str:
    txt = " ".join([
        (tags.get("cuisine") or "").lower(),
        (tags.get("amenity") or "").lower(),
        (tags.get("shop") or "").lower()
    ])

    rules = [
        (("shabu","sukiyaki","hotpot"), "ชาบู/สุกี้ยากี้/หม้อไฟ"),
        (("bbq","yakiniku","barbecue","grill"), "ปิ้งย่าง/ยากินิกุ/บาร์บีคิว"),
        (("sushi","sashimi"), "ซูชิ/ซาชิมิ"),
        (("ramen",), "ราเมง"),
        (("udon","soba"), "อุด้ง/โซบะ"),
        (("dim sum","dimsum","yumcha"), "ติ่มซำ"),
        (("seafood",), "ซีฟู้ด"),
        (("burger","sandwich"), "เบอร์เกอร์/แซนด์วิช"),
        (("pizza",), "พิซซ่า"),
        (("cafe","coffee"), "คาเฟ่/กาแฟ"),
        (("bakery","patisserie","bread"), "เบเกอรี่/ขนมอบ"),
        (("dessert","ice cream","sweet"), "ของหวาน/ไอศกรีม"),
        (("fast_food",), "อาหารจานด่วน"),
        (("breakfast","brunch"), "อาหารเช้า/บรันช์"),
        (("street_food","streetfood"), "สตรีทฟู้ด"),
        (("vegetarian","vegan"), "มังสวิรัติ/วีแกน"),
        (("halal",), "ฮาลาล"),
        (("healthy","clean food"), "อาหารเพื่อสุขภาพ"),
        (("thai",), "ไทย"),
        (("japanese",), "ญี่ปุ่น"),
        (("korean",), "เกาหลี"),
        (("chinese",), "จีน"),
        (("vietnamese",), "เวียดนาม"),
        (("indian",), "อินเดีย"),
        (("italian",), "อิตาลี"),
        (("french",), "ฝรั่งเศส"),
        (("mediterranean",), "เมดิเตอร์เรเนียน"),
        (("mexican",), "เม็กซิกัน"),
        (("fusion",), "ฟิวชัน"),
    ]
    for keys, label in rules:
        if any(k in txt for k in keys):
            return label
    return "ร้านอาหาร"

# ---- HTTP with retry (กัน 429/5xx) ----
def post_with_retry(url, headers, payload, tries=4, backoff=0.6):
    for k in range(1, tries + 1):
        try:
            r = requests.post(url, headers=headers, json=payload, timeout=30)
            if r.status_code in (200, 201):
                return True
            if r.status_code in (429, 500, 502, 503, 504):
                time.sleep(backoff * k)
                continue
            print(f"[{r.status_code}] {r.text[:200]}")
            return False
        except requests.RequestException as e:
            time.sleep(backoff * k)
    print("Give up after retries")
    return False

# ======= Import process =======
def import_from_overpass(query_path: Path, limit: int = 0, dry_run: bool = False,
                         save_raw: Path = None, delay: float = 0.05):
    print(f"-> Overpass: {OVERPASS_URL}")
    print(f"-> Target  : {CREATE_URL}")
    query = load_query(query_path)
    data  = call_overpass(query)
    if save_raw:
        save_json(save_raw, data)
        print(f"Saved raw JSON to {save_raw}")

    elements = data.get("elements", [])
    print(f"Got {len(elements)} elements")

    seen, created, skipped = set(), 0, 0

    for i, el in enumerate(elements, 1):
        tags = el.get("tags", {}) or {}
        lat, lon = get_latlon(el)
        if lat is None or lon is None:
            skipped += 1
            continue

        name = pick_name(tags)
        dupe = make_dupe_key(name, lat, lon)
        if dupe in seen:
            skipped += 1
            continue
        seen.add(dupe)

        province, district, subdistrict = pick_admin(tags)
        phone = pick_phone(tags)
        desc  = pick_desc(tags)
        ot, ct = parse_opening_hours_to_times(tags.get("opening_hours", ""))
        type_name = pick_type_name(tags)

        payload = {
            "restaurantName": name,
            "restaurantPhone": phone or None,
            "description": desc or None,
            "latitude":  str(lat),
            "longitude": str(lon),
            "province": province or None,
            "district": district or None,
            "subdistrict": subdistrict or None,
            "openTime": ot or None,
            "closeTime": ct or None,
            "restaurantTypeName": type_name,  # ฝั่ง backend ควร find-or-create
        }

        if dry_run:
            if i <= 5:
                print(f"[DRY RUN] {payload}")
        else:
            ok = post_with_retry(CREATE_URL, HEADERS, payload, tries=4, backoff=0.6)
            if ok:
                created += 1
            else:
                skipped += 1
            time.sleep(delay)

        if limit and created >= limit:
            break

    print(f"Done. Created={created}, Skipped={skipped}")

def main():
    p = argparse.ArgumentParser(description="Import Chiang Mai restaurants from OSM into your backend.")
    p.add_argument("--query", default="queries/chiangmai_restaurants.overpassql")
    p.add_argument("--limit", type=int, default=0)        # 0 = ไม่จำกัด
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--save-raw", default="")
    p.add_argument("--delay", type=float, default=0.10)   # default ช้าลงนิด กัน 500/429
    a = p.parse_args()

    import_from_overpass(
        Path(a.query),
        a.limit,
        a.dry_run,
        Path(a.save_raw) if a.save_raw else None,
        a.delay
    )

if __name__ == "__main__":
    main()
