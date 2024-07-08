#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "usage: ./rs-localbtrfs.sh <localbtrfs & vm snapshot dir> <restore path>"
  exit -1
fi

# 检测还原路径是否存在
if [ -d "$2" ]; then
    echo "$2 目标路径存在"
else
    echo "$2 目标路径不存在，终止还原"
    exit -1
fi

if [ ! -d "$2/@local-btrfs" ]; then
    echo "$2 下不存在 @local-btrfs 子卷，继续还原"
else
    echo "$2 下已经存在 @local-btrfs 子卷，终止还原"
    exit -1
fi

if [ ! -d "$2/@local-btrfs-ro" ]; then
    echo "$2 下不存在 @local-btrfs-ro 子卷，继续还原"
else
    echo "$2 下已经存在 @local-btrfs-ro 子卷，终止还原"
    exit -1
fi

lb_cnt=$(ls $1 -l | awk '$9 ~/local_btrfs.snap$/{print $9}'| wc -l)
if [ ${lb_cnt} -eq 1 ];then
    echo "$1 包含有效的 local_btrfs 存储"
else
    echo "$1 不包含有效 local_btrfs 存储，终止还原"
    exit -1
fi

lb_snap=$(ls $1 -l | awk '$9 ~/local_btrfs.snap$/{print $9}')
echo "restore ${lb_snap} to $2"
btrfs receive -f $1/${lb_snap} $2

if [ -d "$2/@local-btrfs-ro" ]; then
    echo "restore read-only snapshot $2/@local-btrfs-ro success"
else
    echo "restore read-only snapshot $2/@local-btrfs-ro failed, Abort!"
    exit -1
fi

btrfs sub snap $2/@local-btrfs-ro $2/@local-btrfs

if [ $? -eq 0 ];then
    echo "create rw snap: $2/@local-btrfs for $2/@local-btrfs-ro success"
else
    echo "create rw snap: $2/@local-btrfs for $2/@local-btrfs-ro failed, Abort!"
    exit -1
fi

btrfs sub del -c $2/@local-btrfs-ro

ls $1 -l | awk '$9 ~/_vm-/{print $9}' | awk -v pf=$1 -v dst=$2 '{print "btrfs receive -f "pf"/"$0" "dst}' | bash
ls $2 -l | awk '$9 ~/^vm-/{print $9}' | awk -v pf=$2 '{split($0,x,"-")}{print "btrfs sub snap "pf"/"$0" "pf"/@local-btrfs/images/"x[2]"/"$0}' | bash
ls $2 -l | awk -v pf=$2 '$9 ~/^vm-/{print "btrfs sub del -c "pf"/"$9}' | bash

echo "restore all vm snapshot success"
