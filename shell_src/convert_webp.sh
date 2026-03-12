#!/usr/bin/env bash

set -u

# cwebp コマンド確認
if ! command -v cwebp >/dev/null 2>&1; then
  echo "エラー: cwebp が見つかりません"
  exit 1
fi

QUALITY=80

find . -type f \( \
  -iname "*.jpg" -o \
  -iname "*.jpeg" -o \
  -iname "*.png" \
\) -print0 | while IFS= read -r -d '' file; do

  output="${file%.*}.webp"

  # 既存webpチェック
  if [ -f "$output" ]; then
    echo "スキップ: 既に存在 $output"
    continue
  fi

  echo "変換: $file -> $output"

  if cwebp -q "$QUALITY" "$file" -o "$output" >/dev/null 2>&1; then
    echo "成功: 元ファイル削除 $file"
    rm -f "$file"
  else
    echo "失敗: $file"
  fi

done

echo "完了 ✨"
