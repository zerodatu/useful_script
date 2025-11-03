#!/usr/bin/env bash
# rm_pdf_dirs.sh — カレント直下のPDF名に一致するディレクトリを削除
set -Eeuo pipefail

target_dir="${1:-.}"

if ! target_abs=$(cd "$target_dir" 2>/dev/null && pwd -P); then
  echo "ERROR: ディレクトリにアクセスできないよ: $target_dir" >&2
  exit 1
fi

deleted=0
skipped=0

while IFS= read -r -d '' pdf; do
  pdf_name=$(basename "$pdf")
  base="${pdf_name%.[Pp][Dd][Ff]}"
  dir_candidate="$target_abs/$base"

  if [[ -d "$dir_candidate" ]]; then
    if [[ "$dir_candidate" == "$target_abs" ]]; then
      echo "warn: ルートと同名のためスキップ: $dir_candidate" >&2
      ((skipped++))
      continue
    fi

    rm -rf -- "$dir_candidate"
    echo "removed: $dir_candidate"
    ((deleted++))
  else
    ((skipped++))
  fi
done < <(find "$target_abs" -maxdepth 1 -type f -iname '*.pdf' -print0)

echo "done: deleted=$deleted skipped=$skipped"
