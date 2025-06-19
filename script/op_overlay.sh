# OpenWrt自动扩容
opkg update
opkg install parted fdisk losetup resize2fs f2fs-tools && parted -l

cat << "EOF" > /etc/uci-defaults/70-rootpt-resize
if [ ! -e /etc/rootpt-resize ] && type parted >/dev/null && lock -n /var/lock/root-resize; then
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
    touch /etc/rootpt-resize
    reboot
fi
EOF
cat << "EOF" > /etc/uci-defaults/80-rootpt-resize
if [ ! -e /etc/rootfs-resize ] && [ -e /etc/rootpt-resize ] && type losetup > /dev/null && type resize2fs > /dev/null && type resize.f2fs > /dev/null && type df > /dev/null && lock -n /var/lock/root-resize; then
    ROOT_BLK="$(fdisk -l 2>/dev/null | awk '/^\/dev/{print $1}' | tail -n 2 | head -n 1)"
    OFFSET="$(losetup | awk '/\/dev\/loop/{print $3}')" # 获取loop设备偏移量
    FSTYPE="$(df -Th | grep loop | awk '{print $2}')" # 检查文件系统类型并扩容

    if [ -n "$OFFSET" ] && [ "$FSTYPE" = "f2fs" ]; then
        LOOP="/dev/loop1"
        losetup -f -o "$OFFSET" "${ROOT_BLK}" # 创建新loop设备
        mkdir -p /mnt/resize-tmp
        mount "${LOOP}" /mnt/resize-tmp
        umount "${LOOP}"
        resize.f2fs -f "${LOOP}"
    elif [ -n "$OFFSET" ] && [ "$FSTYPE" = "ext4" ]; then
        resize2fs -f /dev/loop0
        exit 1
    else
        LOOP="/dev/loop0"
        losetup "${LOOP}" "${ROOT_BLK}"
        FSTYPE="$(df -Th | grep loop | awk '{print $2}')"
        if [ "$FSTYPE" = "f2fs" ]; then
            resize.f2fs -f "${LOOP}"
        elif [ "$FSTYPE" = "ext4" ]; then
            resize2fs -f "${LOOP}"
        fi
    fi
fi
touch /etc/rootfs-resize
reboot
EOF
cat << "EOF" >> /etc/sysupgrade.conf
/etc/uci-defaults/70-rootpt-resize
/etc/uci-defaults/80-rootpt-resize
EOF

sh /etc/uci-defaults/70-rootpt-resize
