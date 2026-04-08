#!/usr/bin/env bash

set -euo pipefail

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SDKMAN_DIR_ORIG="$SDKMAN_DIR"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

is_sourced() {
  [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

log() {
  printf '%s\n' "$*"
}

backup_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    cp "$file" "${file}.bak.sdkman-uninstall.${TIMESTAMP}"
    log "Backed up: ${file}.bak.sdkman-uninstall.${TIMESTAMP}"
  fi
}

remove_sdkman_lines() {
  local file="$1"
  local tmp

  [[ -f "$file" ]] || return 0

  tmp="$(mktemp)"
  awk '
    /#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!/ { next }
    /sdkman-init\.sh/ { next }
    /^[[:space:]]*export[[:space:]]+SDKMAN_DIR=.*sdkman/ { next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  log "Cleaned SDKMAN init lines from: $file"
}

remove_path_prefix() {
  local target="$1"
  local path_string="${2:-$PATH}"
  local new_path=""
  local entry

  IFS=':' read -r -a _path_entries <<< "$path_string"
  for entry in "${_path_entries[@]}"; do
    [[ "$entry" == "$target" ]] && continue
    if [[ -z "$new_path" ]]; then
      new_path="$entry"
    else
      new_path="${new_path}:$entry"
    fi
  done

  printf '%s' "$new_path"
}

cleanup_current_shell_env() {
  local sdkman_dir="$SDKMAN_DIR"
  local candidate_bin_dirs=()
  local current_link
  local entry
  local cleaned_path=""

  if [[ -d "$sdkman_dir/candidates" ]]; then
    while IFS= read -r -d '' current_link; do
      candidate_bin_dirs+=("${current_link}/bin")
    done < <(find "$sdkman_dir/candidates" -mindepth 2 -maxdepth 2 -type l -name current -print0)
  fi

  for current_link in "${candidate_bin_dirs[@]}"; do
    PATH="$(remove_path_prefix "$current_link" "$PATH")"
  done
  IFS=':' read -r -a candidate_bin_dirs <<< "$PATH"
  for entry in "${candidate_bin_dirs[@]}"; do
    [[ "$entry" == "$sdkman_dir"* ]] && continue
    if [[ -z "$cleaned_path" ]]; then
      cleaned_path="$entry"
    else
      cleaned_path="${cleaned_path}:$entry"
    fi
  done
  PATH="$cleaned_path"
  export PATH

  unset JAVA_HOME KOTLIN_HOME
  unset SDKMAN_BROKER_API SDKMAN_CANDIDATES_API SDKMAN_CANDIDATES_DIR SDKMAN_PLATFORM SDKMAN_VERSION
  unset binary_input zip_output SDKMAN_DIR

  hash -r 2>/dev/null || true
  log "Cleaned SDKMAN environment variables from current shell"
}

log "Starting SDKMAN uninstall script"
log "SDKMAN_DIR: $SDKMAN_DIR"

cleanup_current_shell_env

for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
  backup_file "$rc_file"
  remove_sdkman_lines "$rc_file"
done

if [[ -d "$SDKMAN_DIR_ORIG" ]]; then
  rm -rf "$SDKMAN_DIR_ORIG"
  log "Deleted: $SDKMAN_DIR_ORIG"
else
  log "SDKMAN directory not found, skipped: $SDKMAN_DIR_ORIG"
fi

log ""
log "Completed."
if is_sourced; then
  log "This script was sourced, so the current shell environment was cleaned too."
else
  log "This script was executed as a subprocess, so the parent shell may still have old SDKMAN variables cached."
  log "To clean the current shell too, run:"
  log "  source \"$0\""
  log "or restart the shell with:"
  log "  exec \$SHELL -l"
fi
log "Suggested checks:"
log "  env | grep -i SDKMAN"
log "  command -v sdk"
log "  command -v java"
log "  echo \$PATH"
