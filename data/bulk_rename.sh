#!/bin/bash

echo "=== Bulk Filename Editor ==="

# Choose mode
echo "Select operation:"
echo "1) Replace text in filenames"
echo "2) Add prefix"
echo "3) Add suffix"
echo "4) Convert to lowercase"
echo "5) Convert to uppercase"
read -p "Enter choice (1-5): " choice

read -p "Target directory (default = current): " dir
dir=${dir:-.}

cd "$dir" || exit

case $choice in
  1)
    read -p "Text to find: " find
    read -p "Replace with: " replace
    for f in *; do
      new=$(echo "$f" | sed "s/$find/$replace/g")
      if [[ "$f" != "$new" ]]; then
        mv -i "$f" "$new"
      fi
    done
    ;;

  2)
    read -p "Prefix to add: " prefix
    for f in *; do
      mv -i "$f" "${prefix}${f}"
    done
    ;;

  3)
    read -p "Suffix to add (before extension): " suffix
    for f in *; do
      name="${f%.*}"
      ext="${f##*.}"
      if [[ "$f" == *.* ]]; then
        mv -i "$f" "${name}${suffix}.${ext}"
      else
        mv -i "$f" "${name}${suffix}"
      fi
    done
    ;;

  4)
    for f in *; do
      new=$(echo "$f" | tr '[:upper:]' '[:lower:]')
      mv -i "$f" "$new"
    done
    ;;

  5)
    for f in *; do
      new=$(echo "$f" | tr '[:lower:]' '[:upper:]')
      mv -i "$f" "$new"
    done
    ;;
    
  *)
    echo "Invalid choice"
    ;;
esac

echo "Done!"