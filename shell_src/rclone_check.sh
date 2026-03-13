nohup rclone cryptcheck /mnt/4THDD_EXT/02.dropbox "dropbox_crypt:02.dropbox" \
  --checkers 8 \
  --fast-list \
  --one-way \
  --stats 5m \
  --stats-one-line \
  > rclone_check.log 2>&1 & disown

