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

check_root(){
    if [ "$(id -u)" != "0" ]; then
        echo -e " ${Error} 请使用${Red} CentOS 8${Nc} 或更高版本" && exit 1
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
        if [[ ${os_version} -lt 8 ]]; then
            echo -e " ${Error} 请使用 CentOS 8 或更高版本" && exit 1
        fi
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
    elif [[ "${release}" == "oracle" ]]; then
        echo
    elif [[ "${release}" == "alpine" ]]; then
        echo
    else
        echo -e "${Error} 抱歉，此脚本不支持您的操作系统。"
        echo -e "${Info} 请确保您使用的是以下支持的操作系统之一："
        echo -e "-${Red} Ubuntu${Nc} "
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
        apps=("cron" "net-tools" "iproute2" "python3" "xxd")
    elif [[ "$release" == "almalinux" || "$release" == "fedora" || "$release" == "rocky" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("cronie" "net-tools" "iproute" "python3.11" "xxd")
    elif [[ "$release" == "centos" || "$release" == "oracle" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        apps=("cronie" "net-tools" "iproute" "python3.11" "vim-common")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        apps=("dcron" "net-tools" "iproute2" "python3" "xxd")
    fi
}

install_base(){
    check_pmc
    cmds=("crontab" "netstat" "ip" "python3" "xxd")
    echo -e "${Info} 你的系统是${Red} $release $os_version ${Nc}"
    for g in "${!cmds[@]}"; do
        if [ ! $(type -p ${cmds[g]}) ]; then
            CMDS+=(${cmds[g]})
            DEPS+=(${apps[g]})
        fi
    done

    if [ "${#DEPS[@]}" -ge 1 ]; then
        echo -e "${Info} 安装依赖列表：${Green}${CMDS[@]}${Nc}"
        $updates >/dev/null 2>&1
        $installs ${DEPS[@]} >/dev/null 2>&1
    else
        echo -e "${Info} 所有依赖已存在，不需要额外安装。"
    fi
}

check_root
install_base
