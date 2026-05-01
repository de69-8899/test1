#!/bin/bash

DATA_DIR="./data"
COVER_DIR="$DATA_DIR/covers"
OUTPUT_FILE="$DATA_DIR/tracks.json"
CACHE_FILE="$DATA_DIR/romaji-cache.json"

mkdir -p "$COVER_DIR"

echo "Generating tracks.json with metadata, album covers, romaji cache, and fuzzy search data..."

python3 <<'PY'
import json
import subprocess
import hashlib
from pathlib import Path

DATA_DIR = Path("./data")
COVER_DIR = DATA_DIR / "covers"
OUTPUT_FILE = DATA_DIR / "tracks.json"
CACHE_FILE = DATA_DIR / "romaji-cache.json"

SUPPORTED = {".flac", ".mp3", ".wav", ".m4a", ".ogg", ".opus", ".aac"}

try:
    from pykakasi import kakasi
    kks = kakasi()
    ROMAJI_ENABLED = True
except ImportError:
    print("Warning: pykakasi not installed. Install with: python3 -m pip install pykakasi")
    ROMAJI_ENABLED = False

if CACHE_FILE.exists():
    with open(CACHE_FILE, "r", encoding="utf-8") as f:
        romaji_cache = json.load(f)
else:
    romaji_cache = {}

def to_romaji(text):
    text = str(text or "").strip()

    if not text:
        return ""

    if text in romaji_cache:
        return romaji_cache[text]

    if not ROMAJI_ENABLED:
        romaji_cache[text] = ""
        return ""

    result = kks.convert(text)
    romaji = " ".join(item["hepburn"] for item in result).strip()

    romaji_cache[text] = romaji
    return romaji

def safe_name(text):
    text = str(text or "Unknown")
    return "".join(c if c.isalnum() or c in " -_." else "_" for c in text).strip()

def album_key(artist, album):
    raw = f"{artist}__{album}".lower().strip()
    short_hash = hashlib.md5(raw.encode("utf-8")).hexdigest()[:8]
    return f"{safe_name(artist)} - {safe_name(album)} - {short_hash}"

def ffprobe_metadata(file_path):
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v", "quiet",
                "-print_format", "json",
                "-show_format",
                str(file_path)
            ],
            capture_output=True,
            text=True
        )

        data = json.loads(result.stdout or "{}")
        fmt = data.get("format", {})
        tags = {k.lower(): v for k, v in fmt.get("tags", {}).items()}

        return {
            "title": tags.get("title"),
            "artist": tags.get("artist") or tags.get("album_artist") or tags.get("albumartist"),
            "album": tags.get("album"),
            "genre": tags.get("genre"),
            "date": tags.get("date") or tags.get("year"),
            "duration": float(fmt.get("duration", 0)) if fmt.get("duration") else None,
            "bitrate": int(fmt.get("bit_rate", 0)) if fmt.get("bit_rate") else None
        }

    except Exception:
        return {}

def extract_album_cover(file_path, artist, album):
    cover_name = album_key(artist, album) + ".jpg"
    cover_path = COVER_DIR / cover_name

    if cover_path.exists() and cover_path.stat().st_size > 0:
        return cover_path.as_posix()

    command = [
        "ffmpeg",
        "-y",
        "-i", str(file_path),
        "-an",
        "-vcodec", "copy",
        str(cover_path)
    ]

    result = subprocess.run(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    if result.returncode == 0 and cover_path.exists() and cover_path.stat().st_size > 0:
        return cover_path.as_posix()

    return ""

tracks = []

for file in sorted(DATA_DIR.rglob("*")):
    if "covers" in file.parts:
        continue

    if file.suffix.lower() not in SUPPORTED:
        continue

    meta = ffprobe_metadata(file)

    title = meta.get("title") or file.stem.replace("_", " ").strip()
    artist = meta.get("artist") or "Unknown Artist"
    album = meta.get("album") or "Unknown Album"
    genre = meta.get("genre") or ""
    date = meta.get("date") or ""

    cover = extract_album_cover(file, artist, album)
    filename_search = file.stem.replace("_", " ")

    romaji = " ".join([
        to_romaji(title),
        to_romaji(artist),
        to_romaji(album),
        to_romaji(genre),
        to_romaji(filename_search)
    ]).strip()

    search_text = " ".join([
        str(title),
        str(artist),
        str(album),
        str(genre),
        str(date),
        str(filename_search),
        str(romaji)
    ]).lower()

    tracks.append({
        "title": title,
        "artist": artist,
        "album": album,
        "genre": genre,
        "date": date,
        "duration": meta.get("duration"),
        "bitrate": meta.get("bitrate"),
        "cover": cover,
        "src": file.as_posix(),
        "romaji": romaji,
        "search": search_text
    })

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(tracks, f, ensure_ascii=False, indent=2)

with open(CACHE_FILE, "w", encoding="utf-8") as f:
    json.dump(romaji_cache, f, ensure_ascii=False, indent=2)

print(f"Done! Generated {len(tracks)} tracks.")
print(f"Romaji cache saved to {CACHE_FILE}")
PY