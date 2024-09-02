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

# 版权信息
cop_info(){
    clear
    echo -e "${Green}######################################
#           ${Red}Swap 一键脚本            ${Green}#
#         作者: ${Yellow}你挺能闹啊🍏          ${Green}#
######################################${Nc}"
    echo
}

# 检查 Root 权限
check_root(){
    if [[ $(whoami) != "root" ]]; then
        echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_globa}sudo -i${Nc} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
        exit 1
    fi
}

check_ovz(){
    if [[ -d "/proc/vz" ]]; then
        echo -e "${Error} 你的VPS基于 OpenVZ，不支持！"
        exit 1
    fi
}

# 检查 Swap 文件是否存在
check_swap_file(){
    swapfile=$(swapon --show | awk 'NR>1 {print $1}')
}

add_swap(){
    check_swap_file
    if [[ -z "${swapfile}" ]]; then
        echo -e "${Tip} Swapfile 未发现，正在为其创建 swapfile..."
        echo -e "${Tip} 请输入需要添加的 swap，建议为内存的2倍！"
        read -p "swap 数值:" swapsize
        dd if=/dev/zero of=/etc/swap bs=1M count=${swapsize}
        echo "/etc/swap none swap sw 0 0" | sudo tee -a /etc/fstab
        chmod 600 /etc/swap
        mkswap /etc/swap
        swapon /etc/swap
        echo -e "${Info} swap 开启成功！虚拟内存大小 ${Green}${swapsize}MB${Nc}"
        echo
    else
        echo -e "${Error} Swapfile 已存在，swap设置失败，请先运行脚本删除 swap 后重新设置！"
        echo
    fi
}

del_swap(){
    check_swap_file
    if [[ -z "${swapfile}" ]]; then
        echo -e "${Error} Swapfile 未发现，不存在swap分区！"
        echo
    else
        swapoff ${swapfile}
        rm -f ${swapfile}
        echo -e "${Info} swap 已删除！"
        echo
    fi
}

# 开始菜单
main(){
    check_root
    check_ovz
    cop_info
    echo -e "———————————————————————————————————————
1. ${Green}添加 Swap${Nc}
2. ${Red}删除 Swap${Nc}
———————————————————————————————————————"
    echo
    read -p "请输入数字 [1-2]:" num
    until [[ "$num" =~ ^[1-2]$ ]]; do
        echo -e "${Error} 请输入正确的数字 [1-2]"
        echo
        exit 1
    done
    case "$num" in
        1)
        add_swap
        ;;
        2)
        del_swap
        ;;
    esac
}

main
