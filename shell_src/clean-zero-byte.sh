#!/usr/bin/env bash
# clean-zero-byte.sh
# 再帰的に0バイトファイルを削除（除外パターン対応、dry-runあり）

set -euo pipefail

usage() {
  cat <<'USAGE'
使い方:
  clean-zero-byte.sh [オプション] <対象ディレクトリ>

オプション:
  -n, --dry-run      削除せずに一覧だけ表示
  -E, --exclude PAT  除外パターン（複数指定可）
  -h, --help         このヘルプを表示
USAGE
}

dry_run=false
excludes=()

# 引数処理
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) dry_run=true; shift ;;
    -E|--exclude)
      [[ $# -ge 2 ]] || { echo "--exclude の後にパターンが必要なの"; exit 1; }
      excludes+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "不明なオプション: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

[[ $# -eq 1 ]] || { usage; exit 1; }
target=$1
[[ -d "$target" ]] || { echo "ディレクトリじゃないよ: $target"; exit 1; }

# findコマンドを安全に構築
find_cmd=(find "$target")

# 除外指定
for pat in "${excludes[@]}"; do
  find_cmd+=(-path "$pat" -prune -o)
done

# ファイルのみ、サイズ0のものを探す
find_cmd+=(-type f -size 0c -print)

# dry-runモード or 実削除
if $dry_run; then
  echo "💡 以下のファイルが0バイトです（削除しません）"
  "${find_cmd[@]}"
else
  echo "🗑️ 0バイトファイルを削除します..."
  "${find_cmd[@]}" -exec rm -f -- {} +
fi
