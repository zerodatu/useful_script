#!/usr/bin/env bash
# mkpdfs.sh — ディレクトリごとに画像を名前順でPDF化するスクリプト
#
# 📘 概要:
#   指定したルートディレクトリ以下を再帰的に探索して、
#   各フォルダ内の画像を名前順に1つのPDFにまとめます。
#   PDFは同じディレクトリ内、または別の出力先ディレクトリに作成できます。
#
# 💡 使い方:
#   ./mkpdfs.sh [検索ルート] [出力ルート]
#
#   検索ルート   : 探すディレクトリ (省略時はカレント)
#   出力ルート   : まとめたPDFを置く場所 (省略時は各フォルダ内に出力)
#
# 🧩 実行イメージ:
#   # カレント配下の各フォルダ内にPDFを作成
#   ./mkpdfs.sh
#
#   # ~/Pictures 以下を走査し、PDFは全部 ~/PDFs に集約
#   ./mkpdfs.sh ~/Pictures ~/PDFs
#
#   # /mnt/data/images を走査してPDFを各フォルダに作成
#   ./mkpdfs.sh /mnt/data/images
#
# 🔧 依存:
#   - img2pdf（推奨）
#   - ImageMagick (magick または convert)
#
# 📦 インストール例 (Pop!_OS / Ubuntu):
#   sudo apt update
#   sudo apt install -y img2pdf imagemagick
#
# 🕒 省力化機能:
#   既にPDFが存在し、それが画像より新しい場合は自動スキップします。
#
set -Eeuo pipefail

root="${1:-.}"
out_root="${2:-}"

img_regex='.*\.\(jpg\|jpeg\|png\|gif\|bmp\|tif\|tiff\|webp\|heic\)$'

if ! root_abs=$(cd "$root" 2>/dev/null && pwd -P); then
  echo "ERROR: ルートディレクトリにアクセスできないよ: $root" >&2
  exit 1
fi

have_img2pdf=false
have_magick=false
have_convert=false
command -v img2pdf >/dev/null && have_img2pdf=true
command -v magick   >/dev/null && have_magick=true
command -v convert  >/dev/null && have_convert=true

if ! $have_img2pdf && ! $have_magick && ! $have_convert; then
  echo "ERROR: img2pdf または ImageMagick(magick/convert) をインストールしてね" >&2
  exit 1
fi

find "$root" -type d -print0 | while IFS= read -r -d '' dir; do
  mapfile -d '' -t imgs < <(
    find "$dir" -maxdepth 1 -type f -iregex "$img_regex" -print0 | sort -z
  )
  ((${#imgs[@]})) || continue

  if [[ -n "$out_root" ]]; then
    rel="${dir#"$root"/}"
    [[ "$rel" == "$dir" ]] && rel="$(basename "$dir")"
    mkdir -p "$out_root"
    outfile="$out_root/${rel//\//_}.pdf"
  else
    base="$(basename "$dir")"
    if [[ "$base" == "." || "$base" == "/" || -z "$base" ]]; then
      base="$(basename "$root_abs")"
    fi
    outfile="$dir/$base.pdf"
  fi

  if [[ -f "$outfile" ]]; then
    newest_img_mtime=0
    for f in "${imgs[@]}"; do
      m=$(stat -c %Y "$f")
      (( m > newest_img_mtime )) && newest_img_mtime=$m
    done
    pdf_mtime=$(stat -c %Y "$outfile")
    if (( pdf_mtime >= newest_img_mtime )); then
      echo "skip: $outfile up to date"
      continue
    fi
  fi

  pdf_done=false
  err_msg=""

  if $have_img2pdf; then
    if output=$(img2pdf --rotation ifvalid --output "$outfile" "${imgs[@]}" 2>&1); then
      pdf_done=true
    else
      err_msg="$output"
      if [[ "$err_msg" == *"Invalid rotation"* ]]; then
        echo "warn: img2pdf rotation auto failed (Invalid rotation). retrying with --rotation none: $outfile" >&2
        if output=$(img2pdf --rotation none --output "$outfile" "${imgs[@]}" 2>&1); then
          pdf_done=true
        else
          err_msg="$output"
        fi
      fi

      if ! $pdf_done && [[ "$err_msg" == *"alpha"* ]]; then
        if $have_magick || $have_convert; then
          echo "warn: flattening images to remove alpha channel before pdf: $outfile" >&2
          tmpdir=$(mktemp -d)
          tmp_imgs=()
          flatten_failed=false
          for idx in "${!imgs[@]}"; do
            img="${imgs[$idx]}"
            printf -v tmp "%s/%05d.jpg" "$tmpdir" "$idx"
            if $have_magick; then
              if ! magick "$img" -background white -alpha remove -alpha off "$tmp"; then
                flatten_failed=true
                err_msg="failed to flatten $img"
                break
              fi
            else
              if ! convert "$img" -background white -alpha remove -alpha off "$tmp"; then
                flatten_failed=true
                err_msg="failed to flatten $img"
                break
              fi
            fi
            tmp_imgs+=("$tmp")
          done

          if ! $flatten_failed; then
            if output=$(img2pdf --rotation none --output "$outfile" "${tmp_imgs[@]}" 2>&1); then
              pdf_done=true
              err_msg=""
            else
              err_msg="$output"
            fi
          fi

          rm -rf "$tmpdir"
        fi
      fi
    fi
  fi

  if ! $pdf_done; then
    if $have_magick; then
      [[ -n "$err_msg" ]] && echo "$err_msg" >&2
      magick "${imgs[@]}" "$outfile"
      pdf_done=true
    elif $have_convert; then
      [[ -n "$err_msg" ]] && echo "$err_msg" >&2
      convert "${imgs[@]}" "$outfile"
      pdf_done=true
    else
      [[ -n "$err_msg" ]] && echo "$err_msg" >&2
      echo "ERROR: PDF生成に失敗したよ: $outfile" >&2
      exit 1
    fi
  fi

  echo "made: $outfile"
done
