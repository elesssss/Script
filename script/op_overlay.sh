# Configure startup scripts
opkg update
opkg install parted fdisk lsblk losetup resize2fs f2fs-tools && parted -l

cat << "EOF" > /etc/uci-defaults/70-rootpt-resize
if [ ! -e /etc/rootpt-resize ] && type parted >/dev/null && lock -n /var/lock/root-resize; then
    #touch /etc/rootpt-resize
    ROOT_BLK="$(fdisk -l 2>/dev/null | awk '/^\/dev/{print $1}' | tail -n 2 | head -n 1)"
    ROOT_DISK="$(fdisk -l 2>/dev/null | awk '/^\/dev/{print $1}' | tail -n 2 | head -n 1 | sed 's/[0-9]*$//')"
    ROOT_PART="${ROOT_BLK##*[^0-9]}"
    echo 请输入 yes
    echo 请输入 yes
    echo 请输入 yes
    parted -f "${ROOT_DISK}" resizepart "${ROOT_PART}" 100% || {
        echo "分区扩展失败!"
        exit 1
    }
    reboot
fi
EOF

cat << "EOF" > /etc/uci-defaults/80-rootpt-resize
ROOT_BLK="$(fdisk -l 2>/dev/null | awk '/^\/dev/{print $1}' | tail -n 2 | head -n 1)"
# 获取loop设备偏移量
OFFSET="$(losetup | awk '/\/dev\/loop0/{print $3}')"
if [ -n "$OFFSET" ] && [ "$OFFSET" -gt 0 ]; then
    # 创建新loop设备
    losetup -f -o "$OFFSET" "${ROOT_BLK}"
    mkdir -p /mnt/resize-tmp
    mount /dev/loop1 /mnt/resize-tmp
    umount /dev/loop1
else
    losetup /dev/loop1 "${ROOT_BLK}"
fi
# 检查文件系统类型并扩容
FSTYPE="$(lsblk -f | awk '/loop1/{print $2}')"
if [ "$FSTYPE" = "f2fs" ]; then
    if ! resize.f2fs -f /dev/loop1; then
        echo "f2fs扩容失败!"
        exit 1
    fi
elif [ "$FSTYPE" = "ext4" ]; then
    if ! resize2fs -f /dev/loop1; then
        echo "ext4扩容失败!"
        exit 1
    fi
fi
reboot
EOF
cat << "EOF" >> /etc/sysupgrade.conf
/etc/uci-defaults/70-rootpt-resize
/etc/uci-defaults/80-rootpt-resize
EOF

sh /etc/uci-defaults/70-rootpt-resize
