#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "usage: ./debian-bk-btrfs.sh <snapshot date, like 2026-05-03_20-00-01>"
  exit -1
fi

# 获取 UUID for btrfs device
rid=$(lsblk -no UUID $(df -P / | awk 'END{print $1}'))

# mount FS_TREE
sudo mkdir -p /mnt/backup
sudo mount -o subvolid=5 UUID=${rid} /mnt/backup

SNAP_DATE="$1"
SNAP_ROOT="/mnt/backup/timeshift-btrfs/snapshots/${SNAP_DATE}/@"
SNAP_HOME="/mnt/backup/timeshift-btrfs/snapshots/${SNAP_DATE}/@home"

echo "$SNAP_ROOT"
echo "$SNAP_HOME"
# 检查 @ 子卷的只读属性
RO_ROOT=$(sudo btrfs property get "$SNAP_ROOT" ro | awk -F= '{print $2}')
echo "Root snapshot ro=$RO_ROOT"

# 检查 @home 子卷的只读属性
RO_HOME=$(sudo btrfs property get "$SNAP_HOME" ro | awk -F= '{print $2}')
echo "Home snapshot ro=$RO_HOME"

if [ "$RO_ROOT" = "true" ]; then
    SEND_ROOT="$SNAP_ROOT"
else
    TMP_ROOT="/mnt/backup/@-send-ro"
    sudo btrfs subvolume snapshot -r "$SNAP_ROOT" "$TMP_ROOT"
    SEND_ROOT="$TMP_ROOT"
fi

echo "Send @ ro snapshot: $SEND_ROOT"

if [ "$RO_HOME" = "true" ]; then
    SEND_HOME="$SNAP_HOME"
else
    TMP_HOME="/mnt/backup/@home-send-ro"
    sudo btrfs subvolume snapshot -r "$SNAP_HOME" "$TMP_HOME"
    SEND_HOME="$TMP_HOME"
fi

echo "Send @home ro snapshot: $SEND_HOME"
