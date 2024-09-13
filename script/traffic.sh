#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 转换函数
convert_bytes() {
    bytes=$1

    if ((bytes >= 1024 ** 4)); then
        printf "%.2f TB\n" "$(echo "scale=2; $bytes / 1024^4" | bc)"
    elif ((bytes >= 1024 ** 3)); then
        printf "%.2f GB\n" "$(echo "scale=2; $bytes / 1024^3" | bc)"
    elif ((bytes >= 1024 ** 2)); then
        echo "$((bytes / 1024 ** 2)) MB"
    elif ((bytes >= 1024)); then
        echo "$((bytes / 1024)) KB"
    else
        echo "${bytes} Bytes"
    fi
}

# 统计入站流量
rx_total=$(ifconfig | grep "RX packets" | awk '{print $5}' | awk '{ sum += $1 } END { printf "%.0f", sum }')
rx_converted=$(convert_bytes $rx_total)
echo -e "${YELLOW}入站流量：${NC}${GREEN}$rx_converted${NC}"

# 统计出站流量
tx_total=$(ifconfig | grep "TX packets" | awk '{print $5}' | awk '{ sum += $1 } END { printf "%.0f", sum }')
tx_converted=$(convert_bytes $tx_total)
echo -e "${YELLOW}出站流量: ${NC}${GREEN}$tx_converted${NC}"
