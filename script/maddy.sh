#! /bin/bash

# 输出字体颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 设置版权输出
clear
echo -e "${GREEN}#############################################################${NC}"
echo -e "${GREEN}#                  ${RED}Maddy Mail邮件服务器一键脚本             ${GREEN}#${NC}"
echo -e "${GREEN}#                     作者: ${YELLOW}你挺能闹啊🍏                     ${GREEN}#${NC}"
echo -e "${GREEN}#############################################################${NC}"
echo ""

read -p "确认执行此脚本？[按y确认，按任意键退出]: " confirm
if [ "$confirm" != "y" ]; then
    exit 1
fi

# 设置运行环境变量
if [[ $(whoami) != "root" ]]; then
    echo -e "${RED}请以root身份执行该脚本"
    exit 1
fi

OS=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|CentOS" | head -n 1)

if [[ $OS != "Debian" && $OS != "Ubuntu" && $OS != "CentOS" ]]; then
    echo -e "${RED}很抱歉，你的系统不受支持！${NC}"
    exit 1
fi

if [[ $OS == "CentOS" ]]; then
    CMD_INSTALL="yum install -y"
    CMD_REMOVE="yum remove -y"
    CMD_UPGRADE="yum update -y"
    ${CMD_UPGRADE}
    ${CMD_INSTALL} cronie telnet glibc-devel
    systemctl restart crond
    systemctl enable crond
else
    CMD_INSTALL="apt install -y"
    CMD_REMOVE="apt remove -y"
    CMD_REMOVE1="apt upgrade -y && apt autoremove -y"
    CMD_UPGRADE="apt update -y"
    ${CMD_UPGRADE}
    ${CMD_INSTALL} cron telnet libc6-dev
    systemctl restart cron
    systemctl enable cron
fi

# 检查25端口是否开放
mailport=25
timeout=3

if echo "quit" | timeout $timeout telnet smtp.qq.com $port | grep 'Connected'; then
    echo -e "$YELLOW端口 $mailport 当前 $GREEN可用$NC"
else
    echo -e "$RED端口 $mailport 未开放$NC"
    echo -e "$YELLOW请关闭防火墙或放行25端口。注意！！！某些服务商的vps关闭25端口，请更换vps。$NC"
    exit 1
fi

uname_f=$(uname -m)
if [[ $uname_f == "x86_64" ]]; then
    jg="amd64"
elif [[ $uname_f == "aarch64" ]]; then
    jg="arm64"
else
    echo "无法识别的架构"
    exit 1
fi

# 安装依赖
${CMD_INSTALL} wget curl git tar socat openssl lsof acl gcc make

# 安装acme
install_acme() {
    cd ~
    git clone https://github.com/acmesh-official/acme.sh.git
    cd ./acme.sh
    read -rp "请输入注册邮箱 (例: my@example.com, 或留空自动生成一个gmail邮箱): " acmeEmail
    if [[ -z $acmeEmail ]]; then
        autoEmail=$(date +%s%N | md5sum | cut -c 1-16)
        acmeEmail=$autoEmail@gmail.com
        echo -e "${YELLOW}已取消设置邮箱, 使用自动生成的gmail邮箱: $acmeEmail${NC}"
    fi
    ./acme.sh --install -m ${acmeEmail}
    bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        echo -e "${GREEN}Acme.sh证书申请脚本安装成功!${NC}"
    else
        echo -e "${RED}抱歉, Acme.sh证书申请脚本安装失败${NC}"
        echo -e "${GREEN}建议如下：${NC}"
        echo -e "${YELLOW}1. 检查VPS的网络环境${NC}"
        echo -e "${YELLOW}2. 脚本可能跟不上时代, 请更换其他脚本${NC}"
        exit 1
    fi
}

# 检查80端口是否占用
check_80() {
    echo -e "${YELLOW}正在检测80端口是否占用...${NC}"
    sleep 1

    if [[ $(lsof -i:"80" | grep -i -c "listen") -eq 0 ]]; then
        echo -e "${GREEN}检测到目前80端口未被占用${NC}"
        sleep 1
    else
        echo -e "${RED}检测到目前80端口被其他程序被占用，以下为占用程序信息${NC}"
        lsof -i:"80"
        read -rp "如需结束占用进程请按Y，按其他键则退出 [Y/N]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            RUNPID=$(lsof -i:"80" | awk '{print $2}' | grep -v "PID" | head -n 1)
            kill -9 ${RUNPID}
            sleep 1
        else
            exit 1
        fi
    fi
}
switch_provider() {
    echo -e "${YELLOW}请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书 ${NC}"
    echo -e "${YELLOW}如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请.${NC}"
    echo -e " ${GREEN}1.${NC} Letsencrypt.org"
    echo -e " ${GREEN}2.${NC} BuyPass.com"
    echo -e " ${GREEN}3.${NC} ZeroSSL.com"
    read -rp "请选择证书提供商 [1-3，默认1]: " provider
    case $provider in
    2) bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && echo -e "${GREEN}切换证书提供商为 BuyPass.com 成功！${NC}" ;;
    3) bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && echo -e "${GREEN}切换证书提供商为 ZeroSSL.com 成功！${NC}" ;;
    *) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && echo -e "${GREEN}切换证书提供商为 Letsencrypt.org 成功！${NC}" ;;
    esac
    runacme
}
checktls() {
    if [[ -f "$CERT1PATH"/${domain}/fullchain.pem && -f "$CERT1PATH"/${domain}/privkey.pem ]]; then
        if [[ -s "$CERT1PATH"/${domain}/fullchain.pem && -s "$CERT1PATH"/${domain}/privkey.pem ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl restart warp-go
            fi
            echo $domain >/root/ca.log
            echo -e "${GREEN}证书申请成功! 脚本申请到的证书 fullchain.pem 和私钥 privkey.pem 文件已保存到 "$CERT1PATH"/${domain} 路径下${NC}"
            echo -e "${GREEN}证书crt文件路径如下: "$CERT1PATH"/${domain}/fullchain.pem${NC}"
            echo -e "${GREEN}私钥key文件路径如下: "$CERT1PATH"/${domain}/privkey.pem${NC}"
            sleep 5
        else
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl restart warp-go
            fi
            echo -e "${RED}很抱歉，证书申请失败${NC}"
            echo -e "${GREEN}建议如下: ${NC}"
            echo -e "${YELLOW}1. 自行检测防火墙是否打开, 如使用80端口申请模式时, 请关闭防火墙或放行80端口${NC}"
            echo -e "${YELLOW}2. 脚本可能跟不上时代, 建议更换其他脚本${NC}"
            echo -e "${YELLOW}3. 同一域名多次申请可能会触发Let's Encrypt官方风控, 请尝试更换证书颁发机构, 再重试申请证书, 或更换域名、或等待7天后再尝试执行脚本${NC}"
            read -rp "请输入“y”退出, 或按任意键切换机构：" switch_provider
            case "$back2menuInput" in
            y) exit 1 ;;
            *) switch_provider ;;
            esac
        fi
    fi
}
runacme() {
    if [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        echo -e "${RED}未安装acme.sh, 执行安装acme.sh${NC}"
        install_acme
    else
        echo -e "${GREEN}acme.sh已安装，继续执行下一步操作${NC}"
    fi
    check_80
    WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
    fi

    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)

    echo ""
    echo -e "${YELLOW}在使用80端口申请模式时, 请先将您的域名解析至你的VPS的真实IP地址, 否则会导致证书申请失败${NC}"
    echo ""
    if [[ -n $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${NC}"
        echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${NC}"
    elif [[ -n $ipv4 && -z $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${NC}"
    elif [[ -z $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${NC}"
    fi
    echo ""
    read -rp "请输入邮件服务器的域名: " domain
    [[ -z $domain ]] && echo -e "${RED}未输入域名，无法执行操作！${NC}" && exit 1
    echo -e "${GREEN}已输入的域名：$domain ${NC}" && sleep 1
    domainIP=$(curl -sm8 ipget.net/?ip="${domain}")

    if [[ $domainIP == $ipv6 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --listen-v6 --insecure
    fi
    if [[ $domainIP == $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --insecure
    fi

    if [[ -n $(echo $domainIP | grep nginx) ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            wg-quick up wgcf >/dev/null 2>&1
        fi
        if [[ -e "/opt/warp-go/warp-go" ]]; then
            systemctl start warp-go
        fi
        echo -e "${RED}域名解析失败, 请检查域名是否正确填写或等待解析完成再执行脚本${NC}"
        exit 1
    elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
        if [[ $domainIP != $ipv4 ]] && [[ $domainIP != $ipv6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go
            fi
            echo -e "${GREEN}域名 ${domain} 目前解析的IP: ($domainIP) ${NC}"
            echo -e "${RED}当前域名解析的IP与当前VPS使用的真实IP不匹配${NC}"
            echo -e "${GREEN}建议如下：${NC}"
            echo -e "${YELLOW}1. 请确保CloudFlare小云朵为关闭状态(仅限DNS), 其他域名解析或CDN网站设置同理${NC}"
            echo -e "${YELLOW}2. 请检查DNS解析设置的IP是否为VPS的真实IP${NC}"
            echo -e "${YELLOW}3. 同一域名多次申请可能会触发Let's Encrypt官方风控, 请尝试更换证书颁发机构, 再重试申请证书, 或更换域名、或等待7天后再尝试执行脚本${NC}"
            read -rp "请输入“y”退出, 或按任意键切换机构：" switch_provider
            case "$back2menuInput" in
            y) exit 1 ;;
            *) switch_provider ;;
            esac
        fi
    fi

    CERT1PATH=/etc/maddy/certs
    mkdir -p $CERT1PATH/${domain}

    bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file "$CERT1PATH"/${domain}/privkey.pem --fullchain-file "$CERT1PATH"/${domain}/fullchain.pem
    checktls
}
runacme

# 获取golang最新版本
GO_VERSION=$(curl -s https://go.dev/dl/ | grep "download downloadBox" | awk -F 'href="/dl/go|\\.' '{print "go"$2"."$3"."$4}' | uniq)

# 安装golang临时环境
cd ~
wget https://go.dev/dl/${GO_VERSION}.linux-${jg}.tar.gz
tar xvf ${GO_VERSION}.linux-${jg}.tar.gz
PATH=$PATH:/root/go/bin

# 编译安装maddy
cd ~
git clone https://github.com/foxcpp/maddy.git ./maddy
cd maddy
bash build.sh
cd build
chmod +x maddy
cp -f maddy /usr/local/bin/
mkdir -p /etc/maddy
cp -f maddy.conf /etc/maddy/
cp -f systemd/maddy.service /etc/systemd/system/

cd /etc/maddy/

read -rp "请输入邮局的主机名，[例如：mail.example.com ] " yjhostname
[[ -z $yjhostname ]] && echo -e "${RED}未输入邮局主机名，无法执行操作！${NC}" && exit 1
YJHOSTNAME="$yjhostname"
echo -e "${GREEN}已输入的主机名：$YJHOSTNAME ${NC}" && sleep 1

read -rp "请输入邮局的主域名，[例如：example.com ] " primary_domain
[[ -z $primary_domain ]] && echo -e "${RED}未输入邮局主域名，无法执行操作！${NC}" && exit 1
PRIMARY_DOMAIN="$primary_domain"
echo -e "${GREEN}已输入的主域名：$PRIMARY_DOMAIN ${NC}" && sleep 1

sed -i "s/^\$(hostname) =.*/\$(hostname) = ${YJHOSTNAME}/g" /etc/maddy/maddy.conf
sed -i "s/^\$\((primary_domain)\) =.*/\$(primary_domain) = ${PRIMARY_DOMAIN}/g" /etc/maddy/maddy.conf

useradd -mrU -s /sbin/nologin -c "maddy mail server" maddy
chown -R maddy:maddy /usr/local/bin/maddy* /etc/maddy
setfacl -R -m u:maddy:rX /etc/maddy/certs/

read -rp "请创建登录的用户名，[例如：admin@example.com ] " usermail
[[ -z $usermail ]] && echo -e "${RED}未输入用户名，无法执行操作！${NC}" && exit 1
USERMAIL="$usermail"
maddy creds create ${USERMAIL}
maddy imap-acct create ${USERMAIL}

systemctl daemon-reload
systemctl restart maddy
systemctl enable maddy

# 删除临时文件
cd ~
rm -rf acme.sh master.tar.gz maddy go ${GO_VERSION}.linux-${jg}.tar.gz
${CMD_REMOVE} gcc make
eval "$CMD_REMOVE1"

# 输出信息
clear
echo -e "${GREEN}#############################################################${NC}"
echo -e "${GREEN}#                  ${RED}Maddy Mail邮件服务器一键脚本             ${GREEN}#${NC}"
echo -e "${GREEN}#                     作者: ${YELLOW}你挺能闹啊🍏                     ${GREEN}#${NC}"
echo -e "${GREEN}#############################################################${NC}"
echo ""
echo -e "${YELLOW}Maddy Mail邮件服务器安装 ${GREEN}成功${NC}"
echo -e "${YELLOW}maddy mail登录用户名是 ${GREEN}${USERMAIL}${NC}"
echo -e "${YELLOW}maddy mail登录密码是 ${GREEN}你刚才设置的密码${NC}"
echo -e "${YELLOW}dns解析教程请访问 ${GREEN}https://maddy.email/tutorials/setting-up/#dns-records ${YELLOW}获取${NC}"
echo ""
