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
    if [ -d "/proc/vz" ]; then
        echo -e "${Error} 警告: 你的VPS基于OpenVZ，内核可能不支持IPSec。"
        echo -e "${Tip} L2TP安装已取消。"
        exit 1
    fi
    
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

    if [[ ! "${release}" == "ubuntu" ]]; then
        echo -e "${Error} 抱歉，此脚本不支持您的操作系统。"
        echo -e "${Info} 请确保您使用的是 ${Red}ubuntu${Nc} 系统"
        exit 1
    fi
}

check_pmc(){
    check_release
    if [[ "$release" == "ubuntu" ]]; then
        updates="apt update -y"
        installs="apt install -y"
        apps=("curl" "xl2tpd" "strongswan" "nftables")
    fi
}

install_base(){
    check_pmc
    cmds=("curl" "xl2tpd" "ipsec" "nft")
    echo -e "${Info} 你的系统是${Red} $release $os_version ${Nc}"
    echo
    
    for i in "${!cmds[@]}"; do
        if ! which "${cmds[i]}" &>/dev/null; then
            APPS+=("${apps[i]}")
        fi
    done
    
    if [ ${#APPS[@]} -gt 0 ]; then
        echo -e "${Tip} 安装依赖列表：${Green}${APPS[*]}${Nc} 请稍后..."
        $updates 
        $installs "${APPS[@]}"
        $installs ppp &>/dev/null
    else
        echo -e "${Info} 所有依赖已存在，不需要额外安装。"
    fi
}

rand(){
    local length=${1:-10}
    local chars=({a..z} {A..Z} {0..9})
    local str=""
    
    for i in $(seq 1 $length); do
        str+="${chars[$RANDOM%62]}"
    done
    echo "$str"
}

get_public_ip(){
    InFaces=($(ls /sys/class/net | grep -E '^(eth|ens|eno|esp|enp|vif)'))
    IP_API=(
        "ip.gs"
        "api64.ipify.org"
        "ip.sb"
        "ifconfig.me"
        "icanhazip.com"
    )

    for iface in "${InFaces[@]}"; do
        for ip_api in "${IP_API[@]}"; do
            IPv4=$(curl -s4 --max-time 2 --interface "$iface" "$ip_api")

            if [[ -n "$IPv4" ]]; then
                inface="$iface"
                break 2
            fi
        done
    done
}

install_vpn(){
    get_public_ip
    set_conf
    cat > /etc/ipsec.conf<<EOF
config setup
    charondebug="ike 2, knl 2, cfg 2"
    uniqueids=no

conn %default
    keyexchange=ikev1
    authby=secret
    ike=aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    esp=aes256-sha1,aes128-sha1,3des-sha1!
    keyingtries=3
    ikelifetime=8h
    lifetime=1h
    dpdaction=clear
    dpddelay=30s
    dpdtimeout=120s
    rekey=no
    forceencaps=yes
    fragmentation=yes

conn L2TP-PSK
    left=%any
    leftid=${IPv4}
    leftfirewall=yes
    leftprotoport=17/${l2tpport}
    right=%any
    rightprotoport=17/%any
    type=transport
    auto=add
    also=%default

EOF
    cat > /etc/ipsec.secrets<<EOF
%any %any : PSK "${l2tppsk}"

EOF
    cat > /etc/xl2tpd/xl2tpd.conf<<EOF
[global]
port = ${l2tpport}

[lns default]
ip range = ${l2tplocip}.11-${l2tplocip}.255
local ip = ${l2tplocip}.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes

EOF
    cat > /etc/ppp/options.xl2tpd<<EOF
ipcp-accept-local
ipcp-accept-remote
require-mschap-v2
ms-dns 1.1.1.1
ms-dns 114.114.114.114
noccp
auth
hide-password
idle 1800
mtu 1410
mru 1410
nodefaultroute
debug
proxyarp
connect-delay 5000

EOF

    cat > /etc/ppp/chap-secrets <<EOF
# Secrets for authentication using CHAP
# client    server    secret    IP addresses
EOF

    for num in $(seq 11 255); do
        echo "${l2tpuser}${num}    l2tpd    ${l2tppass}${num}    ${l2tplocip}.${num}" >> /etc/ppp/chap-secrets
    done

    set_icmp
    set_nftables
}

set_icmp(){
    seticmp1="net.ipv4.ip_forward=1"
    seticmp2="net.ipv4.conf.all.send_redirects=0"
    seticmp3="net.ipv4.conf.default.send_redirects=0"
    seticmp4="net.ipv4.conf.all.accept_redirects=0"
    seticmp5="net.ipv4.conf.default.accept_redirects=0"

    for seticmp in "$seticmp1" "$seticmp2" "$seticmp3" "$seticmp4" "$seticmp5"; do
        if grep -qE "^\s*${seticmp%=*}\s*=" /etc/sysctl.conf; then
            sed -i "s|^\s*${seticmp%=*}\s*=.*|${seticmp}|g" /etc/sysctl.conf
        else
            echo "$seticmp" >> /etc/sysctl.conf
        fi
    done

    sysctl -p &> /dev/null
    ip rule add fwmark 0x39 lookup 100
    ip route add local 0.0.0.0/0 dev lo table 100
}

set_nftables(){
    [ -f /etc/nftables.conf ] && cp -pf /etc/nftables.conf /etc/nftables.conf.old.`date +%Y%m%d`
    cat > /etc/nftables.conf <<EOF
#!/usr/sbin/nft -f

flush ruleset

table ip mangle {
    chain singbox {
        ip daddr { 0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } return
        meta l4proto icmp return
        ip saddr ${l2tplocip}.0/24 meta l4proto tcp tproxy to :${tproxyport} meta mark set 0x39 accept
        ip saddr ${l2tplocip}.0/24 meta l4proto udp tproxy to :${tproxyport} meta mark set 0x39 accept
    }

    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        iifname "ppp*" jump singbox
    }

    chain input {
        type filter hook input priority mangle; policy accept;
        iifname "ppp*" meta l4proto tcp tcp flags & (syn|rst) == syn counter tcp option maxseg size set 1200
    }

    chain forward {
        type filter hook forward priority mangle; policy accept;
        iifname "ppp*" meta l4proto tcp tcp flags & (syn|rst) == syn counter tcp option maxseg size set 1200
        oifname "ppp*" meta l4proto tcp tcp flags & (syn|rst) == syn counter tcp option maxseg size set 1200
    }

    chain output {
        type route hook output priority mangle; policy accept;
        oifname "ppp*" meta l4proto tcp tcp flags & (syn|rst) == syn counter tcp option maxseg size set 1200
    }
}

table inet filter {
    chain input {
        type filter hook input priority 0;
        ct state established,related accept
        ip protocol icmp accept
        iif lo accept
        udp dport { 500, 4500, ${l2tpport} } accept
        accept
    }

    chain forward {
        type filter hook forward priority 0;
        ct state established,related accept
        ip saddr ${l2tplocip}.0/24 accept
        accept
    }

    chain output {
        type filter hook output priority 0;
        accept
    }
}

table ip nat {
    chain prerouting {
        type nat hook prerouting priority 0;
        accept
    }

    chain postrouting {
        type nat hook postrouting priority 100;
        oif "${inface}" masquerade
    }

    chain output {
        type nat hook output priority 0;
        accept
    }
}
EOF
    systemctl daemon-reload
    systemctl enable nftables
    systemctl restart nftables
}

vpn_start(){
    systemctl daemon-reload 
    systemctl enable ipsec
    systemctl enable xl2tpd

    echo 1 > /proc/sys/net/ipv4/ip_forward
    systemctl restart ipsec
    systemctl restart xl2tpd
}

set_conf(){
    echo
    # L2tp
    echo -e "${Tip} 请输入L2tpIP范围:"
    read -p "(默认范围: 10.10.10):" l2tplocip
    [ -z "${l2tplocip}" ] && l2tplocip="10.10.10"
    echo
    echo -e "${Tip} 请输入L2tp端口:"
    read -p "(默认端口: 1701):" l2tpport
    [ -z "${l2tpport}" ] && l2tpport=1701
    echo
    # 端口范围检查
    while ! [[ "$l2tpport" =~ ^[0-9]+$ ]] || [ "$l2tpport" -lt 1000 ] || [ "$l2tpport" -gt 65535 ]; do
        echo -e "${Error} 端口必须为1000-65535之间的数字"
        read -p "请重新输入端口 (1000-65535):" l2tpport
        [ -z "${l2tpport}" ] && l2tpport=1701
    done
    echo
    l2tpuser=$(rand 5)
    echo -e "${Tip} 请输入L2tp用户名:"
    read -p "(默认用户名: ${l2tpuser}):" tmpl2tpuser
    [ -n "${tmpl2tpuser}" ] && l2tpuser="${tmpl2tpuser}"
    echo
    l2tppass=$(rand 7)
    echo -e "${Tip} 请输入 ${l2tpuser} 的密码:"
    read -p "(默认密码: ${l2tppass}):" tmpl2tppass
    [ -n "${tmpl2tppass}" ] && l2tppass="${tmpl2tppass}"
    echo
    l2tppsk=$(rand 20)
    echo -e "${Tip} 请输入L2tp PSK密钥:"
    read -p "(默认PSK: ${l2tppsk}):" tmppsk
    [ -n "${tmppsk}" ] && l2tppsk="${tmppsk}"
    echo
    echo -e "${Tip} 请输入 tproxy 端口:"
    read -p "(默认端口: 12345):" tproxyport
    [ -z "${tproxyport}" ] && tproxyport=12345
    echo
    # 端口范围检查
    while ! [[ "$tproxyport" =~ ^[0-9]+$ ]] || [ "$tproxyport" -lt 10000 ] || [ "$tproxyport" -gt 65535 ]; do
        echo -e "${Error} 端口必须为1000-65535之间的数字"
        read -p "请重新输入端口 (10000-65535):" tproxyport
        [ -z "${tproxyport}" ] && tproxyport=12345
    done
    echo
    echo -e "${Info} L2tp 服务器本地IP: ${Green}${l2tplocip}.1${Nc}"
    echo -e "${Info} L2tp 客户端IP范围: ${Green}${l2tplocip}.11-${l2tplocip}.255${Nc}"
    echo -e "${Info} L2tp 端口    : ${Green}${l2tpport}${Nc}"
    echo -e "${Info} L2tp 用户名  : ${Green}${l2tpuser}${Nc}"
    echo -e "${Info} L2tp 密码    : ${Green}${l2tppass}${Nc}"
    echo -e "${Info} L2tp PSK密钥 : ${Green}${l2tppsk}${Nc}"
    echo -e "${Info} 透明代理端口  : ${Green}${tproxyport}${Nc}"
    echo
}

finally(){
    echo "请稍候..."
    sleep 3
    vpn_start
    echo
    echo "###############################################################"
    echo "# VPN 安装脚本                                                #"
    echo "###############################################################"
    echo
    echo -e "${Info} 默认用户名和密码如下:"
    echo
    echo -e "${Info} 服务器IP: ${Green}${IPv4}${Nc}"
    echo
    echo -e "${Info} L2tp 端口    : ${Green}${l2tpport}${Nc}"
    echo -e "${Info} L2tp 用户名  : ${Green}${l2tpuser}${Nc}"
    echo -e "${Info} L2tp 密码    : ${Green}${l2tppass}${Nc}"
    echo -e "${Info} L2tp PSK密钥 : ${Green}${l2tppsk}${Nc}"
    echo -e "${Info} 透明代理端口  : ${Green}${tproxyport}${Nc}"
    echo
    echo -e "${Info} 完整的用户配置请查看 ${Green}/etc/ppp/chap-secrets${Nc} 文件"
    echo
}


vpn(){
    clear
    echo
    echo "###############################################################"
    echo "# VPN 安装脚本                                                #"
    echo "###############################################################"
    echo
    check_root
    install_base
    install_vpn
    finally
}

vpn
