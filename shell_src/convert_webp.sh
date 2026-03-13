cat > ~/convert_webp.sh <<'EOF'
#!/usr/bin/env bash

set -u
set -o pipefail

if ! command -v cwebp >/dev/null 2>&1; then
  echo "エラー: cwebp が見つかりません"
  exit 1
fi

if command -v magick >/dev/null 2>&1; then
  IM_CMD="magick"
elif command -v convert >/dev/null 2>&1; then
  IM_CMD="convert"
else
  IM_CMD=""
fi

QUALITY_JPG=80
PNG_MODE="lossless"   # "lossless" or "lossy"
QUALITY_PNG=90

find . -type f \( \
  -iname "*.jpg" -o \
  -iname "*.jpeg" -o \
  -iname "*.png" \
\) -print0 | while IFS= read -r -d '' file; do

  if [ ! -f "$file" ]; then
    echo "スキップ: 入力ファイルが見つからない $file"
    continue
  fi

  output="${file%.*}.webp"

  if [ -f "$output" ]; then
    echo "スキップ: 既に存在 $output"
    continue
  fi

  echo "変換: $file -> $output"

  ext="${file##*.}"
  ext_lower=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
  err_file=$(mktemp)
  tmp_png=""

  success=0

  if [ "$ext_lower" = "png" ]; then
    if [ "$PNG_MODE" = "lossless" ]; then
      cwebp -lossless "$file" -o "$output" > /dev/null 2>"$err_file" && success=1
    else
      cwebp -q "$QUALITY_PNG" "$file" -o "$output" > /dev/null 2>"$err_file" && success=1
    fi
  else
    # まずはそのままJPEGを試す
    cwebp -q "$QUALITY_JPG" "$file" -o "$output" > /dev/null 2>"$err_file" && success=1

    # ダメなら ImageMagick で sRGB PNG に変換して再挑戦
    if [ $success -eq 0 ] && [ -n "$IM_CMD" ]; then
      echo "救済処理: RGB変換して再試行 $file"
      rm -f "$err_file"
      err_file=$(mktemp)
      tmp_png=$(mktemp --suffix=.png)

      if "$IM_CMD" "$file" -colorspace sRGB "$tmp_png" > /dev/null 2>"$err_file"; then
        rm -f "$err_file"
        err_file=$(mktemp)
        cwebp -q "$QUALITY_JPG" "$tmp_png" -o "$output" > /dev/null 2>"$err_file" && success=1
      fi
    fi
  fi

  if [ $success -eq 1 ] && [ -s "$output" ]; then
    echo "成功: 元ファイル削除 $file"
    rm -f "$file"
  else
    echo "失敗: $file"
    if [ -s "$err_file" ]; then
      echo "理由:"
      cat "$err_file"
    else
      echo "理由: 詳細不明"
    fi
    rm -f "$output"
  fi

  rm -f "$err_file"
  [ -n "$tmp_png" ] && rm -f "$tmp_png"
done

echo "完了 ✨"
EOF

chmod +x ~/convert_webp.sh