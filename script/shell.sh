#!/bin/bash

# 颜色定义
Green="\033[32m" # 绿色
Red="\033[31m" # 红色
Yellow="\033[0;33m" # 黄色
Blue="\033[0;34m" # 蓝色
Plain="\033[0m" # 重置颜色
Green_background="\033[42;37m" # 绿底
Red_background="\033[41;37m" # 红底
Yellow_globa="\033[43;37m" # 黄底
Blue_globa="\033[44;37m" # 蓝底

# 状态提示
Info="${Green}[信息]${Plain}"
Error="${Red}[错误]${Plain}"
Warning="${Yellow}[警告]${Plain}"
Success="${Green}[成功]${Plain}"
Tip="${Yellow}[提示]${Plain}"

# 检查是否为root用户
check_root(){
    if [ "$(id -u)" != "0" ]; then
        echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_globa}sudo -i${Plain} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
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

    if [[ "${release}" == "ol" ]]; then
        release=oracle
    elif [[ ! "${release}" =~ ^(kali|centos|ubuntu|fedora|debian|almalinux|rocky|alpine)$ ]]; then
        echo -e "${Error} 抱歉，此脚本不支持您的操作系统。"
        echo -e "${Info} 请确保您使用的是以下支持的操作系统之一："
        echo -e "-${Red} Ubuntu ${Plain}"
        echo -e "-${Red} Debian ${Plain}"
        echo -e "-${Red} CentOS ${Plain}"
        echo -e "-${Red} Fedora ${Plain}"
        echo -e "-${Red} Kali ${Plain}"
        echo -e "-${Red} AlmaLinux ${Plain}"
        echo -e "-${Red} Rocky Linux ${Plain}"
        echo -e "-${Red} Oracle Linux ${Plain}"
        echo -e "-${Red} Alpine Linux ${Plain}"
        exit 1
    fi
}

check_pmc(){
    check_release
    if [[ "$release" == "debian" || "$release" == "ubuntu" || "$release" == "kali" ]]; then
        updates="apt update -y"
        installs="apt install -y"
        apps=("openssl" "python3" "xxd" "procps" "iproute2")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        apps=("openssl" "python3" "py3-cryptography" "xxd" "procps" "iproute2")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("openssl" "python3.11" "vim-common" "procps-ng" "iproute")
    elif [[ "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        apps=("openssl" "python3" "vim-common" "procps-ng" "iproute")
    elif [[ "$release" == "fedora" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("openssl" "python3" "vim-common" "procps-ng" "iproute")
    fi
}

install_base(){
    check_pmc
    cmds=("openssl" "python3" "xxd" "ps" "ip")
    echo -e "${Info} 你的系统是${Red} $release $os_version ${Plain}"
    echo

    for i in "${!cmds[@]}"; do
        if ! which "${cmds[i]}" &>/dev/null; then
            DEPS+=("${apps[i]}")
        fi
    done
    
    if [ ${#DEPS[@]} -gt 0 ]; then
        echo -e "${yellow}[Tip]安装依赖列表：${Green}${DEPS[*]}${Plain} 请稍后..."
        $updates 
        $installs "${DEPS[@]}" 
    else
        echo -e "${Info} 所有依赖已存在，不需要额外安装。"
    fi
}

check_root
install_base
