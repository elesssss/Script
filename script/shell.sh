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
    os_version=$(echo $VERSION_ID | cut -d. -f1,2)


    if [[ "${release}" == "arch" ]]; then
        echo
    elif [[ "${release}" == "kali" ]]; then
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
        echo -e "-${Red} Arch Linux ${Nc}"
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
        app=( ["cron"]="cron" ["netstat"]="net-tools" ["ip"]="iproute2" ["python3"]="python3")
    elif [[ "$release" == "almalinux" || "$release" == "fedora" || "$release" == "rocky" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        app=( ["cron"]="cronie" ["netstat"]="net-tools" ["ip"]="iproute"])
    elif [[ "$release" == "centos" || "$release" == "oracle" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        app=( ["cron"]="cronie" ["netstat"]="net-tools" ["ip"]="iproute"])
    elif [[ "$release" == "arch" ]]; then
        updates="pacman -Syu --noconfirm"
        installs="pacman -S --noconfirm"
        app=( ["cron"]="cronie" ["netstat"]="inetutils" ["ip"]="iproute2")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update"
        installs="apk add"
        app=( ["cron"]="dcron" ["netstat"]="net-tools" ["ip"]="iproute2" ["python3"]="python3")
    fi
}


install_base(){
    check_pmc
    echo -e "${Info}你的系统是${Red} $release $os_version ${Nc}"
    commands=("crontab" "netstat" "ip" "python3")
    apps=("cron" "netstat" "ip" "python3")
    install=()
    for i in ${!commands[@]}; do
        [ ! $(command -v ${commands[i]}) ] && install+=(${app[${apps[i]}]})
    done
    [ "${#install[@]}" -gt 0 ] && $updates && $installs ${install[@]}
}

check_root
install_base
