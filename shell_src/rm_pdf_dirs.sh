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

declare -A pdf_map=()

while IFS= read -r -d '' pdf; do
  pdf_dir=$(dirname -- "$pdf")
  pdf_name=$(basename -- "$pdf")
  base="${pdf_name%.[Pp][Dd][Ff]}"
  key="${pdf_dir}"$'\t'"${base,,}"
  pdf_map["$key"]=1
done < <(find "$target_abs" -maxdepth 1 -type f -iname '*.pdf' -print0)

while IFS= read -r -d '' dir_path; do
  dir="${dir_path%/}"
  parent=$(dirname -- "$dir")
  base=$(basename -- "$dir")
  key="${parent}"$'\t'"${base,,}"

  if [[ -n "${pdf_map[$key]:-}" ]]; then
    rm -rf -- "$dir"
    echo "removed: $dir"
    ((deleted++))
  else
    echo "skip: no matching pdf -> $dir" >&2
    ((skipped++))
  fi
done < <(find "$target_abs" -maxdepth 1 -mindepth 1 -type d -print0)

echo "done: deleted=$deleted skipped=$skipped"
