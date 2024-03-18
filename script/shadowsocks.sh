#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#       System Required: Debian/Ubuntu
#       Description: shadowsocks 管理脚本
#       Author: 你挺能闹啊🍏
#       WebSite: https://t.me/fun513
#=================================================

# 输出字体颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[0;33m"
NC="\033[0m"
GREEN_ground="\033[42;37m" # 全局绿色
RED_ground="\033[41;37m"   # 全局红色
Info="${GREEN}[信息]${NC}"
Error="${RED}[错误]${NC}"
Tip="${YELLOW}[注意]${NC}"

# 设置变量
sh_ver="v1.16.1"
FILE="/usr/local/bin/shadowsocks"
FOLDER="/etc/shadowsocks"
CONF="${FOLDER}/config.json"
dowloadURL="ipaddres:port/"

check_root() {
    if [[ $(whoami) != "root" ]]; then
        echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法 继续操作，请更换ROOT账号或使用 ${GREEN_ground}sudo su${NC} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
        exit 1
    fi
}

Installation_dependency() {
    OS=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|CentOS" | head -n 1)
    if [[ "$OS" != "Debian" && "$OS" != "Ubuntu" && "$OS" != "CentOS" ]]; then
        echo -e "${Error} 很抱歉，你的系统不受支持！${NC}"
        exit 1
    fi

    if [[ "$OS" == "CentOS" ]]; then
        CMD_INSTALL="yum install -y"
        CMD_UPGRADE="yum update -y"
        CMD_REMOVE="yum remove -y"
        systemctl stop firewalld >/dev/null 2>&1
        ${CMD_UPGRADE}
        ${CMD_INSTALL} wget xz jq openssl unzip gzip tar
    else
        CMD_INSTALL="apt install -y"
        CMD_UPGRADE="apt update -y"
        CMD_REMOVE="apt remove -y"
        CMD_AUTORRM="apt autoremove -y"
        ${CMD_UPGRADE}
        ${CMD_INSTALL} wget xz-utils jq openssl unzip gzip tar
    fi
    timedatectl set-timezone Asia/Shanghai >/dev/null 2>&1
}

sysArch() {
    uname=$(uname -m)
    if [[ "$uname" == "i386" || "$uname" == "i686" ]]; then
        arch="i686"
    elif [[ "$uname" == "armv6l" || "$uname" == "armv7l" ]]; then
        arch="arm"
    elif [[ "$uname" == "armv8l" || "$uname" == "aarch64" ]]; then
        arch="aarch64"
    else
        arch="x86_64"
    fi
}

check_installed_status() {
    if [[ ! -e ${FILE} ]]; then
        echo -e "${Error} shadowsocks 没有安装，请检查！"
        exit 1
    fi
}

check_status() {
    status=$(systemctl status shadowsocks | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
}

# 稳定源
stable_Download() {
    echo -e "${Info} 开始下载 shadowsocks ……"
    wget --no-check-certificate -N "${dowloadURL}shadowsocks-${sh_ver}.${arch}-unknown-linux-gnu.tar.xz"
    if [[ ! -e "shadowsocks-${sh_ver}.${arch}-unknown-linux-gnu.tar.xz" ]]; then
        echo -e "${Error} shadowsocks 下载失败！"
        return 1 && exit 1
    else
        tar -xvf "shadowsocks-${sh_ver}.${arch}-unknown-linux-gnu.tar.xz"
    fi
    if [[ ! -e "ssserver" ]]; then
        echo -e "${Error} shadowsocks 解压失败！"
        echo -e "${Error} shadowsocks 安装失败！"
        return 1 && exit 1
    else
        rm -rf "shadowsocks-${sh_ver}.${arch}-unknown-linux-gnu.tar.xz"
        chmod +x ssserver
        mv -f ssserver "${FILE}"
        rm -f sslocal ssmanager ssservice ssurl
        echo -e "${Info} shadowsocks 主程序下载安装完毕！"
        return 0
    fi
}

# 备用源
backup_Download() {
    new_ver=$(curl -s https://ghproxy.com/https://github.com/shadowsocks/shadowsocks-rust/releases/ | grep -o 'shadowsocks-v\([0-9.]*\)' | grep -o 'v[0-9.]*' | sed 's/\.$//' | head -n 1)
    backdowloadURL="https://ghproxy.com/github.com/shadowsocks/shadowsocks-rust/releases/download/${new_ver}/"
    echo -e "${Info} 试图请求 备用源 shadowsocks ……"
    echo -e "${Info} 开始下载 shadowsocks ……"
    wget --no-check-certificate -N "${backdowloadURL}shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    if [[ ! -e "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz" ]]; then
        echo -e "${Error} shadowsocks 下载失败！"
        exit 1
    else
        tar -xvf "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
    fi
    if [[ ! -e "ssserver" ]]; then
        echo -e "${Error} shadowsocks 解压失败！"
        echo -e "${Error} shadowsocks 安装失败！"
        exit 1
    else
        rm -rf "shadowsocks-${new_ver}.${arch}-unknown-linux-gnu.tar.xz"
        chmod +x ssserver
        mv -f ssserver "${FILE}"
        rm -f sslocal ssmanager ssservice ssurl
        echo -e "${Info} shadowsocks 主程序下载安装完毕！"
        return 0
    fi
}

Download() {
    if [[ ! -e "${FOLDER}" ]]; then
        mkdir "${FOLDER}"
        # else
        # [[ -e "${FILE}" ]] && rm -rf "${FILE}"
    fi
    stable_Download
    if [[ $? != 0 ]]; then
        backup_Download
    fi
}

Service() {
    echo '[Unit]
Description=Shadowsocks Service
Documentation=https://github.com/shadowsocks/shadowsocks-rust
After=network.target

[Service]
Type=simple
LimitNOFILE=32768
User=root
ExecStart=/usr/local/bin/shadowsocks -c /etc/shadowsocks/config.json
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target' >/etc/systemd/system/shadowsocks.service

    systemctl daemon-reload
    systemctl enable shadowsocks
    echo -e "${Info} shadowsocks 服务配置完成！"
}

Write_config() {
    cat >${CONF} <<-EOF
{
    "server": "::",
    "server_port": ${port},
    "method": "${cipher}",
    "password": "${password}",
    "mode": "tcp_and_udp",
    "timeout":300
}
EOF
}

Read_config() {
    [[ ! -e ${CONF} ]] && echo -e "${Error} shadowsocks 配置文 件不存在！" && exit 1
    port=$(cat ${CONF} | jq -r '.server_port')
    cipher=$(cat ${CONF} | jq -r '.method')
    password=$(cat ${CONF} | jq -r '.password')
}

Set_port() {
    while true; do
        echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请 手动放行相应端口！"
        echo -e "请输入 shadowsocks 端口 [10000-65535]"
        read -e -p "(默认：随机生成)：" port
        [[ -z "$port" ]] && port=$(shuf -i10000-65000 -n1)
        echo $((port + 0)) &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ $port -ge 10000 ]] && [[ $port -le 65535 ]]; then
                echo && echo "=================================="
                echo -e "端口：${RED_ground} ${port} ${NC}"
                echo "==================================" && echo
                break
            else
                echo -e "${Error}输入错误，请输入正确的端口。"
            fi
        else
            echo -e "${Error}输入错误，请输入正确的端口。"
        fi
    done
}

Set_cipher() {
    echo -e "请选择 shadowsocks 加密方式
==================================
 ${GREEN} 1.${NC} chacha20-ietf-poly1305 ${GREEN}(默认)${NC}
 ${GREEN} 2.${NC} aes-128-gcm
 ${GREEN} 3.${NC} aes-256-gcm
==================================
 ${Tip} AEAD 2022 加密（须v1.15.0及以上版本且密码需经过Base64加密）
==================================
 ${GREEN} 4.${NC} 2022-blake3-aes-128-gcm
 ${GREEN} 5.${NC} 2022-blake3-aes-256-gcm
 ${GREEN} 6.${NC} 2022-blake3-chacha20-poly1305
==================================
 ${Tip} 如需其它加密方式请手动修改配置文件 !" && echo
    read -e -p "(默认: 1. chacha20-ietf-poly1305)：" cipher
    [[ -z "${cipher}" ]] && cipher="1"
    if [[ ${cipher} == "1" ]]; then
        cipher="chacha20-ietf-poly1305"
    elif [[ ${cipher} == "2" ]]; then
        cipher="aes-128-gcm"
    elif [[ ${cipher} == "3" ]]; then
        cipher="aes-256-gcm"
    elif [[ ${cipher} == "4" ]]; then
        cipher="2022-blake3-aes-128-gcm"
    elif [[ ${cipher} == "5" ]]; then
        cipher="2022-blake3-aes-256-gcm"
    elif [[ ${cipher} == "6" ]]; then
        cipher="2022-blake3-chacha20-poly1305"
    else
        cipher="chacha20-ietf-poly1305"
    fi
    echo && echo "=================================="
    echo -e "加密：${RED_ground} ${cipher} ${NC}"
    echo "==================================" && echo
}

Set_password() {
    if [[ "$cipher" != "aes-128-gcm" && "$cipher" != "2022-blake3-aes-128-gcm" ]]; then
        echo -e "${Tip}shadowsocks密码，请留空随机生成"
        read -e -p "(请留空)：" password
        if [[ -z "${password}" ]]; then
            password=$(openssl rand -base64 32)
            echo && echo "=================================="
            echo -e "密码：${RED_ground} ${password} ${NC}"
            echo "==================================" && echo
        else
            echo -e "${Error}手动输入密码，不正确的操作！${NC}"
            exit 1
        fi
    else
        echo -e "${Tip}shadowsocks密码，请留空随机生成"
        read -e -p "(请留空)：" password
        if [[ -z "${password}" ]]; then
            password=$(openssl rand -base64 16)
            echo && echo "=================================="
            echo -e "密码：${RED_ground} ${password} ${NC}"
            echo "==================================" && echo
        else
            echo -e "${Error}手动输入密码，不正确的操作！${NC}"
            exit 1
        fi
    fi
}

Set() {
    check_installed_status
    echo && echo -e "${Tip}你要做什么？
==================================
 ${GREEN}1.${NC}  修改 端口配置
 ${GREEN}2.${NC}  修改 加密密码
==================================
 ${GREEN}3.${NC}  修改 全部配置" && echo
    read -e -p "(默认：取消)：" modify
    [[ -z "${modify}" ]] && echo -e "${Info}已取消..." && exit 1
    if [[ "${modify}" == "1" ]]; then
        Read_config
        Set_port
        password=${password}
        cipher=${cipher}
        Write_config
        Restart
    elif [[ "${modify}" == "2" ]]; then
        Read_config
        Set_cipher
        Set_password
        port=${port}
        password=${password}
        Write_config
        Restart
    elif [[ "${modify}" == "3" ]]; then
        Read_config
        Set_port
        Set_cipher
        Set_password
        Write_config
        Restart
    else
        echo -e "${Error} 请输入正确的数字(1-5)" && exit 1
    fi
}

Install() {
    [[ -e ${FILE} ]] && echo -e "${Error} 检测到 shadowsocks 已安装！" && exit 1
    echo -e "${Info} 开始安装 依赖..."
    Installation_dependency
    echo -e "${Info} 开始下载/安装..."
    Download
    echo -e "${Info} 开始设置 配置..."
    Set_port
    Set_cipher
    Set_password
    echo -e "${Info} 开始写入 配置文件..."
    Write_config
    echo -e "${Info} 开始安装系统服务脚本..."
    Service
    echo -e "${Info} 所有步骤 安装完毕，开始启动..."
    Start
    Start_Menu
}

Start() {
    check_installed_status
    check_status
    [[ "$status" == "running" ]] && echo -e "${Info} shadowsocks 已在运行 ！" && exit 1
    systemctl start shadowsocks
    check_status
    [[ "$status" == "running" ]] && echo -e "${Info} shadowsocks 启动成功 ！"
    sleep 1s
    Start_Menu
}

Stop() {
    check_installed_status
    check_status
    [[ !"$status" == "running" ]] && echo -e "${Error} shadowsocks 没有运行，请检查！" && exit 1
    systemctl stop shadowsocks
    sleep 1s
    Start_Menu
}

Restart() {
    check_installed_status
    systemctl restart shadowsocks
    echo -e "${Info} shadowsocks 重启中... "
    sleep 1s
    Start_Menu
}

Uninstall() {
    check_installed_status
    echo -e "${Tip}确定要卸载 shadowsocks ? (y/N)"
    echo
    read -e -p "(默认：n)：" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
        check_status
        [[ "$status" == "running" ]] && systemctl stop shadowsocks
        systemctl disable shadowsocks
        rm -rf "${FOLDER}"
        rm -rf "${FILE}"
        rm -f /etc/systemd/system/shadowsocks.service
        echo && echo -e "${Info}shadowsocks 卸载完成！" && echo
    else
        echo && echo -e "${Info}卸载已取消..." && echo
    fi
    sleep 1s
    Start_Menu
}

getipv4() {
    ipv4=$(wget -qO- -4 -t1 -T2 ipinfo.io/ip)
    if [[ -z "${ipv4}" ]]; then
        ipv4=$(wget -qO- -4 -t1 -T2 api.ip.sb/ip)
        if [[ -z "${ipv4}" ]]; then
            ipv4=$(wget -qO- -4 -t1 -T2 members.3322.org/dyndns/getip)
            if [[ -z "${ipv4}" ]]; then
                ipv4="IPv4_Error"
            fi
        fi
    fi
}

getipv6() {
    ipv6=$(wget -qO- -6 -t1 -T2 ifconfig.co)
    if [[ -z "${ipv6}" ]]; then
        ipv6="IPv6_Error"
    fi
}

get_country_emoji() {
    ip=$1
    country_code=$(curl -s https://ipinfo.io/ | grep country | cut -d '"' -f 4)

    case $country_code in
    CN) emoji="%F0%9F%87%A8%F0%9F%87%B3" ;;
    US) emoji="%F0%9F%87%BA%F0%9F%87%B8" ;;
    HK) emoji="%F0%9F%87%AD%F0%9F%87%B0" ;;
    TW) emoji="%F0%9F%87%B9%F0%9F%87%BC" ;;
    MO) emoji="%F0%9F%87%B2%F0%9F%87%B4" ;;
    JP) emoji="%F0%9F%87%AF%F0%9F%87%B5" ;;
    KR) emoji="%F0%9F%87%B0%F0%9F%87%B7" ;;
    GB) emoji="%F0%9F%87%AC%F0%9F%87%A7" ;;
    FR) emoji="%F0%9F%87%AB%F0%9F%87%B7" ;;
    DE) emoji="%F0%9F%87%A9%F0%9F%87%AA" ;;
    IT) emoji="%F0%9F%87%AE%F0%9F%87%B9" ;;
    ES) emoji="%F0%9F%87%AA%F0%9F%87%B8" ;;
    CA) emoji="%F0%9F%87%A8%F0%9F%87%A6" ;;
    AU) emoji="%F0%9F%87%A6%F0%9F%87%BA" ;;
    BR) emoji="%F0%9F%87%A7%F0%9F%87%B7" ;;
    RU) emoji="%F0%9F%87%B7%F0%9F%87%BA" ;;
    IN) emoji="%F0%9F%87%AE%F0%9F%87%B3" ;;
    SA) emoji="%F0%9F%87%B8%F0%9F%87%A6" ;;
    ZA) emoji="%F0%9F%87%BF%F0%9F%87%A6" ;;
    AR) emoji="%F0%9F%87%A6%F0%9F%87%B7" ;;
    CA) emoji="%F0%9F%87%A8%F0%9F%87%A6" ;;
    AU) emoji="%F0%9F%87%A6%F0%9F%87%BA" ;;
    BR) emoji="%F0%9F%87%A7%F0%9F%87%B7" ;;
    RU) emoji="%F0%9F%87%B7%F0%9F%87%BA" ;;
    IN) emoji="%F0%9F%87%AE%F0%9F%87%B3" ;;
    SA) emoji="%F0%9F%87%B8%F0%9F%87%A6" ;;
    ZA) emoji="%F0%9F%87%BF%F0%9F%87%A6" ;;
    AR) emoji="%F0%9F%87%A6%F0%9F%87%B7" ;;
    CL) emoji="%F0%9F%87%A6%F0%9F%87%B1" ;;
    CO) emoji="%F0%9F%87%A8%F0%9F%87%B4" ;;
    PE) emoji="%F0%9F%87%B5%F0%9F%87%AA" ;;
    VE) emoji="%F0%9F%87%BB%F0%9F%87%AA" ;;
    EC) emoji="%F0%9F%87%AA%F0%9F%87%A8" ;;
    MX) emoji="%F0%9F%87%B2%F0%9F%87%BD" ;;
    CA) emoji="%F0%9F%87%A8%F0%9F%87%A6" ;;
    AU) emoji="%F0%9F%87%A6%F0%9F%87%BA" ;;
    BR) emoji="%F0%9F%87%A7%F0%9F%87%B7" ;;
    RU) emoji="%F0%9F%87%B7%F0%9F%87%BA" ;;
    IN) emoji="%F0%9F%87%AE%F0%9F%87%B3" ;;
    SA) emoji="%F0%9F%87%B8%F0%9F%87%A6" ;;
    ZA) emoji="%F0%9F%87%BF%F0%9F%87%A6" ;;
    AR) emoji="%F0%9F%87%A6%F0%9F%87%B7" ;;
    CL) emoji="%F0%9F%87%A6%F0%9F%87%B1" ;;
    CO) emoji="%F0%9F%87%A8%F0%9F%87%B4" ;;
    PE) emoji="%F0%9F%87%B5%F0%9F%87%AA" ;;
    VE) emoji="%F0%9F%87%BB%F0%9F%87%AA" ;;
    EC) emoji="%F0%9F%87%AA%F0%9F%87%A8" ;;
    MX) emoji="%F0%9F%87%B2%F0%9F%87%BD" ;;
    *) emoji="%F0%9F%87%B4%F0%9F%87%B4" ;; # Use a question mark emoji for unknown countries
    esac
    echo "$emoji"
}

urlsafe_base64() {
    date=$(echo -n "$1" | base64 | sed ':a;N;s/\n/ /g;ta' | sed 's/ //g;s/=//g;s/+/-/g;s/\//_/g')
    echo -e "${date}"
}

Link_QR() {
    if [[ "${ipv4}" != "IPv4_Error" ]]; then
        country_emoji=$(get_country_emoji "${ipv4}")
        SSbase64=$(urlsafe_base64 "${cipher}:${password}")
        SSurl="ss://${SSbase64}@${ipv4}:${port}#${country_emoji}"
        link_ipv4=" 链接  [IPv4]：${RED}${SSurl}${NC}"
    fi
    if [[ "${ipv6}" != "IPv6_Error" ]]; then
        country_emoji=$(get_country_emoji "${ipv6}")
        SSbase64=$(urlsafe_base64 "${cipher}:${password}")
        SSurl="ss://${SSbase64}@${ipv6}:${port}#${country_emoji}"
        link_ipv6=" 链接  [IPv6]：${RED}${SSurl}${NC}"
    fi
}

View() {
    check_installed_status
    Read_config
    getipv4
    getipv6
    Link_QR
    clear && echo
    echo -e "shadowsocks 配置："
    echo -e "——————————————————————————————————"
    [[ "${ipv4}" != "IPv4_Error" ]] && echo -e " 地址：${GREEN}${ipv4}${NC}"
    [[ "${ipv6}" != "IPv6_Error" ]] && echo -e " 地址：${GREEN}${ipv6}${NC}"
    echo -e " 端口：${GREEN}${port}${NC}"
    echo -e " 密码：${GREEN}${password}${NC}"
    echo -e " 加密：${GREEN}${cipher}${NC}"
    echo -e "——————————————————————————————————"
    [[ ! -z "${link_ipv4}" ]] && echo -e "${link_ipv4}"
    [[ ! -z "${link_ipv6}" ]] && echo -e "${link_ipv6}"
    echo -e "——————————————————————————————————"
    Before_Start_Menu
}

Status() {
    echo -e "${Info} 获取 shadowsocks 活动日志 ……"
    echo -e "${Tip} 返回主菜单请按 q ！"
    systemctl status shadowsocks
    Start_Menu
}

Before_Start_Menu() {
    echo && echo -n -e "${yellow}* 按回车返回主菜单 *${plain}" && read temp
    Start_Menu
}

Start_Menu() {
    clear
    check_root
    sysArch
    action=$1
    clear && echo -e "==================================
shadowsocks 管理脚本 ${RED}[${sh_ver}]${NC}
    作者: ${GREEN}你挺能闹啊${NC}🍏
 群组: ${GREEN}https://t.me/fun513${NC}
==================================
 ${GREEN} 1.${NC} 安装 shadowsocks
 ${GREEN} 2. ${RED}卸载 shadowsocks${NC}
——————————————————————————————————
 ${GREEN} 3.${NC} 启动 shadowsocks
 ${GREEN} 4.${NC} 停止 shadowsocks
 ${GREEN} 5.${NC} 重启 shadowsocks
——————————————————————————————————
 ${GREEN} 6.${NC} 修改 配置信息
 ${GREEN} 7.${NC} 查看 配置信息
 ${GREEN} 8.${NC} 查看 运行状态
——————————————————————————————————
 ${GREEN} 0.${NC} 退出脚本
==================================" && echo
    if [[ -e ${FILE} ]]; then
        check_status
        if [[ "$status" == "running" ]]; then
            echo -e " 当前状态：${GREEN}已安装${NC} 并 ${GREEN}已启动${NC}"
            Read_config
            getipv4
            getipv6
            Link_QR
            echo
            echo -e "shadowsocks 配置："
            echo -e "——————————————————————————————————"
            [[ "${ipv4}" != "IPv4_Error" ]] && echo -e " 地址：${GREEN}${ipv4}${NC}"
            [[ "${ipv6}" != "IPv6_Error" ]] && echo -e " 地址：${GREEN}${ipv6}${NC}"
            echo -e " 端口：${GREEN}${port}${NC}"
            echo -e " 密码：${GREEN}${password}${NC}"
            echo -e " 加密：${GREEN}${cipher}${NC}"
            echo -e "——————————————————————————————————"
            [[ ! -z "${link_ipv4}" ]] && echo -e "${link_ipv4}"
            [[ ! -z "${link_ipv6}" ]] && echo -e "${link_ipv6}"
            echo -e "——————————————————————————————————"
        else
            echo -e " 当前状态：${GREEN}已安装${NC} 但 ${RED}未启动${NC}"
        fi
    else
        echo -e " 当前状态：${RED}未安装${NC}"
    fi
    echo
    read -e -p " 请输入数字 [0-8]：" num
    case "$num" in
    1)
        Install
        ;;
    2)
        Uninstall
        ;;
    3)
        Start
        ;;
    4)
        Stop
        ;;
    5)
        Restart
        ;;
    6)
        Set
        ;;
    7)
        View
        ;;
    8)
        Status
        ;;
    0)
        echo
        exit 1
        ;;
    *)
        echo -e "${Error}请输入正确数字 [0-8]${NC}"
        echo
        exit 1
        ;;
    esac
}
Start_Menu
