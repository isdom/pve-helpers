#!/bin/bash
# MEMO: TBD

if [ "$#" -ne 1 ]; then
    echo "usage: ./pve-br.sh <subvol name>"
    exit -1
fi

echo "start to change pve boot subvol..."

sblid=$(btrfs sub list / | awk -v sbl=$1 '$9==sbl {print $2}')

echo "作为根目录启动的子卷($1) ID为:${sblid}"
if [[ ${sblid} =~ ^[0-9]+$ ]]; then
    echo "$1 为有效子卷名称"
else
    echo "$1 不是有效子卷名称，终止执行"
    exit -1
fi

# 生成17位时间戳字符串
tm=$(date +'%Y%m%d_%H%M%S')
rfs_path=./rfs_${tm}
mkdir ${rfs_path}

# fetch rootfs disk uuid
rid=$(lsblk -no UUID $(df -P / | awk 'END{print $1}'))

# mount rootfs for next boot
mount -o subvolid=${sblid} UUID=${rid} ${rfs_path}

# 检测该子卷是否有 boot 目录，如果不存在 boot 目录，则终止设定，避免误操作
if [ -d "${rfs_path}/boot/" ]; then
    echo "$1 为有效的根目录子卷，继续执行设定"
else
    echo "$1 不是有效的根目录子卷，终止执行"
    umount ${rfs_path}
    rm -r ${rfs_path}
    exit -1
fi

echo "关键性操作：将要修改下次启动的 btrfs 根文件系统设置为: "$1
read -p "确认该操作，请输入 yes，否则输入 no：" input

# 为了避免大小写的问题，将其全部转换成小写处理
input=$(echo "${input}" | tr "[A-Z]" "[a-z]")

if [ "${input}" != "yes" ]; then
    echo "用户没有输入 yes，终止执行！"
    umount ${rfs_path}
    rm -r ${rfs_path}
    exit -1
else
    echo "用户输入 yes，将执行关键性修改"
fi

echo "DEBUG: rootfs uuid=${rid}"
btrfs sub set ${sblid} /
echo "DEBUG: btrfs default volume is: $(btrfs sub get /)"

for i in /sys /proc /run /dev; do mount --rbind "${i}" "${rfs_path}${i}"; done

# fetch efi disk id
eid=$(lsblk -no UUID $(df -P /boot/efi | awk 'END{print $1}'))
echo "mount efi part: "${eid}

mount UUID=${eid} ${rfs_path}/boot/efi

rp=$(df -P / | awk 'END{print $1}')
rdisk=${rp:0:${#rp}-1}

echo "DEBUG: grub will install to ${rdisk}"

chroot ${rfs_path} update-grub
chroot ${rfs_path} grub-install ${rdisk}

echo "change next boot rootfs to ("$1") success."
umount -lf ${rfs_path}
rm -r ${rfs_path}
