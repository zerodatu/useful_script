#!/usr/bin/env bash
# collect_pdfs.sh — 指定ディレクトリ配下のPDFを直下に回収するスクリプト
#
# 使い方:
#   ./collect_pdfs.sh /path/to/target
#
# `/path/to/target` 配下 (サブディレクトリ含む) から PDF を探索し、
# 対象パス直下へ移動します。同名ファイルが既に存在する場合は
# `_1`, `_2` ... のように連番を付けて衝突を避けます。

set -Eeuo pipefail

usage() {
  echo "Usage: $0 <target-directory>" >&2
  exit 1
}

(( $# == 1 )) || usage

target="$1"

if ! [[ -d "$target" ]]; then
  echo "ERROR: ディレクトリじゃないみたい: $target" >&2
  exit 1
fi

if ! target_abs=$(cd "$target" 2>/dev/null && pwd -P); then
  echo "ERROR: ターゲットにアクセスできないよ: $target" >&2
  exit 1
fi

found_any=false

find "$target_abs" -mindepth 2 -type f -iname '*.pdf' -print0 |
while IFS= read -r -d '' pdf; do
  found_any=true
  rel="${pdf#"$target_abs"/}"
  base="$(basename "$pdf")"
  dest="$target_abs/$base"

  if [[ -e "$dest" ]]; then
    stem="${base%.*}"
    ext="${base##*.}"
    counter=1
    while true; do
      dest="$target_abs/${stem}_${counter}.${ext}"
      [[ -e "$dest" ]] || break
      ((counter++))
    done
  fi

  mv "$pdf" "$dest"
  echo "moved: $rel -> $(basename "$dest")"
done

if ! $found_any; then
  echo "no PDFs found under $target_abs" >&2
fi
