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

mtproxy_dir="/var/MTProxy"
mtproxy_file="${mtproxy_dir}/mtproxy.py"
mtproxy_conf="${mtproxy_dir}/config.py"
mtproxy_ini="${mtproxy_dir}/config.ini"
mtproxy_log="${mtproxy_dir}/log_mtproxy.log"


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
        apps=("openssl" "python3" "xxd" "procps" "iproute2")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        check_install="apk info -e"
        apps=("openssl" "python3" "py3-cryptography" "xxd" "procps" "iproute2")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        check_install="dnf list installed"
        apps=("openssl" "python3.11" "vim-common" "procps-ng" "iproute")
    elif [[ "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        check_install="yum list installed"
        apps=("openssl" "python3" "vim-common" "procps-ng" "iproute")
    elif [[ "$release" == "fedora" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        check_install="dnf list installed"
        apps=("openssl" "python3" "vim-common" "procps-ng" "iproute")
    fi
}

install_base(){
    check_pmc
    cmds=("openssl" "python3" "xxd" "ps" "ip")
    echo -e "${Info} 你的系统是${Red} $release $os_version ${Nc}"
    echo

    for g in "${!apps[@]}"; do
        if ! $check_install "${apps[$g]}" &> /dev/null; then
            CMDS+=(${cmds[g]})
            DEPS+=("${apps[$g]}")
        fi
    done
    
    if [ ${#DEPS[@]} -gt 0 ]; then
        echo -e "${Tip} 安装依赖列表：${Green}${CMDS[@]}${Nc} 请稍后..."
        $updates &> /dev/null
        $installs "${DEPS[@]}" &> /dev/null
    else
        echo -e "${Info} 所有依赖已存在，不需要额外安装。"
    fi

    if [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" ]]; then
        ln -sf /usr/bin/python3.11 /usr/bin/python3
    fi
}

check_root
install_base
