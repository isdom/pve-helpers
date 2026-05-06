#!/bin/bash

# ---------- 自动检测 EFI 系统分区 ----------
EFI_PART=""

# 方法1：通过 ESP 分区类型 GUID 查找（最准确）
# GUID: C12A7328-F81F-11D2-BA4B-00A0C93EC93B
EFI_PART=$(lsblk -p -o PATH,PARTTYPE 2>/dev/null | \
           grep -i 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B' | \
           awk '{print $1}' | head -n1)

# 方法2：若方法1失败，则从常见挂载点获取
if [ -z "$EFI_PART" ]; then
    for mp in /boot/efi /boot /efi; do
        EFI_PART=$(findmnt -n -o SOURCE --target "$mp" 2>/dev/null)
        [ -n "$EFI_PART" ] && break
    done
fi

# 如果仍未找到，退出并报错
if [ -z "$EFI_PART" ]; then
    echo "错误：未找到 EFI 系统分区。请确认系统是否以 UEFI 模式启动。"
    exit 1
fi

echo "检测到 EFI 分区：$EFI_PART"

# ---------- 执行备份 ----------
BACKUP_DIR="/tmp"

# 制作 EFI 镜像
echo "正在备份 $EFI_PART 到 $BACKUP_DIR/efi.img ..."
sudo dd if="$EFI_PART" of="$BACKUP_DIR/efi.img" bs=4M status=progress

# 生成校验文件（读取分区前 4 MiB 的 MD5）
echo "正在生成分区前 4 MiB 的校验和..."
sudo dd if="$EFI_PART" bs=4M count=1 status=none | md5sum | sudo tee "$BACKUP_DIR/efi_checksum_before.txt" > /dev/null

echo "备份完成。"
