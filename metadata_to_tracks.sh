#!/bin/bash

DATA_DIR="./data"
OUTPUT_FILE="$DATA_DIR/tracks.json"

echo "Generating tracks.json with advanced metadata..."

python3 <<'PY'
import os
import json
import subprocess
from pathlib import Path

DATA_DIR = Path("./data")
OUTPUT_FILE = DATA_DIR / "tracks.json"

SUPPORTED = {".flac", ".mp3", ".wav", ".m4a", ".ogg", ".opus", ".aac"}

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

        # 🔥 IMPORTANT: normalize tag keys (fix your issue)
        raw_tags = fmt.get("tags", {})
        tags = {k.lower(): v for k, v in raw_tags.items()}

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

def clean_filename_name(path):
    return path.stem.replace("_", " ").strip()

tracks = []

for file in sorted(DATA_DIR.rglob("*")):
    if file.suffix.lower() not in SUPPORTED:
        continue

    meta = ffprobe_metadata(file)

    title = meta.get("title") or clean_filename_name(file)
    artist = meta.get("artist") or "Unknown Artist"
    album = meta.get("album") or "Unknown Album"

    rel_path = file.as_posix()

    tracks.append({
        "title": title,
        "artist": artist,
        "album": album,
        "genre": meta.get("genre") or "",
        "date": meta.get("date") or "",
        "duration": meta.get("duration"),
        "bitrate": meta.get("bitrate"),
        "src": rel_path
    })

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(tracks, f, ensure_ascii=False, indent=2)

print(f"Done! Generated {OUTPUT_FILE} with {len(tracks)} tracks.")
PY