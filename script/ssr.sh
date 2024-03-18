#!/bin/bash
# shadowsocksR/SSR一键安装教程
# Author: Fun云网络<https://fun513.xyz>

RED="\033[31m"    # Error message
GREEN="\033[32m"  # Success message
YELLOW="\033[33m" # Warning message
BLUE="\033[36m"   # Info message
PLAIN='\033[0m'

V6_PROXY=""
IP=$(curl -sL -4 ip.sb)
if [[ "$?" != "0" ]]; then
    IP=$(curl -sL -6 ip.sb)
    V6_PROXY="https://gh.hijk.art/"
fi

FILENAME="ShadowsocksR-v3.2.2"
URL="https://raw.githubusercontent.com/RyanY610/logs/main/files/3.2.2.tar.gz"
BASE=$(pwd)

OS=$(hostnamectl | grep -i system | cut -d: -f2)

CONFIG_FILE="/etc/shadowsocksR.json"
SERVICE_FILE="/etc/systemd/system/shadowsocksR.service"
NAME="shadowsocksR"

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

checkSystem() {
    if [[ $(whoami) != "root" ]]; then
        colorEcho $RED " 请以root身份执行该脚本"
        exit 1
    fi

    res=$(which yum 2>/dev/null)
    if [[ "$?" != "0" ]]; then
        res=$(which apt 2>/dev/null)
        if [[ "$?" != "0" ]]; then
            colorEcho $RED " 不受支持的Linux系统"
            exit 1
        fi
        PMT="apt"
        CMD_INSTALL="apt install -y "
        CMD_REMOVE="apt remove -y "
        CMD_UPGRADE="apt update && apt upgrade -y; apt autoremove -y"
    else
        PMT="yum"
        CMD_INSTALL="yum install -y "
        CMD_REMOVE="yum remove -y "
        CMD_UPGRADE="yum update -y"
    fi
    res=$(which systemctl 2>/dev/null)
    if [[ "$?" != "0" ]]; then
        colorEcho $RED " 系统版本过低，请升级到最新版本"
        exit 1
    fi
}

getData() {
    echo ""
    read -p " 请设置SSR的密码（不输入则随机生成）:" PASSWORD
    [[ -z "$PASSWORD" ]] && PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    echo ""
    colorEcho $BLUE " 密码： $PASSWORD"

    echo ""
    while true; do
        read -p " 请设置SSR的端口号[1-65535]:" PORT
        [[ -z "$PORT" ]] && PORT=$(shuf -i1025-65000 -n1)
        if [[ "${PORT:0:1}" = "0" ]]; then
            echo -e " ${RED}端口不能以0开头${PLAIN}"
            exit 1
        fi
        expr $PORT + 0 &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [ $PORT -ge 1 ] && [ $PORT -le 65535 ]; then
                echo ""
                colorEcho $BLUE " 端口号： $PORT"
                break
            else
                colorEcho $RED " 输入错误，端口号为1-65535的数字"
            fi
        else
            colorEcho $RED " 输入错误，端口号为1-65535的数字"
        fi
    done

    echo ""
    colorEcho $BLUE " 请选择SSR的加密方式:"
    echo "  1)aes-256-cfb"
    echo "  2)aes-192-cfb"
    echo "  3)aes-128-cfb"
    echo "  4)aes-256-ctr"
    echo "  5)aes-192-ctr"
    echo "  6)aes-128-ctr"
    echo "  7)aes-256-cfb8"
    echo "  8)aes-192-cfb8"
    echo "  9)aes-128-cfb8"
    echo "  10)camellia-128-cfb"
    echo "  11)camellia-192-cfb"
    echo "  12)camellia-256-cfb"
    echo "  13)chacha20-ietf"
    read -p " 请选择加密方式（默认aes-256-cfb）" answer
    if [[ -z "$answer" ]]; then
        METHOD="aes-256-cfb"
    else
        case $answer in
        1)
            METHOD="aes-256-cfb"
            ;;
        2)
            METHOD="aes-192-cfb"
            ;;
        3)
            METHOD="aes-128-cfb"
            ;;
        4)
            METHOD="aes-256-ctr"
            ;;
        5)
            METHOD="aes-192-ctr"
            ;;
        6)
            METHOD="aes-128-ctr"
            ;;
        7)
            METHOD="aes-256-cfb8"
            ;;
        8)
            METHOD="aes-192-cfb8"
            ;;
        9)
            METHOD="aes-128-cfb8"
            ;;
        10)
            METHOD="camellia-128-cfb"
            ;;
        11)
            METHOD="camellia-192-cfb"
            ;;
        12)
            METHOD="camellia-256-cfb"
            ;;
        13)
            METHOD="chacha20-ietf"
            ;;
        *)
            colorEcho $RED " 无效的选择，使用默认加密方式"
            METHOD="aes-256-cfb"
            ;;
        esac
    fi
    echo ""
    colorEcho $BLUE " 加密方式： $METHOD"

    echo ""
    colorEcho $BLUE " 请选择SSR协议："
    echo "   1)origin"
    echo "   2)verify_deflate"
    echo "   3)auth_sha1_v4"
    echo "   4)auth_aes128_md5"
    echo "   5)auth_aes128_sha1"
    echo "   6)auth_chain_a"
    echo "   7)auth_chain_b"
    echo "   8)auth_chain_c"
    echo "   9)auth_chain_d"
    echo "   10)auth_chain_e"
    echo "   11)auth_chain_f"
    read -p " 请选择SSR协议（默认origin）" answer
    if [[ -z "$answer" ]]; then
        PROTOCOL="origin"
    else
        case $answer in
        1)
            PROTOCOL="origin"
            ;;
        2)
            PROTOCOL="verify_deflate"
            ;;
        3)
            PROTOCOL="auth_sha1_v4"
            ;;
        4)
            PROTOCOL="auth_aes128_md5"
            ;;
        5)
            PROTOCOL="auth_aes128_sha1"
            ;;
        6)
            PROTOCOL="auth_chain_a"
            ;;
        7)
            PROTOCOL="auth_chain_b"
            ;;
        8)
            PROTOCOL="auth_chain_c"
            ;;
        9)
            PROTOCOL="auth_chain_d"
            ;;
        10)
            PROTOCOL="auth_chain_e"
            ;;
        11)
            PROTOCOL="auth_chain_f"
            ;;
        *)
            colorEcho $RED " 无效的选择，使用默认协议"
            PROTOCOL="origin"
            ;;
        esac
    fi
    echo ""
    colorEcho $BLUE " SSR协议： $PROTOCOL"

    echo ""
    colorEcho $BLUE " 请选择SSR混淆模式："
    echo "   1)plain"
    echo "   2)http_simple"
    echo "   3)http_post"
    echo "   4)tls1.2_ticket_auth"
    echo "   5)tls1.2_ticket_fastauth"
    read -p " 请选择混淆模式（默认plain）" answer
    if [[ -z "$answer" ]]; then
        OBFS="plain"
    else
        case $answer in
        1)
            OBFS="plain"
            ;;
        2)
            OBFS="http_simple"
            ;;
        3)
            OBFS="http_post"
            ;;
        4)
            OBFS="tls1.2_ticket_auth"
            ;;
        5)
            OBFS="tls1.2_ticket_fastauth"
            ;;
        *)
            colorEcho $RED " 无效的选择，使用默认混淆模式"
            OBFS="plain"
            ;;
        esac
    fi
    echo ""
    colorEcho $BLUE " 混淆模式： $OBFS"
}

status() {
    res=$(which python 2>/dev/null)
    if [[ "$?" != "0" ]]; then
        echo 0
        return
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        echo 1
        return
    fi
    port=$(grep server_port $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    res=$(netstat -nltp | grep ${port} | grep python)
    if [[ -z "$res" ]]; then
        echo 2
    else
        echo 3
    fi
}

statusText() {
    res=$(status)
    case $res in
    2)
        echo -e ${GREEN}已安装${PLAIN} ${RED}未运行${PLAIN}
        ;;
    3)
        echo -e ${GREEN}已安装${PLAIN} ${GREEN}正在运行${PLAIN}
        ;;
    *)
        echo -e ${RED}未安装${PLAIN}
        ;;
    esac
}

preinstall() {
    $PMT clean all
    [[ "$PMT" = "apt" ]] && $PMT update
    #echo $CMD_UPGRADE | bash
    echo ""
    colorEcho $BLUE " 安装必要软件"
    if [[ "$PMT" = "yum" ]]; then
        $CMD_INSTALL epel-release
    fi
    $CMD_INSTALL curl wget vim python2 net-tools libsodium* openssl unzip tar qrencode git socat gnupg2
    res=$(which wget 2>/dev/null)
    [[ "$?" != "0" ]] && $CMD_INSTALL wget
    res=$(which netstat 2>/dev/null)
    [[ "$?" != "0" ]] && $CMD_INSTALL net-tools
    res=$(which python 2>/dev/null)
    if [[ "$?" != "0" ]]; then
        ln -s /usr/bin/python2 /usr/bin/python
    fi

    if [[ -s /etc/selinux/config ]] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        setenforce 0
    fi
}

installSSR() {
    if [[ ! -d /usr/local/shadowsocks ]]; then
        colorEcho $BLUE " 下载安装文件"
        if ! wget --no-check-certificate -O ${FILENAME}.tar.gz ${URL}; then
            echo -e " [${RED}Error${PLAIN}] 下载文件失败!"
            exit 1
        fi

        tar -zxf ${FILENAME}.tar.gz
        mv shadowsocksr-3.2.2/shadowsocks /usr/local
        if [[ ! -f /usr/local/shadowsocks/server.py ]]; then
            colorEcho $RED " $OS 安装失败，请访问 https://t.me/fun_dmbot 反馈"
            cd ${BASE} && rm -rf shadowsocksr-3.2.2 ${FILENAME}.tar.gz
            exit 1
        fi
        cd ${BASE} && rm -rf shadowsocksr-3.2.2 ${FILENAME}.tar.gz
    fi

    cat >$SERVICE_FILE <<-EOF
[Unit]
Description=shadowsocksR
Documentation=https://tizi.blog/
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
LimitNOFILE=32768
ExecStart=python2 /usr/local/shadowsocks/server.py -c $CONFIG_FILE -d start
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s TERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocksR
}

configSSR() {
    cat >$CONFIG_FILE <<-EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":${PORT},
    "local_port":1080,
    "password":"${PASSWORD}",
    "timeout":600,
    "method":"${METHOD}",
    "protocol":"${PROTOCOL}",
    "protocol_param":"",
    "obfs":"${OBFS}",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":false,
    "workers":1
}
EOF
}

setFirewall() {
    res=$(which firewall-cmd 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        systemctl status firewalld >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            firewall-cmd --permanent --add-port=${PORT}/tcp
            firewall-cmd --permanent --add-port=${PORT}/udp
            firewall-cmd --reload
        else
            nl=$(iptables -nL | nl | grep FORWARD | awk '{print $1}')
            if [[ "$nl" != "3" ]]; then
                iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
                iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT
            fi
        fi
    else
        res=$(which iptables 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            nl=$(iptables -nL | nl | grep FORWARD | awk '{print $1}')
            if [[ "$nl" != "3" ]]; then
                iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT
                iptables -I INPUT -p udp --dport ${PORT} -j ACCEPT
            fi
        else
            res=$(which ufw 2>/dev/null)
            if [[ $? -eq 0 ]]; then
                res=$(ufw status | grep -i inactive)
                if [[ "$res" = "" ]]; then
                    ufw allow ${PORT}/tcp
                    ufw allow ${PORT}/udp
                fi
            fi
        fi
    fi
}

showInfo() {
    res=$(status)
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SSR未安装，请先安装！${PLAIN}"
        return
    fi
    port=$(grep server_port $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    res=$(netstat -nltp | grep ${port} | grep python)
    [[ -z "$res" ]] && status="${RED}已停止${PLAIN}" || status="${GREEN}正在运行${PLAIN}"
    password=$(grep password $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    method=$(grep method $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    protocol=$(grep protocol $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    obfs=$(grep obfs $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')

    p1=$(echo -n ${password} | base64 -w 0)
    p1=$(echo -n ${p1} | tr -d =)
    res=$(echo -n "${IP}:${port}:${protocol}:${method}:${obfs}:${p1}/?remarks=&protoparam=&obfsparam=" | base64 -w 0)
    res=$(echo -n ${res} | tr -d =)
    link="ssr://${res}"

    echo ""
    echo ============================================
    echo -e " ${BLUE}ssr运行状态：${PLAIN}${status}"
    echo -e " ${BLUE}ssr配置文件：${PLAIN}${RED}$CONFIG_FILE${PLAIN}"
    echo ""
    echo -e " ${RED}ssr配置信息：${PLAIN}"
    echo -e "   ${BLUE}IP(address):${PLAIN}  ${RED}${IP}${PLAIN}"
    echo -e "   ${BLUE}端口(port)：${PLAIN}${RED}${port}${PLAIN}"
    echo -e "   ${BLUE}密码(password)：${PLAIN}${RED}${password}${PLAIN}"
    echo -e "   ${BLUE}加密方式(method)：${PLAIN} ${RED}${method}${PLAIN}"
    echo -e "   ${BLUE}协议(protocol)：${PLAIN} ${RED}${protocol}${PLAIN}"
    echo -e "   ${BLUE}混淆(obfuscation)：${PLAIN} ${RED}${obfs}${PLAIN}"
    echo
    echo -e " ${BLUE}ssr链接:${PLAIN} $link"
    #qrencode -o - -t utf8 $link
}

showQR() {
    res=$(status)
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SSR未安装，请先安装！${PLAIN}"
        return
    fi
    port=$(grep server_port $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    res=$(netstat -nltp | grep ${port} | grep python)
    [[ -z "$res" ]] && status="${RED}已停止${PLAIN}" || status="${GREEN}正在运行${PLAIN}"
    password=$(grep password $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    method=$(grep method $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    protocol=$(grep protocol $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    obfs=$(grep obfs $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')

    p1=$(echo -n ${password} | base64 -w 0)
    p1=$(echo -n ${p1} | tr -d =)
    res=$(echo -n "${IP}:${port}:${protocol}:${method}:${obfs}:${p1}/?remarks=&protoparam=&obfsparam=" | base64 -w 0)
    res=$(echo -n ${res} | tr -d =)
    link="ssr://${res}"
    qrencode -o - -t utf8 $link
}

install() {
    getData
    preinstall
    installSSR
    configSSR
    setFirewall

    start
    showInfo
}

reconfig() {
    res=$(status)
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SSR未安装，请先安装！${PLAIN}"
        return
    fi
    getData
    configSSR
    setFirewall
    restart

    showInfo
}

uninstall() {
    res=$(status)
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SSR未安装，请先安装！${PLAIN}"
        return
    fi

    echo ""
    read -p " 确定卸载SSR吗？(y/n)" answer
    [[ -z ${answer} ]] && answer="n"

    if [[ "${answer}" == "y" ]] || [[ "${answer}" == "Y" ]]; then
        rm -f $CONFIG_FILE
        rm -f /var/log/shadowsocksr.log
        rm -rf /usr/local/shadowsocks
        systemctl disable shadowsocksR && systemctl stop shadowsocksR && rm -rf $SERVICE_FILE
    fi
    echo -e " ${RED}卸载成功${PLAIN}"
}

start() {
    res=$(status)
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SS未安装，请先安装！${PLAIN}"
        return
    fi
    systemctl restart ${NAME}
    sleep 2
    port=$(grep server_port $CONFIG_FILE | cut -d: -f2 | tr -d \",' ')
    res=$(netstat -nltp | grep ${port} | grep python)
    if [[ "$res" = "" ]]; then
        colorEcho $RED " SSR启动失败，请检查端口是否被占用！"
    else
        colorEcho $BLUE " SSR启动成功！"
    fi
}

restart() {
    res=$(status)
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SSR未安装，请先安装！${PLAIN}"
        return
    fi

    stop
    start
}

stop() {
    res=$(status)
    if [[ $res -lt 2 ]]; then
        echo -e " ${RED}SSR未安装，请先安装！${PLAIN}"
        return
    fi
    systemctl stop ${NAME}
    colorEcho $BLUE " SSR停止成功"
}

showLog() {
    tail /var/log/shadowsocksr.log
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#             ${RED}ShadowsocksR/SSR 一键安装脚本${PLAIN}                 #"
    echo -e "# ${GREEN}作者${PLAIN}: 你挺能闹啊🍏                                        #"
    echo -e "# ${GREEN}网址${PLAIN}: https://fun513.xyz                                  #"
    echo "#############################################################"
    echo ""

    echo -e "  ${GREEN}1.${PLAIN}  ${GREEN}安装SSR${PLAIN}"
    echo -e "  ${GREEN}2.  ${RED}卸载SSR${PLAIN}"
    echo " -------------"
    echo -e "  ${GREEN}4.${PLAIN}  ${GREEN}启动SSR${PLAIN}"
    echo -e "  ${GREEN}5.${PLAIN}  重启SSR"
    echo -e "  ${GREEN}6.${PLAIN}  ${RED}停止SSR${PLAIN}"
    echo " -------------"
    echo -e "  ${GREEN}7.${PLAIN}  查看SSR配置"
    echo -e "  ${GREEN}8.${PLAIN}  查看配置二维码"
    echo -e "  ${GREEN}9.  ${RED}修改SSR配置${PLAIN}"
    echo -e "  ${GREEN}10.${PLAIN} 查看SSR日志"
    echo " -------------"
    echo -e "  ${GREEN}0.${PLAIN} 退出"
    echo
    echo -n " 当前状态："
    statusText
    echo

    read -p " 请选择操作[0-10]：" answer
    case $answer in
    0)
        exit 0
        ;;
    1)
        install
        ;;
    2)
        uninstall
        ;;
    4)
        start
        ;;
    5)
        restart
        ;;
    6)
        stop
        ;;
    7)
        showInfo
        ;;
    8)
        showQR
        ;;
    9)
        reconfig
        ;;
    10)
        showLog
        ;;
    *)
        echo -e "$RED 请选择正确的操作！${PLAIN}"
        exit 1
        ;;
    esac
}

checkSystem

action=$1
[[ -z $1 ]] && action=menu
case "$action" in
menu | install | uninstall | start | restart | stop | showInfo | showQR | showLog)
    ${action}
    ;;
*)
    echo " 参数错误"
    echo " 用法: $(basename $0) [menu|install|uninstall|start|restart|stop|showInfo|showQR|showLog]"
    ;;
esac
