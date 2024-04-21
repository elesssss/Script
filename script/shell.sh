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
        echo -e "${Error}请执行 ${Green}sudo -i${Nc} 后以${Green}root${Nc}权限执行此脚本！"
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

    os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

    if [[ "${release}" == "arch" ]]; then
        echo ""
    elif [[ "${release}" == "kali" ]]; then
        echo ""
    elif [[ "${release}" == "centos" ]]; then
        if [[ ${os_version} -lt 7 ]]; then
            echo -e "${Error} 请使用 CentOS 7 或更高版本！" && exit 1
        fi
    elif [[ "${release}" == "ubuntu" ]]; then
        if [[ ${os_version} -lt 20 ]]; then
            echo -e "${Error} 请使用 Ubuntu 20.04 或更高版本！" && exit 1
        fi
    elif [[ "${release}" == "fedora" ]]; then
        if [[ ${os_version} -lt 36 ]]; then
            echo -e "${Error} 请使用 Fedora 36 或更高版本！" && exit 1
        fi
    elif [[ "${release}" == "debian" ]]; then
        if [[ ${os_version} -lt 10 ]]; then
            echo -e "${Error} 请使用 Debian 10 或更高版本！" && exit 1
        fi
    elif [[ "${release}" == "almalinux" ]]; then
        if [[ ${os_version} -lt 9 ]]; then
            echo -e "${Error} 请使用 AlmaLinux 9 或更高版本！" && exit 1
        fi
    elif [[ "${release}" == "rocky" ]]; then
        if [[ ${os_version} -lt 9 ]]; then
            echo -e "${Error} 请使用 Rocky Linux 9 或更高版本！" && exit 1
        fi
    elif [[ "${release}" == "oracle" ]]; then
        if [[ ${os_version} -lt 8 ]]; then
            echo -e "${Error} 请使用 Oracle Linux 8 或更高版本！" && exit 1
        fi
    elif [[ "${release}" == "alpine" ]]; then
        if [[ ${os_version} -lt 3.8 ]]; then
            echo -e "${Error} 请使用 Alpine Linux 3.8 或更高版本！" && exit 1
        fi
    else
        echo -e "${Error} 抱歉，此脚本不支持您的操作系统。"
        echo "${Info} 请确保您使用的是以下支持的操作系统之一："
        echo "- Ubuntu 20.04+"
        echo "- Debian 10+"
        echo "- CentOS 7+"
        echo "- Fedora 36+"
        echo "- Arch Linux"
        echo "- Kali"
        echo "- AlmaLinux 9+"
        echo "- Rocky Linux 9+"
        echo "- Oracle Linux 8+"
        echo "- Alpine Linux 3.8"
        exit 1
    fi
}

install_base(){
    check_release
    if [[ "$release" == "debian" || "$release" == "ubuntu" || "$release" == "kali" ]]; then
        update="apt update -y"
        install="apt install -y"
    elif [[ "$release" == "almalinux" || "$release" == "fedora" || "$release" == "rocky" ]]; then
        update="dnf update -y"
        install="dnf install -y"
    elif [[ "$release" == "centos" || "$release" == "oracle" ]]; then
        update="yum update -y"
        install="yum install -y"
    elif [[ "$release" == "arch" ]]; then
        update="pacman -Syu --noconfirm"
        install="pacman -S --noconfirm"
    elif [[ "$release" == "alpine" ]]; then
        update="apk update -q"
        install="apk add -q"
    fi

    commands=("netstat")
    apps=("net-tools")
    install=()
    for i in ${!commands[@]}; do
        [ ! $(command -v ${commands[i]}) ] && install+=(${apps[i]})
    done
    [ "${#install[@]}" -gt 0 ] && $update && $install ${install[@]}
}
