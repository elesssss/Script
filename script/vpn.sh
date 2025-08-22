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

    if [[ "${release}" == "ol" ]]; then
        release=oracle
    elif [[ ! "${release}" =~ ^(kali|centos|ubuntu|fedora|debian|almalinux|rocky|alpine)$ ]]; then
        echo -e "${Error} 抱歉，此脚本不支持您的操作系统。"
        echo -e "${Info} 请确保您使用的是以下支持的操作系统之一："
        echo -e "-${Red} Ubuntu ${Nc}"
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
        apps=("curl" "xl2tpd" "strongswan" "pptpd")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        apps=("curl" "xl2tpd" "strongswan" "pptpd")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        check_install="dnf list installed"
        apps=("curl" "xl2tpd" "strongswan" "pptpd")
    elif [[ "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        apps=("curl" "xl2tpd" "strongswan" "pptpd")
    elif [[ "$release" == "fedora" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("curl" "xl2tpd" "strongswan" "pptpd")
    fi
}

install_base(){
    check_pmc
    cmds=("curl" "xl2tpd" "ipsec" "pptpd")
    echo -e "${Info} 你的系统是${Red} $release $os_version ${Nc}"
    echo
    
    for i in "${!cmds[@]}"; do
        if ! which "${cmds[i]}" &>/dev/null; then
            APPS+=("${apps[i]}")
            CMDS+=("${cmds[i]}")
        fi
    done
    
    if [ ${#APPS[@]} -gt 0 ]; then
        echo -e "${Tip} 安装依赖列表：${Green}${CMDS[*]}${Nc} 请稍后..."
        $updates &>/dev/null
        $installs "${APPS[@]}" &>/dev/null
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
ms-dns 8.8.8.8
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

    cat > /etc/pptpd.conf<<EOF
option /etc/ppp/pptpd-options
debug
localip ${pptplocip}.1
remoteip ${pptplocip}.11-255

EOF

    cat > /etc/ppp/pptpd-options<<EOF
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 114.114.114.114
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd

EOF

    cat > /etc/ppp/chap-secrets <<EOF
# Secrets for authentication using CHAP
# client    server    secret    IP addresses
EOF

    for num in $(seq 11 255); do
        echo "${l2tpuser}${num}    l2tpd    ${l2tppass}${num}    ${l2tplocip}.${num}" >> /etc/ppp/chap-secrets
    done
    for num in $(seq 11 255); do
        echo "${pptpuser}${num}    pptpd    ${pptppass}${num}    ${pptplocip}.${num}" >> /etc/ppp/chap-secrets
    done

    set_icmp
    set_iptables
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
}

set_iptables(){
    [ -f /etc/iptables.vpn.rules ] && cp -pf /etc/iptables.vpn.rules /etc/iptables.vpn.rules.old.`date +%Y%m%d`
    cat > /etc/iptables.vpn.rules <<EOF
# Added by L2TP VPN script
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A INPUT -p udp -m multiport --dports 500,4500,${l2tpport},${pptpport} -j ACCEPT
-A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s ${l2tplocip}.0/24 -j ACCEPT
-A FORWARD -s ${pptplocip}.0/24 -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o ${inface} -j MASQUERADE
COMMIT
EOF
}

vpn_start(){
    # 创建rc.local文件（如果不存在）
    if [ ! -f /etc/rc.local ]; then
        cat > /etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

echo 1 > /proc/sys/net/ipv4/ip_forward
/usr/sbin/service ipsec start
/usr/sbin/service xl2tpd start
/usr/sbin/service pptpd start
/sbin/iptables-restore < /etc/iptables.vpn.rules

exit 0
EOF
        chmod +x /etc/rc.local
    else
        # 如果已存在rc.local，则追加内容
        sed -i '/^exit 0/d' /etc/rc.local
        cat >> /etc/rc.local <<EOF

# Added by L2TP VPN script
echo 1 > /proc/sys/net/ipv4/ip_forward
/usr/sbin/service ipsec start
/usr/sbin/service xl2tpd start
/usr/sbin/service pptpd start
/sbin/iptables-restore < /etc/iptables.vpn.rules

exit 0
EOF
    fi

    cat > /etc/network/if-up.d/iptables <<EOF
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.vpn.rules
EOF
    chmod +x /etc/network/if-up.d/iptables

    update-rc.d -f xl2tpd defaults
    # 启用并启动服务
    systemctl enable ipsec
    systemctl enable xl2tpd
    systemctl enable pptpd

    echo 1 > /proc/sys/net/ipv4/ip_forward
    /sbin/iptables-restore < /etc/iptables.vpn.rules
    systemctl daemon-reload 
    systemctl restart ipsec
    systemctl restart xl2tpd
    systemctl restart pptpd
}

set_conf(){
    echo
    # L2tp
    echo -e "${Tip} 请输入L2tpIP范围:"
    read -p "(默认范围: 10.10.10):" l2tplocip
    [ -z "${l2tplocip}" ] && l2tplocip="10.10.10"

    echo -e "${Tip} 请输入L2tp端口:"
    read -p "(默认端口: 1999):" l2tpport
    [ -z "${l2tpport}" ] && l2tpport=1999

    # 端口范围检查
    while ! [[ "$l2tpport" =~ ^[0-9]+$ ]] || [ "$l2tpport" -lt 1000 ] || [ "$l2tpport" -gt 65535 ]; do
        echo -e "${Error} 端口必须为1000-65535之间的数字"
        read -p "请重新输入端口 (1000-65535):" l2tpport
        [ -z "${l2tpport}" ] && l2tpport=1999
    done

    l2tpuser=$(rand 5)
    echo -e "${Tip} 请输入L2tp用户名:"
    read -p "(默认用户名: ${l2tpuser}):" tmpl2tpuser
    [ -n "${tmpl2tpuser}" ] && l2tpuser="${tmpl2tpuser}"

    l2tppass=$(rand 7)
    echo -e "${Tip} 请输入 ${l2tpuser} 的密码:"
    read -p "(默认密码: ${l2tppass}):" tmpl2tppass
    [ -n "${tmpl2tppass}" ] && l2tppass="${tmpl2tppass}"

    l2tppsk=$(rand 20)
    echo -e "${Tip} 请输入L2tp PSK密钥:"
    read -p "(默认PSK: ${l2tppsk}):" tmppsk
    [ -n "${tmppsk}" ] && l2tppsk="${tmppsk}"
    
    # Pptp
    echo -e "${Tip} 请输入Pptp IP范围:"
    read -p "(默认范围: 192.168.30):" pptplocip
    [ -z "${pptplocip}" ] && pptplocip="192.168.30"

    echo -e "${Tip} 请输入Pptp端口:"
    read -p "(默认端口: 1723):" pptpport
    [ -z "${pptpport}" ] && pptpport=1723

    # 端口范围检查
    while ! [[ "$pptpport" =~ ^[0-9]+$ ]] || [ "$pptpport" -lt 1000 ] || [ "$pptpport" -gt 65535 ]; do
        echo -e "${Error} 端口必须为1000-65535之间的数字"
        read -p "请重新输入端口 (1000-65535):" l2tpport
        [ -z "${pptpport}" ] && pptpport=1723
    done

    pptpuser=$(rand 5)
    echo -e "${Tip} 请输入Pptp用户名:"
    read -p "(默认用户名: ${pptpuser}):" tmppptpuser
    [ -n "${tmppptpuser}" ] && pptpuser="${tmppptpuser}"

    pptppass=$(rand 7)
    echo -e "${Tip} 请输入 ${pptpuser} 的密码:"
    read -p "(默认密码: ${pptppass}):" tmppptppass
    [ -n "${tmppptppass}" ] && pptppass="${tmppptppass}"

    echo
    echo -e "${Info} L2tp服务器本地IP: ${Green}${l2tplocip}.1${Nc}"
    echo -e "${Info} L2tp客户端IP范围: ${Green}${l2tplocip}.11-${l2tplocip}.255${Nc}"
    echo -e "${Info} L2tp端口    : ${Green}${l2tpport}${Nc}"
    echo -e "${Info} L2tp用户名  : ${Green}${l2tpuser}${Nc}"
    echo -e "${Info} L2tp密码    : ${Green}${l2tppass}${Nc}"
    echo -e "${Info} L2tpPSK密钥 : ${Green}${l2tppsk}${Nc}"
    echo
    echo -e "${Info} Pptp服务器本地IP: ${Green}${pptplocip}.1${Nc}"
    echo -e "${Info} Pptp客户端IP范围: ${Green}${pptplocip}.11-${pptplocip}.255${Nc}"
    echo -e "${Info} Pttp端口    : ${Green}${pptpport}${Nc}"
    echo -e "${Info} Pttp用户名  : ${Green}${pptpuser}${Nc}"
    echo -e "${Info} Pttp密码    : ${Green}${pptppass}${Nc}"
    echo
}

finally(){
    echo "请稍候..."
    sleep 3
    vpn_start
    #ipsec verify
    echo
    echo "###############################################################"
    echo "# VPN 安装脚本                                                #"
    echo "###############################################################"
    echo
    echo -e "${Info} 默认用户名和密码如下:"
    echo
    echo -e "${Info} 服务器IP: ${Green}${IPv4}${Nc}"
    echo
    echo -e "${Info} L2tp端口    : ${Green}${l2tpport}${Nc}"
    echo -e "${Info} L2tp用户名  : ${Green}${l2tpuser}${Nc}"
    echo -e "${Info} L2tp密码    : ${Green}${l2tppass}${Nc}"
    echo -e "${Info} L2tpPSK密钥 : ${Green}${l2tppsk}${Nc}"
    echo
    echo -e "${Info} Pttp端口    : ${Green}${pptpport}${Nc}"
    echo -e "${Info} Pttp用户名  : ${Green}${pptpuser}${Nc}"
    echo -e "${Info} Pttp密码    : ${Green}${pptppass}${Nc}"
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
