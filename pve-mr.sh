#!/bin/bash

rid=$(lsblk -no UUID $(df -P / | awk 'END{print $1}'))
mount -o subvolid=5 UUID=${rid} $1
