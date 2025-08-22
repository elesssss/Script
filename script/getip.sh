#!/bin/bash

Red="\033[31m" # 红色
Green="\033[32m" # 绿色
Yellow="\033[33m" # 黄色
Blue="\033[34m" # 蓝色
Nc="\033[0m" # 重置颜色
Red_globa="\033[41;37m" # 红底白字
Green_globa="\033[42;37m" # 绿底白字
Yellow_globa="\033[43;37m" # 黄底白字
Blue_globa="\033[44;37m" # 蓝底白字
Info="${Green}[信息]${Nc}"
Error="${Red}[错误]${Nc}"
Tip="${Yellow}[提示]${Nc}"
start_time=$(date +%s) # 记录开始时间

# 检查是否为root用户
check_root(){
    if [ "$(id -u)" != "0" ]; then
        echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_globa}sudo -i${Nc} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
        exit 1
    fi
}

get_public_ip(){
    InFaces=($(ls /sys/class/net | grep -E '^(eth|ens|eno|esp|enp|vif)'))
    IP_API=(
        "api64.ipify.org"
        "ip.sb"
        "ifconfig.me"
        "icanhazip.com"
    )

    for iface in "${InFaces[@]}"; do
        for ip_api in "${IP_API[@]}"; do
            IPv4=$(curl -s4 --max-time 2 --interface "$iface" "$ip_api")
            IPv6=$(curl -s6 --max-time 2 --interface "$iface" "$ip_api")

            if [[ -n "$IPv4" || -n "$IPv6" ]]; then # 检查是否获取到IP地址
                break 2 # 获取到任一IP类型停止循环
            fi
        done
    done
}

Echo_IP(){
    get_public_ip
    echo -e "${Info} 通过 ${Green}$iface${Nc} 获取到以下IP"
    echo -e "${Info} IPv4 是${Green} ${IPv4}${Nc}"
    echo -e "${Info} IPv6 是${Green} ${IPv6}${Nc}"
    
    end_time=$(date +%s) # 在脚本结束时记录结束时间
    duration=$((end_time - start_time)) # 计算持续时间
    echo -e "${Info} 脚本运行时间: ${Green}${duration}${Nc} 秒。"
}

main(){
    check_root
    Echo_IP
}

main
