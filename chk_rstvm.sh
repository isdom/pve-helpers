#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "usage: ./chk_rstvm.sh <url for test online> <vmid for openwrt>"
  exit -1
fi

restart_vm(){
    vmid=$1 

    echo "[$(date)] 开始重启虚拟机 ${vmid}"

    /usr/sbin/qm stop ${vmid}
    sleep 10s

    if /usr/sbin/qm status $vmid | grep -q 'status: stopped'; then
        echo "虚拟机 $vmid 已成功关闭"
    else
       echo "虚拟机 $vmid 关闭失败"
       exit 1
    fi

    /usr/sbin/qm start $vmid

    if /usr/sbin/qm status $vmid | grep -q 'status: running'; then
       echo "虚拟机 $vmid 已成功启动"
    else
       echo "虚拟机 $vmid 启动失败"
       exit 1
    fi

    echo "[$(date)] 虚拟机 $vmid 重启完成"
}

# 检测网络连接
ping -c 1 $1 > /dev/null 2>&1
if [ $? -eq 0 ];then
    echo "[$(date)]检测网络正常"
    exit 0
else
    echo "[$(date)]检测网络连接异常, try to restart vm $2"
    restart_vm $2
fi
