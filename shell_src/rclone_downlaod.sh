nohup rclone copy "dropbox_crypt:02.dropbox" /mnt/4THDD_EXT/02.dropbox \
  --progress \
  --transfers 8 \
  --checkers 16 \
  --fast-list \
  > /mnt/4THDD_EXT/rclone_download.log 2>&1 & disown

