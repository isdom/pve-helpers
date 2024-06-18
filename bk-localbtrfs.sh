#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "需要提供备份 @local-btrfs 子卷的nfs 路径"
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
rfs_path=./rfs_$tm
mkdir $rfs_path

# 获取 UUID for btrfs device
rid=$(lsblk -no UUID $(df -P / | awk 'END{print $1}'))
# mount FS_TREE
mount -o subvolid=5 UUID=$rid $rfs_path

if [ $? -eq 0 ];then
    echo "mount rfs success"
else
    echo "mount rfs failed! exit"
    rm -r $rfs_path
    exit -1
fi

cd $rfs_path


# 检测 @local-btrfs 子卷是否存在
if [ -d "@local-btrfs" ]; then
    echo "@local-btrfs 存在"
else
    echo "@local-btrfs 不存在，终止备份"
    cd ..
    umount $rfs_path
    rm -r $rfs_path
    exit -1
fi

mkdir $tm

#create snapshot for @local-btrfs
echo "create read-only snapshot for @local-btrfs as $tm/@local-btrfs-ro"
btrfs sub snap -r @local-btrfs $tm/@local-btrfs-ro

if [ $? -eq 0 ];then
    echo "create read-only snapshot $tm/@local-btrfs-ro for @local-btrfs success"
else
    echo "create snapshot failed! exit"
    cd ..
    umount $rfs_path
    rm -r $rfs_path
    exit -1
fi

echo "create all vm subvolume snapshot"
btrfs sub list @local-btrfs | awk '$9 ~/^image/{print $9}' | awk -v tm=$tm '{split($0,x,"/")}{print "btrfs sub snap -r @local-btrfs/"$0" "tm"/"x[3]}' | bash

mkdir $1/dump/${tm}

#backup snapshot to remote
bk_path=$1/dump/${tm}/$(hostname)
bk_lb=${bk_path}_${tm}_local_btrfs.snap
echo "backup snapshot $tm/@local-btrfs-ro to $bk_lb"
btrfs send -f $bk_lb $tm/@local-btrfs-ro
 
if [ $? -eq 0 ];then
   echo "backup snapshot $tm/@local-btrfs-ro to $bk_path success"
else
   echo "backup snapshot $tm/@local-btrfs-ro to $bk_path failed!"
fi

echo "delete read-only snapshot $tm/@local-btrfs-ro"
btrfs sub del -c $tm/@local-btrfs-ro

#backup snapshot to remote
bk_vm=${bk_path}_${tm}

# btrfs sub list -o $tm | awk -v tm=$tm '$9 ~/vm-/{print $9}' | awk -v tm=$tm '{print "btrfs send -f "tm"/"$0}'
btrfs sub list -o $tm | awk '$9 ~/vm-/{print $9}' | awk -v bk=$bk_vm '{split($0,x,"/")}{print "btrfs send -f "bk"_"x[2]".snap "$0}' | bash
btrfs sub list -o $tm | awk '$9 ~/vm-/{print $9}' | awk '{print "btrfs sub del -c "$0}' | bash

echo "complete backup @local-btrfs to remote..."
rm -r $tm
cd ..
umount $rfs_path
rm -r $rfs_path
