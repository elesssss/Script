# OpenWrt自动扩容
opkg update
opkg install parted fdisk lsblk losetup resize2fs f2fs-tools && parted -l

cat << "EOF" > /etc/uci-defaults/70-rootpt-resize
if type fdisk > /dev/null && type lsblk > /dev/null && type parted > /dev/null; then
    ROOT_BLK="$(fdisk -l 2>/dev/null | awk '/^\/dev/{print $1}' | tail -n 2 | head -n 1)"
    ROOT_DISK="$(fdisk -l 2>/dev/null | awk '/^\/dev/{print $1}' | tail -n 2 | head -n 1 | sed 's/[0-9]*$//')"
    ROOT_PART="${ROOT_BLK##*[^0-9]}"
    FSTYPE="$(lsblk -f | awk '/loop/{print $2}')" # 检查文件系统类型并扩容
    LOOP="$(df -Th | grep loop | awk '{print $1}')" # 获取loop设备偏移量
    echo 请输入 yes
    echo 请输入 yes
    echo 请输入 yes
    parted -f "${ROOT_DISK}" resizepart "${ROOT_PART}" 100% || {
        echo "分区扩展失败!"
        exit 1
    }
    if [ -z "$LOOP" ]; then
        reboot
    elif [ "$LOOP" = "/dev/loop0" ] && [ "$FSTYPE" = "ext4" ]; then
        reboot
    elif [ "$LOOP" = "/dev/loop0" ] && [ "$FSTYPE" = "f2fs" ]; then
        sh /etc/uci-defaults/80-rootpt-resize
    fi
fi
EOF
cat << "EOF" > /etc/uci-defaults/80-rootpt-resize
if type losetup > /dev/null && type resize2fs > /dev/null && type resize.f2fs > /dev/null && type df > /dev/null; then
    ROOT_BLK="$(fdisk -l 2>/dev/null | awk '/^\/dev/{print $1}' | tail -n 2 | head -n 1)"
    OFFSET="$(losetup | awk '/\/dev\/loop/{print $3}')" # 获取loop设备偏移量
    FSTYPE="$(lsblk -f | awk '/loop/{print $2}')" # 检查文件系统类型并扩容
    LOOP="$(df -Th | grep loop | awk '{print $1}')"

    if [ "$LOOP" = "/dev/loop0" ] && [ "$FSTYPE" = "f2fs" ]; then
        LOOP="/dev/loop1"
        losetup -f -o "$OFFSET" "${ROOT_BLK}" # 创建新loop设备
        mkdir -p /mnt/resize-tmp
        mount "${LOOP}" /mnt/resize-tmp
        umount "${LOOP}"
        resize.f2fs -f "${LOOP}"
    elif [ "$LOOP" = "/dev/loop0" ] && [ "$FSTYPE" = "ext4" ]; then
        resize2fs -f /dev/loop0
        exit 1
    elif [ -z "$LOOP" ]; then
        LOOP="/dev/loop0"
        losetup "${LOOP}" "${ROOT_BLK}"
        FSTYPE="$(lsblk -f | awk '/loop/{print $2}' | head -n 2)"
        if [ "$FSTYPE" = "f2fs" ]; then
            resize.f2fs -f "${LOOP}"
        elif [ "$FSTYPE" = "ext4" ]; then
            resize2fs -f "${LOOP}"
        fi
    fi
fi
reboot
EOF
cat << "EOF" >> /etc/sysupgrade.conf
/etc/uci-defaults/70-rootpt-resize
/etc/uci-defaults/80-rootpt-resize
EOF

sh /etc/uci-defaults/70-rootpt-resize
