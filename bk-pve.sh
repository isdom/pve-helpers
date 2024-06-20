#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "需要提供备份@子卷的nfs 路径"
  exit -1
fi

# 检测备份路径的 dump 子目录是否存在
if [ -d "$1/dump/" ]; then
    echo "$1 为有效的PVE存储"
else
    echo "$1 不是有效PVE存储，终止备份"
    exit -1
fi

# 生成17位时间戳字符串
tm=$(date +'%Y%m%d_%H%M%S')
rfs_path=./rfs_${tm}
mkdir ${rfs_path}

# 获取 UUID for btrfs device
rid=$(lsblk -no UUID $(df -P / | awk 'END{print $1}'))
# mount FS_TREE
mount -o subvolid=5 UUID=${rid} ${rfs_path}

if [ $? -eq 0 ];then
    echo "mount rfs success"
else
    echo "mount rfs failed! exit"
    rm -r ${rfs_path}
    exit -1
fi

cd ${rfs_path}

# 检测 @ 子卷是否存在
if [ -d "./@" ]; then
    echo "FS_TREE/@ 存在，当前 PVE 子卷布局满足备份条件，继续执行备份"
else
    echo "FS_TREE/@ 不存在，当前 PVE 子卷布局不满足备份条件，终止备份"
    cd ..
    umount ${rfs_path}
    rm -r ${rfs_path}
    exit -1
fi

#create snapshot for subvolume
echo "create read-only snapshot for @ as @_${tm}"
btrfs sub snap -r @ @_${tm}

if [ $? -eq 0 ];then
    echo "create read-only snapshot @_${tm} for @ success"
else
    echo "create snapshot failed! exit"
    cd ..
    umount ${rfs_path}
    rm -r ${rfs_path}
    exit -1
fi

mkdir $1/dump/${tm}

#backup snapshot to remote
bk_pve=$1/dump/${tm}/$(hostname)_${tm}_pve.snap
echo "backup snapshot @_${tm} to ${bk_pve}"
btrfs send -f ${bk_pve} @_${tm}

if [ $? -eq 0 ];then
    echo "backup snapshot @_${tm} to ${bk_pve} success"
else
    echo "backup snapshot @_${tm} to ${bk_pve} failed!"
fi

echo "delete read-only snapshot @_${tm}"
btrfs sub del @_${tm} -c

echo "complete backup..."
cd ..
umount ${rfs_path}
rm -r ${rfs_path}
