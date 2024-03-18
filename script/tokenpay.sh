#! /bin/bash

# 输出字体颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 设置版权输出
clear
echo -e "${GREEN}#############################################################${NC}"
echo -e "${GREEN}#                  ${RED}TokenPay USDT收款一键脚本                ${GREEN}#${NC}"
echo -e "${GREEN}#                     作者: ${YELLOW}你挺能闹啊🍏                     ${GREEN}#${NC}"
echo -e "${GREEN}#############################################################${NC}"
echo ""

read -p "确认执行此脚本？[按y确认，按任意键退出]: " confirm
if [ "$confirm" != "y" ]; then
    exit 1
fi

# 检查是否为root用户
if [[ $(whoami) != "root" ]]; then
    echo -e "${RED}请以root身份执行该脚本${NC}"
    exit 1
fi

# 检查系统cpu架构
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    echo -e "${YELLOW}当前CPU架构是 ${GREEN}x86_64${NC}"
    echo -e "${GREEN}可以安装TokenPay${NC}"
elif [[ "$arch" == "i386" || "$arch" == "i686" || "$arch" == "armv6l" || "$arch" == "armv7l" || "$arch" == "armv8l" || "$arch" == "aarch64" || "$arch" == "ppc64le" || "$arch" == "s390x" ]]; then
    echo -e "${YELLOW}当前CPU架构是 ${GREEN}$arch${NC}"
    echo -e "${RED}无法安装TokenPay${NC}"
    exit 1
else
    echo -e "${RED}无法识别当前CPU架构${NC}"
    echo -e "${RED}无法安装TokenPay${NC}"
    exit 1
fi

# 检查系统
OS=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|CentOS" | head -n 1)

if [[ "$OS" != "Debian" && "$OS" != "Ubuntu" && "$OS" != "CentOS" ]]; then
    echo -e "${RED}很抱歉，你的系统不受支持！${NC}"
    exit 1
fi

if [[ "$OS" == "CentOS" ]]; then
    CMD_INSTALL="yum install -y"
    CMD_UPGRADE="yum update -y"
    ${CMD_UPGRADE}
    ${CMD_INSTALL} cronie libicu
    systemctl restart crond
    systemctl enable crond
else
    CMD_INSTALL="apt install -y"
    CMD_UPGRADE="apt update -y"
    ${CMD_UPGRADE}
    ${CMD_INSTALL} cron libicu-dev
    systemctl restart cron
    systemctl enable cron
fi

# 安装依赖
${CMD_INSTALL} git socat lsof wget unzip

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
    if [[ -f "$CERT1PATH"/${domain}/cert.pem && -f "$CERT1PATH"/${domain}/key.pem ]]; then
        if [[ -s "$CERT1PATH"/${domain}/cert.pem && -s "$CERT1PATH"/${domain}/key.pem ]]; then
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
            echo -e "${GREEN}证书申请成功! 脚本申请到的证书 cert.pem 和私钥 key.pem 文件已保存到 "$CERT1PATH"/${domain} 路径下${NC}"
            echo -e "${GREEN}证书crt文件路径如下: "$CERT1PATH"/${domain}/cert.pem${NC}"
            echo -e "${GREEN}私钥key文件路径如下: "$CERT1PATH"/${domain}/key.pem${NC}"
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

    CERT1PATH=/etc/nginx/ssl
    mkdir -p $CERT1PATH/${domain}

    bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file "$CERT1PATH"/${domain}/key.pem --fullchain-file "$CERT1PATH"/${domain}/cert.pem
    checktls
}
runacme

# 安装TokenPay
TKP_VERSION=$(curl -s https://github.com/LightCountry/TokenPay/releases/ | grep -o 'TokenPay v[0-9.]*' | grep -o '[0-9.]*' | sort -rn | head -1)
echo -e "${YELLOW}TokenPay最新版本是 ${GREEN}v${TKP_VERSION} ${YELLOW}现在开始安装...${NC}"

echo -e "${YELLOW}避免接口请求频繁被限制，此处申请TRON-PRO-API-KEY ${GREEN}https://www.trongrid.io/dashboard/keys${NC}"
read -rp "请输入TRON-PRO-API-KEY：" tron_api_key
[[ -z $tron_api_key ]] && echo -e "${RED}未输入TRON-PRO-API-KEY，无法执行操作！${NC}" && exit 1
TRON_API_KEY="$tron_api_key"
echo ""

echo -e "${YELLOW}这里填你用来收款的地址${NC}"
read -rp "请输入TRON链地址：" tron_address
[[ -z $tron_address ]] && echo -e "${RED}未输入TRON链地址，无法执行操作！${NC}" && exit 1
TRON_ADDRESS="$tron_address"
echo ""

echo -e "${YELLOW}这里填你用来对接的密钥，例如易支付，独角数卡，可以脸滚键盘${NC}"
read -rp "请输入ApiToken：" apitoken
[[ -z $apitoken ]] && echo -e "${RED}未输入ApiToken，无法执行操作！${NC}" && exit 1
APITOKEN="$apitoken"
echo ""

echo -e "${YELLOW}就是你刚刚申请证书的域名${NC}"
read -rp "请输入TokenPay域名：" websiteurl
[[ -z $websiteurl ]] && echo -e "${RED}未输入TokenPay域名，无法执行操作！${NC}" && exit 1
WEBSITEURL="$websiteurl"
echo ""

echo -e "${YELLOW}这里填你的TG ID，如不知道ID，可给 ${GREEN}@EShpFakaBot ${YELLOW}发送 ${GREEN}/me ${YELLOW}获取用户ID${NC}"
read -rp "请输入你的TG ID：" adminuserid
[[ -z $adminuserid ]] && echo -e "${RED}未输入TG ID，无法执行操作！${NC}" && exit 1
ADMINUSERID="$adminuserid"
echo ""

echo -e "${YELLOW}从 ${GREEN}@BotFather ${YELLOW}创建机器人时，会给你BotToken${NC}"
read -rp "请输入BotToken：" bottoken
[[ -z $bottoken ]] && echo -e "${RED}未输入BotToken，无法执行操作！${NC}" && exit 1
BOTTOKEN="$bottoken"
echo ""

mkdir -p /var/www/TokenPay
cd /var/www/TokenPay
wget https://github.com/LightCountry/TokenPay/releases/download/v${TKP_VERSION}/release-linux-x64.zip
unzip release-linux-x64.zip
rm -f release-linux-x64.zip
cp appsettings.Example.json appsettings.json

sed -i 's/"TRON-PRO-API-KEY": ".*"/"TRON-PRO-API-KEY": "'"$TRON_API_KEY"'"/g' /var/www/TokenPay/appsettings.json

sed -i "s/\"TRON\": \[ \".*\" \]/\"TRON\": \[ \"$TRON_ADDRESS\" \]/g" /var/www/TokenPay/appsettings.json

sed -i 's/"ApiToken": ".*"/"ApiToken": "'"$APITOKEN"'"/g' /var/www/TokenPay/appsettings.json

sed -i 's|"WebSiteUrl": ".*"|"WebSiteUrl": "https://'"$WEBSITEURL"'"|g' /var/www/TokenPay/appsettings.json

sed -i 's/"AdminUserId": .*,/"AdminUserId": '"$ADMINUSERID"',/g' /var/www/TokenPay/appsettings.json

sed -i 's/"BotToken": ".*"/"BotToken": "'"$BOTTOKEN"'"/g' /var/www/TokenPay/appsettings.json

sed -i 's/"Enable": .*,/"Enable": false,/g' /var/www/TokenPay/appsettings.json

cat <<'EOF' >/etc/systemd/system/tokenpay.service
[Unit]
Description=TokenPay Service
After=network.target
Wants=network.target

[Service]
Type=simple
Restart=always
WorkingDirectory=/var/www/TokenPay
ExecStart=/var/www/TokenPay/TokenPay

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart tokenpay
systemctl enable tokenpay

# 安装nginx
if [ $(which nginx) ]; then
    echo -e "${YELLOW}Nginx已安装${NC}"
else
    echo -e "${YELLOW}Nginx未安装，现在开始安装Nginx${NC}"
    ${CMD_INSTALL} nginx
fi

cat <<'EOF' >/etc/nginx/conf.d/tokenpay.conf
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.example.com; # 替换为您的域名

    # 强制https
    if ($scheme = http) {
        return 301 https://$host$request_uri;
    }

    # SSL设置
    ssl_certificate     /etc/nginx/ssl/www.example.com/cert.pem;   # 证书路径
    ssl_certificate_key /etc/nginx/ssl/www.example.com/key.pem;    # 密钥路径
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_buffer_size 8k;

    # 反向代理规则
    location ^~ / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header REMOTE-HOST $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
    }

    #禁止访问的文件或目录
    location ~ ^/(\.user.ini|\.htaccess|\.git|\.env|\.svn|\.project|LICENSE|README.md) {
        return 404;
    }
}
EOF

sed -i "s/www\.example\.com/$WEBSITEURL/g" /etc/nginx/conf.d/tokenpay.conf

systemctl restart nginx
systemctl enable nginx

# 删除临时文件
cd ~
rm -rf acme.sh

# 设置对接信息
clear
echo -e "${GREEN}#############################################################${NC}"
echo -e "${GREEN}#                  ${RED}TokenPay USDT收款一键脚本                ${GREEN}#${NC}"
echo -e "${GREEN}#                     作者: ${YELLOW}你挺能闹啊🍏                     ${GREEN}#${NC}"
echo -e "${GREEN}#############################################################${NC}"
echo ""

echo -e "${YELLOW}TokenPay v$TKP_VERSION安装 ${GREEN}成功${NC}"
echo -e "${YELLOW}对接url ${GREEN}https://${WEBSITEURL}${NC}"
echo -e "${YELLOW}对接密钥 ${GREEN}${APITOKEN}${NC}"
echo ""
