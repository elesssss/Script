#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#       System Required: Debian/Ubuntu
#       Description: shadowsocks 管理脚本
#       Author: 你挺能闹啊🍏
#       WebSite: https://t.me/fun513
#=================================================

# 颜色定义
Green="\033[32m"        # 绿色
Red="\033[31m"          # 红色
Yellow="\033[0;33m"     # 黄色
Blue="\033[0;34m"       # 蓝色
Plain="\033[0m"         # 重置颜色
Green_background="\033[42;37m"  # 绿底
Red_background="\033[41;37m"    # 红底
Yellow_globa="\033[43;37m"      # 黄底
Blue_globa="\033[44;37m"        # 蓝底

# 状态提示
Info="${Green}[信息]${Plain}"
Error="${Red}[错误]${Plain}"
Warning="${Yellow}[警告]${Plain}"
Success="${Green}[成功]${Plain}"
Tip="${Yellow}[提示]${Plain}"

# 设置变量
sh_ver="v1.24.0"
FILE="/usr/local/bin/shadowsocks"
FOLDER="/etc/shadowsocks"
CONF="${FOLDER}/config.json"
dowloadURL="http://120.79.176.207:54321/shadowsocks/"

check_root(){
    if [[ $(whoami) != "root" ]]; then
        echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background}sudo su${Plain} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
        exit 1
    fi
}

check_os(){
    if [[ -e /etc/os-release ]]; then
        . /etc/os-release
        release=$ID
    elif [[ -e /usr/lib/os-release ]]; then
        . /usr/lib/os-release
        release=$ID
    else
        echo -e "${Error} 检测系统版本失败，请联系作者！" >&2
        exit 1
    fi
    echo -e "${Info} 当前系统版本: ${Green}$release${Plain}"
}

check_pmc(){
    check_os
    if [[ "$release" == "debian" || "$release" == "ubuntu" || "$release" == "kali" || "$release" == "armbian" ]]; then
        updates="apt update -y"
        installs="apt install -y"
        apps=("wget" "xz-utils" "jq" "openssl" "unzip" "gzip" "tar")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update"
        installs="apk add --no-cache"
        apps=("wget" "xz" "jq" "openssl" "unzip" "gzip" "tar")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" || "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        apps=("wget" "xz" "jq" "openssl" "unzip" "gzip" "tar")
    elif [[ "$release" == "fedora" || "$release" == "amzn" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("wget" "xz" "jq" "openssl" "unzip" "gzip" "tar")
    elif [[ "$release" == "arch" || "$release" == "manjaro" || "$release" == "parch" ]]; then
        updates="pacman -Sy"
        installs="pacman -S --noconfirm"
        apps=("wget" "xz" "jq" "openssl" "unzip" "gzip" "tar")
    elif [[ "$release" == "opensuse" || "$release" == "opensuse-leap" || "$release" == "opensuse-tumbleweed" ]]; then
        updates="zypper refresh"
        installs="zypper install -y"
        apps=("wget" "xz" "jq" "openssl" "unzip" "gzip" "tar")
    fi
}

install_base(){
    check_pmc
    DEPS=()  # 重要：初始化数组
    cmds=("wget" "xz" "jq" "openssl" "unzip" "gzip" "tar")

    for i in "${!cmds[@]}"; do
        if ! command -v "${cmds[i]}" &>/dev/null; then
            DEPS+=("${apps[i]}")
        fi
    done
    
    if [ ${#DEPS[@]} -gt 0 ]; then
        echo -e "${Tip} 安装依赖列表：${Green}${DEPS[*]}${Plain} 请稍后..."
        $updates 
        $installs "${DEPS[@]}" 
        echo -e "${Success} 依赖安装完成！${Plain}"
    else
        echo -e "${Success} 所有依赖已存在，不需要额外安装。${Plain}"
    fi
}

sysArch(){
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

check_installed_status(){
    if [[ ! -e ${FILE} ]]; then
        echo -e "${Error} shadowsocks 没有安装，请检查！"
        return 1
    fi
    return 0
}

check_status(){
    if systemctl is-active --quiet shadowsocks 2>/dev/null; then
        status="running"
    else
        status="stopped"
    fi
}

# 稳定源
stable_Download(){
    local filename="shadowsocks-${sh_ver}.${arch}-unknown-linux-musl.tar.xz"
    echo -e "${Info} 开始下载 shadowsocks ..."
    
    if wget --no-check-certificate -q --show-progress -N "${dowloadURL}${filename}"; then
        echo -e "${Success} 下载成功！"
    else
        echo -e "${Error} shadowsocks 下载失败！"
        return 1
    fi
    
    if [[ ! -f "${filename}" ]]; then
        echo -e "${Error} 下载文件不存在！"
        return 1
    fi
    
    tar -xvf "${filename}" 2>/dev/null
    rm -f "${filename}"
    
    if [[ ! -f "ssserver" ]]; then
        echo -e "${Error} shadowsocks 解压失败！"
        return 1
    fi
    
    chmod +x ssserver
    mv -f ssserver "${FILE}"
    rm -f sslocal ssmanager ssservice ssurl 2>/dev/null
    echo -e "${Success} shadowsocks 主程序安装完成！"
    return 0
}

# 备用源
backup_Download(){
    local new_ver=$(curl -s https://ghproxy.com/https://github.com/shadowsocks/shadowsocks-rust/releases/ | grep -o 'shadowsocks-v\([0-9.]*\)' | grep -o 'v[0-9.]*' | sed 's/\.$//' | head -n 1)
    local backdowloadURL="https://ghproxy.com/github.com/shadowsocks/shadowsocks-rust/releases/download/${new_ver}/"
    local filename="shadowsocks-${new_ver}.${arch}-unknown-linux-musl.tar.xz"
    
    echo -e "${Info} 尝试从备用源下载 shadowsocks ..."
    
    if wget --no-check-certificate -q --show-progress -N "${backdowloadURL}${filename}"; then
        echo -e "${Success} 从备用源下载成功！"
    else
        echo -e "${Error} 从备用源下载失败！"
        return 1
    fi
    
    if [[ ! -f "${filename}" ]]; then
        echo -e "${Error} 下载文件不存在！"
        return 1
    fi
    
    tar -xvf "${filename}" 2>/dev/null
    rm -f "${filename}"
    
    if [[ ! -f "ssserver" ]]; then
        echo -e "${Error} shadowsocks 解压失败！"
        return 1
    fi
    
    chmod +x ssserver
    mv -f ssserver "${FILE}"
    rm -f sslocal ssmanager ssservice ssurl 2>/dev/null
    echo -e "${Success} shadowsocks 主程序安装完成！"
    return 0
}

Download(){
    if [[ ! -d "${FOLDER}" ]]; then
        mkdir -p "${FOLDER}"
    fi
    
    if ! stable_Download; then
        echo -e "${Warning} 主源下载失败，尝试备用源..."
        backup_Download || {
            echo -e "${Error} 所有下载源均失败！"
            return 1
        }
    fi
    return 0
}

Service(){
    cat >/etc/systemd/system/shadowsocks.service <<'EOF'
[Unit]
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
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocks
    echo -e "${Success} shadowsocks 服务配置完成！"
}

Write_config(){
    cat >${CONF} <<-EOF
{
    "server": "::",
    "server_port": ${port},
    "method": "${cipher}",
    "password": "${password}",
    "mode": "tcp_and_udp",
    "timeout": 300
}
EOF
    echo -e "${Success} 配置文件写入完成！"
}

Read_config(){
    if [[ ! -e ${CONF} ]]; then
        echo -e "${Error} shadowsocks 配置文件不存在！"
        return 1
    fi
    port=$(jq -r '.server_port' ${CONF} 2>/dev/null)
    cipher=$(jq -r '.method' ${CONF} 2>/dev/null)
    password=$(jq -r '.password' ${CONF} 2>/dev/null)
    
    if [[ -z "$port" || -z "$cipher" || -z "$password" ]]; then
        echo -e "${Error} 读取配置文件失败！"
        return 1
    fi
    return 0
}

Set_port(){
    while true; do
        echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
        echo -e "请输入 shadowsocks 端口 [10000-65535]"
        read -e -p "(默认：随机生成)：" port
        [[ -z "$port" ]] && port=$(shuf -i 10000-65000 -n 1)
        
        if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 10000 ]] && [[ $port -le 65535 ]]; then
            echo && echo "=================================="
            echo -e "端口：${Green} ${port} ${Plain}"
            echo "==================================" && echo
            break
        else
            echo -e "${Error}输入错误，请输入正确的端口。"
        fi
    done
}

Set_cipher(){
    echo -e "请选择 shadowsocks 加密方式"
    echo -e "=================================="
    echo -e " ${Green} 1.${Plain} chacha20-ietf-poly1305 ${Green}(默认)${Plain}"
    echo -e " ${Green} 2.${Plain} aes-128-gcm"
    echo -e " ${Green} 3.${Plain} aes-256-gcm"
    echo -e "=================================="
    echo -e " ${Tip} AEAD 2022 加密（须v1.15.0及以上版本且密码需经过Base64加密）"
    echo -e "=================================="
    echo -e " ${Green} 4.${Plain} 2022-blake3-aes-128-gcm"
    echo -e " ${Green} 5.${Plain} 2022-blake3-aes-256-gcm"
    echo -e " ${Green} 6.${Plain} 2022-blake3-chacha20-poly1305"
    echo -e "=================================="
    echo -e " ${Tip} 如需其它加密方式请手动修改配置文件 !" && echo
    
    read -e -p "(默认: 1. chacha20-ietf-poly1305)：" cipher
    [[ -z "${cipher}" ]] && cipher="1"
    
    case "${cipher}" in
        1) cipher="chacha20-ietf-poly1305" ;;
        2) cipher="aes-128-gcm" ;;
        3) cipher="aes-256-gcm" ;;
        4) cipher="2022-blake3-aes-128-gcm" ;;
        5) cipher="2022-blake3-aes-256-gcm" ;;
        6) cipher="2022-blake3-chacha20-poly1305" ;;
        *) cipher="chacha20-ietf-poly1305" ;;
    esac
    
    echo && echo "=================================="
    echo -e "加密：${Green} ${cipher} ${Plain}"
    echo "==================================" && echo
}

Set_password(){
    echo -e "${Tip} shadowsocks 密码，请留空随机生成"
    read -e -p "(请留空)：" password
    
    if [[ -z "${password}" ]]; then
        if [[ "$cipher" == "2022-blake3-aes-128-gcm" || "$cipher" == "2022-blake3-aes-256-gcm" ]]; then
            password=$(openssl rand -base64 32)
        else
            password=$(openssl rand -base64 16)
        fi
        echo && echo "=================================="
        echo -e "密码：${Green} ${password} ${Plain}"
        echo "==================================" && echo
    else
        echo -e "${Warning} 手动输入密码，不推荐！请确保密码符合要求。${Plain}"
    fi
}

Set(){
    check_installed_status || return 1
    
    echo && echo -e "${Tip} 你要做什么？"
    echo -e "=================================="
    echo -e " ${Green}1.${Plain}  修改 端口配置"
    echo -e " ${Green}2.${Plain}  修改 加密密码"
    echo -e "=================================="
    echo -e " ${Green}3.${Plain}  修改 全部配置"
    echo -e "=================================="
    read -e -p "(默认：取消)：" modify
    [[ -z "${modify}" ]] && echo -e "${Info}已取消..." && return 1
    
    case "${modify}" in
        1)
            Read_config || return 1
            Set_port
            Write_config
            Restart
            ;;
        2)
            Read_config || return 1
            Set_cipher
            Set_password
            Write_config
            Restart
            ;;
        3)
            Read_config || return 1
            Set_port
            Set_cipher
            Set_password
            Write_config
            Restart
            ;;
        *)
            echo -e "${Error} 请输入正确的数字(1-3)" && return 1
            ;;
    esac
}

Install(){
    if [[ -e ${FILE} ]]; then
        echo -e "${Error} 检测到 shadowsocks 已安装！"
        return 1
    fi
    
    echo -e "${Info} 开始安装依赖..."
    install_base
    sysArch
    echo -e "${Info} 系统架构: ${Green}${arch}${Plain}"
    
    echo -e "${Info} 开始下载/安装..."
    Download || return 1
    
    echo -e "${Info} 开始设置配置..."
    Set_port
    Set_cipher
    Set_password
    
    echo -e "${Info} 开始写入配置文件..."
    Write_config
    
    echo -e "${Info} 开始安装系统服务脚本..."
    Service
    
    echo -e "${Info} 所有步骤安装完毕，开始启动..."
    Start
}

Start(){
    check_installed_status || return 1
    check_status
    if [[ "$status" == "running" ]]; then
        echo -e "${Info} shadowsocks 已在运行！"
        return 0
    fi
    
    systemctl start shadowsocks
    sleep 2
    
    check_status
    if [[ "$status" == "running" ]]; then
        echo -e "${Success} shadowsocks 启动成功！"
    else
        echo -e "${Error} shadowsocks 启动失败！请检查日志: journalctl -u shadowsocks -f"
    fi
}

Stop(){
    check_installed_status || return 1
    check_status
    if [[ "$status" != "running" ]]; then
        echo -e "${Error} shadowsocks 没有运行！"
        return 1
    fi
    
    systemctl stop shadowsocks
    check_status
    if [[ "$status" == "stopped" ]]; then
        echo -e "${Success} shadowsocks 已停止！"
    fi
}

Restart(){
    check_installed_status || return 1
    echo -e "${Info} shadowsocks 重启中... "
    systemctl restart shadowsocks
    sleep 2
    check_status
    if [[ "$status" == "running" ]]; then
        echo -e "${Success} shadowsocks 重启成功！"
    else
        echo -e "${Error} shadowsocks 重启失败！请检查日志。"
    fi
}

Uninstall(){
    check_installed_status || return 1
    
    echo -e "${Warning} 确定要卸载 shadowsocks ? (y/N)"
    echo
    read -e -p "(默认：n)：" unyn
    [[ -z ${unyn} ]] && unyn="n"
    
    if [[ ${unyn} != [Yy] ]]; then
        echo && echo -e "${Info}卸载已取消..." && echo
        return 0
    fi
    
    check_status
    [[ "$status" == "running" ]] && systemctl stop shadowsocks
    systemctl disable shadowsocks
    
    rm -rf "${FOLDER}"
    rm -f "${FILE}"
    rm -f /etc/systemd/system/shadowsocks.service
    
    systemctl daemon-reload
    
    echo && echo -e "${Success}shadowsocks 卸载完成！" && exit
}

get_country_emoji(){
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

get_public_ip(){
    InFaces=($(ls /sys/class/net | grep -E '^(eth|ens|enp)'))
    IP_API=(
        "http://ip.gs"
        "http://ip.sb"
        "http://ident.me"
        "http://ifconfig.me"
        "http://api.ipify.org"
        "http://icanhazip.com"
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

urlsafe_base64(){
    echo -n "$1" | base64 | tr -d '\n' | tr -d '=' | tr '+/' '-_'
}

Link_QR(){
    local base64_ss=$(urlsafe_base64 "${cipher}:${password}")
    
    # 生成 IPv4 链接
    if [[ -n "${IPv4}" && "${IPv4}" != "IPv4_Error" ]]; then
        country_emoji=$(get_country_emoji "${IPv4}")
        link_IPv4="ss://${base64_ss}@${IPv4}:${port}#${country_emoji}"
    else
        link_IPv4=""
    fi
    
    # 生成 IPv6 链接
    if [[ -n "${IPv6}" && "${IPv6}" != "IPv6_Error" ]]; then
        country_emoji=$(get_country_emoji "${IPv6}")
        link_IPv6="ss://${base64_ss}@${IPv6}:${port}#${country_emoji}"
    else
        link_IPv6=""
    fi
}

View(){
    check_installed_status || return 1
    Read_config || return 1
    get_public_ip
    Link_QR
    
    clear && echo
    echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
    echo -e "${Green}               shadowsocks 配置信息                      ${Plain}"
    echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
    
    [[ ! -z "${link_IPv4}" ]] && echo -e "  ${Green}地址[IPv4]:${Plain} ${IPv4}"
    [[ ! -z "${link_IPv6}" ]] && echo -e "  ${Green}地址[IPv6]:${Plain} ${IPv6}"
    echo -e "  ${Green}端口:${Plain} ${port}"
    echo -e "  ${Green}密码:${Plain} ${password}"
    echo -e "  ${Green}加密:${Plain} ${cipher}"
    echo -e "${Green}─────────────────────────────────────────────────────${Plain}"
    
    [[ ! -z "${link_IPv4}" ]] && echo -e "  ${Green}链接[IPv4]:${Plain} ${Yellow}${link_IPv4}${Plain}"
    [[ ! -z "${link_IPv6}" ]] && echo -e "  ${Green}链接[IPv6]:${Plain} ${Yellow}${link_IPv6}${Plain}"
    echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
    
    echo
    echo -e "${Tip} 按回车返回主菜单"
    read temp
}

Status(){
    echo -e "${Info} 获取 shadowsocks 运行状态 ..."
    echo -e "${Tip} 返回主菜单请按 q ！"
    systemctl status shadowsocks --no-pager -l
    echo
    echo -e "${Tip} 按回车返回主菜单"
    read temp
}

Start_Menu(){
    clear
    check_root
    sysArch
    
    echo -e "==================================
shadowsocks 管理脚本 ${Red}[${sh_ver}]${Plain}
    作者: ${Green}你挺能闹啊${Plain}🍏
 群组: ${Green}https://t.me/fun513${Plain}
==================================
 ${Green} 1.${Plain} 安装 shadowsocks
 ${Green} 2. ${Red}卸载 shadowsocks${Plain}
——————————————————————————————————
 ${Green} 3.${Plain} 启动 shadowsocks
 ${Green} 4.${Plain} 停止 shadowsocks
 ${Green} 5.${Plain} 重启 shadowsocks
——————————————————————————————————
 ${Green} 6.${Plain} 修改 配置信息
 ${Green} 7.${Plain} 查看 配置信息
 ${Green} 8.${Plain} 查看 运行状态
——————————————————————————————————
 ${Green} 0.${Plain} 退出脚本
==================================" && echo

    if [[ -e ${FILE} ]]; then
        check_status
        if [[ "$status" == "running" ]]; then
            echo -e " 当前状态：${Green}已安装${Plain} 并 ${Green}已启动${Plain}"
            Read_config 2>/dev/null
            if [[ $? -eq 0 ]]; then
                get_public_ip
                Link_QR
                echo
                echo -e "${Green}shadowsocks 配置：${Plain}"
                echo -e "${Green}─────────────────────────────────────────────────────${Plain}"
                [[ "${IPv4}" != "IPv4_Error" ]] && echo -e "  ${Green}地址[IPv4]:${Plain} ${IPv4}"
                [[ "${IPv6}" != "IPv6_Error" ]] && echo -e "  ${Green}地址[IPv6]:${Plain} ${IPv6}"
                echo -e "  ${Green}端口:${Plain} ${port}"
                echo -e "  ${Green}密码:${Plain} ${password}"
                echo -e "  ${Green}加密:${Plain} ${cipher}"
                echo -e "${Green}─────────────────────────────────────────────────────${Plain}"
                [[ ! -z "${link_IPv4}" ]] && echo -e "${Green}IPv4链接${Plain}: ${Red}${link_IPv4}${Plain}"
                [[ ! -z "${link_IPv6}" ]] && echo -e "${Green}IPv6链接${Plain}: ${Red}${link_IPv6}${Plain}"
                echo -e "${Green}─────────────────────────────────────────────────────${Plain}"
            fi
        else
            echo -e " 当前状态：${Green}已安装${Plain} 但 ${Red}未启动${Plain}"
        fi
    else
        echo -e " 当前状态：${Red}未安装${Plain}"
    fi
    
    echo
    read -e -p " 请输入数字 [0-8]：" num
    
    case "$num" in
        1) Install ;;
        2) Uninstall ;;
        3) Start ;;
        4) Stop ;;
        5) Restart ;;
        6) Set ;;
        7) View ;;
        8) Status ;;
        0)
            echo -e "${Tip} 感谢使用，再见！${Plain}"
            exit 0
            ;;
        *)
            echo -e "${Error}请输入正确数字 [0-8]${Plain}"
            exit 1
            ;;
    esac
    
    # 循环回到菜单
    Start_Menu
}

Start_Menu
