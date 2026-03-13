nohup rclone sync /mnt/4THDD_EXT/02.dropbox "dropbox_crypt:02.dropbox" --progress --transfers 8 --checkers 8 --fast-list > /mnt/4THDD_EXT/rclone_sync.log 2>&1 & disown
