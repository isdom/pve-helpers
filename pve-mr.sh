#!/bin/bash

echo "mount FS_TREE(subvolid=5) as $1"

rid=$(lsblk -no UUID $(df -P / | awk 'END{print $1}'))
mount -o subvolid=5 UUID=${rid} $1
