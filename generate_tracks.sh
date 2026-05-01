#!/bin/bash

DATA_DIR="./data"
OUTPUT_FILE="$DATA_DIR/tracks.json"

echo "Generating tracks.json..."

echo "[" > "$OUTPUT_FILE"

first=true

find "$DATA_DIR" -type f \( -iname "*.flac" -o -iname "*.mp3" -o -iname "*.wav" \) | sort | while read -r file; do
    filename=$(basename "$file")
    relpath="${file#./}"

    # Remove extension
    name="${filename%.*}"

    # Expected format:
    # title - album - artist.flac
    IFS='-' read -r raw_title raw_album raw_artist <<< "$name"

    title=$(echo "$raw_title" | xargs)
    album=$(echo "$raw_album" | xargs)
    artist=$(echo "$raw_artist" | xargs)

    # Fallbacks if filename is incomplete
    [ -z "$title" ] && title="$name"
    [ -z "$album" ] && album="Unknown Album"
    [ -z "$artist" ] && artist="Unknown Artist"

    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$OUTPUT_FILE"
    fi

    cat <<EOF >> "$OUTPUT_FILE"
  {
    "title": "$title",
    "artist": "$artist",
    "album": "$album",
    "src": "$relpath"
  }
EOF

done

echo "]" >> "$OUTPUT_FILE"

echo "Done! tracks.json updated."