#!/bin/bash
 
# 生成17位时间戳字符串
tm=$(date +'%Y%m%d_%H%M%S')
rfs_path=./rfs_$tm
mkdir ${rfs_path}
 
# 获取 UUID for btrfs device
rid=$(lsblk -no UUID $(df -P / | awk 'END{print $1}'))
# mount FS_TREE
mount -o subvolid=5 UUID=${rid} ${rfs_path}
 
if [ $? -eq 0 ];then
    echo "mount rfs success"
else
    echo "mount rfs failed! exit"
    rm -r $rfs_path
    exit -1
fi
 
cd $rfs_path
 
#create snapshot for subvolume
echo "create backup snapshot for @ as @_$tm"
btrfs sub snap @ @_$tm
 
if [ $? -eq 0 ];then
    echo "create snapshot @_$tm for @ success"
else
    echo "create snapshot failed! exit"
    cd ..
    umount $rfs_path
    rm -r $rfs_path
    exit -1
fi
 
echo "complete snapshot..."
cd ..
umount $rfs_path
rm -r $rfs_path
