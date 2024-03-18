#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 转换函数
convert_bytes() {
    bytes=$1

    if ((bytes >= 1024 ** 3)); then
        echo "$((bytes / 1024 ** 3)) GB"
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
echo -e "${YELLOW}已接收：${NC}${GREEN}$rx_converted${NC}"

# 统计出站流量
tx_total=$(ifconfig | grep "TX packets" | awk '{print $5}' | awk '{ sum += $1 } END { printf "%.0f", sum }')
tx_converted=$(convert_bytes $tx_total)
echo -e "${YELLOW}已发送: ${NC}${GREEN}$tx_converted${NC}"
