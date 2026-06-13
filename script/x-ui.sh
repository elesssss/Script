#!/bin/bash

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

# consts for log check and clear,unit:M
declare -r DEFAULT_LOG_FILE_DELETE_TRIGGER=35

# consts for geo update
PATH_FOR_GEO_IP='/usr/local/x-ui/bin/geoip.dat'
PATH_FOR_CONFIG='/usr/local/x-ui/bin/config.json'
PATH_FOR_GEO_SITE='/usr/local/x-ui/bin/geosite.dat'
URL_FOR_GEO_IP='https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat'
URL_FOR_GEO_SITE='https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat'

# check root
[[ $EUID -ne 0 ]] && echo -e "${Error} 必须使用root用户运行此脚本!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${Error} 未检测到系统版本，请联系脚本作者！\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${Error} 请使用 CentOS 7 或更高版本的系统！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${Error} 请使用 Ubuntu 16 或更高版本的系统！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${Error} 请使用 Debian 8 或更高版本的系统！\n" && exit 1
    fi
fi

confirm(){
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart(){
    confirm "是否重启面板，重启面板也会重启 xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu(){
    echo && echo -n -e "${Tip} 按回车返回主菜单: ${Plain}" && read temp
    show_menu
}

install(){
    echo -e "${Info} 正在执行安装脚本..."
    bash <(curl -Ls https://raw.githubusercontent.com/elesssss/Script/main/script/x-ui-install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${Success} 安装成功！"
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    else
        echo -e "${Error} 安装失败！"
    fi
}

update(){
    confirm "本功能会强制重装当前最新版，数据不会丢失，是否继续?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${Error} 已取消"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    echo -e "${Info} 正在执行更新脚本..."
    bash <(curl -Ls https://raw.githubusercontent.com/elesssss/Script/main/script/x-ui-install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${Success} 更新完成，已自动重启面板"
        exit 0
    else
        echo -e "${Error} 更新失败！"
    fi
}

uninstall(){
    confirm "确定要卸载面板吗，xray 也会被卸载?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    
    echo -e "${Info} 正在停止服务..."
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    
    echo -e "${Info} 正在清理文件..."
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf
    rm /usr/bin/x-ui -f

    echo ""
    echo -e "${Success} x-ui 卸载成功"
    echo ""

    exit
}

reset_user(){
    confirm "确定要将用户名和密码重置为 admin 吗" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "${Success} 用户名和密码已重置为 ${Green}admin${Plain}"
    echo -e "${Tip} 现在请重启面板${Plain}"
    confirm_restart
}

reset_config(){
    confirm "确定要重置所有面板设置吗？账号数据不会丢失，用户名和密码不会改变" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "${Success} 所有面板设置已重置为默认值"
    echo -e "${Tip} 现在请重启面板，并使用默认的 ${Green}2053${Plain} 端口访问面板${Plain}"
    confirm_restart
}

check_config(){
    info=$(/usr/local/x-ui/x-ui setting -show true)
    if [[ $? != 0 ]]; then
        echo -e "${Error} 获取当前设置失败，请检查日志"
        show_menu
    fi
    echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
    echo -e "${Info} 当前面板配置:${Plain}"
    echo -e "${Green}─────────────────────────────────────────────────────${Plain}"
    echo "$info"
    echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
}

set_port(){
    echo && echo -n -e "${Tip} 输入端口号[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${Warning} 已取消"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "${Success} 端口已设置为: ${Green}${port}${Plain}"
        echo -e "${Tip} 现在请重启面板，并使用新端口访问面板${Plain}"
        confirm_restart
    fi
}

start(){
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${Info} 面板已运行，无需再次启动，如需重启请选择重启"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${Success} x-ui 启动成功"
        else
            echo -e "${Error} 面板启动失败，可能是因为启动时间超过了两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop(){
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${Info} 面板已停止，无需再次停止"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${Success} x-ui 与 xray 停止成功"
        else
            echo -e "${Error} 面板停止失败，可能是因为停止时间超过了两秒，请稍后查看日志信息"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart(){
    echo -e "${Info} 正在重启面板..."
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${Success} x-ui 与 xray 重启成功"
    else
        echo -e "${Error} 面板重启失败，可能是因为启动时间超过了两秒，请稍后查看日志信息"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status(){
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable(){
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${Success} x-ui 设置开机自启成功"
    else
        echo -e "${Error} x-ui 设置开机自启失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable(){
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        echo -e "${Success} x-ui 取消开机自启成功"
    else
        echo -e "${Error} x-ui 取消开机自启失败"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log(){
    echo -e "${Info} 正在查看面板日志 (Ctrl+C 退出)${Plain}"
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui(){
    echo -e "${Info} 正在迁移 v2-ui 数据..."
    /usr/local/x-ui/x-ui v2-ui
    echo -e "${Success} 迁移完成！"
    before_show_menu
}

install_bbr(){
    echo -e "${Info} 正在安装 BBR...${Plain}"
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell(){
    echo -e "${Info} 正在更新管理脚本..."
    wget -O /usr/bin/x-ui -N --no-check-certificate https://raw.githubusercontent.com/elesssss/Script/main/script/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${Error} 下载脚本失败，请检查本机能否连接 Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        echo -e "${Success} 脚本更新成功，请重新运行脚本" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status(){
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled(){
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall(){
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${Error} 面板已安装，请不要重复安装"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install(){
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${Error} 请先安装面板"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status(){
    check_status
    case $? in
    0)
        echo -e "面板状态: ${Green}已运行${Plain}"
        show_enable_status
        ;;
    1)
        echo -e "面板状态: ${Yellow}未运行${Plain}"
        show_enable_status
        ;;
    2)
        echo -e "面板状态: ${Red}未安装${Plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status(){
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "是否开机自启: ${Green}是${Plain}"
    else
        echo -e "是否开机自启: ${Red}否${Plain}"
    fi
}

check_xray_status(){
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status(){
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray 状态: ${Green}运行${Plain}"
    else
        echo -e "xray 状态: ${Red}未运行${Plain}"
    fi
}

# SSL certificate issue functions
ssl_cert_issue(){
    local method=""
    echo -E ""
    echo -e "${Warning} ******使用说明******${Plain}"
    echo -e "${Info} 该脚本提供两种方式实现证书签发，证书安装路径均为/root/cert${Plain}"
    echo -e "${Info} 方式1: acme standalone mode，需要保持端口开放${Plain}"
    echo -e "${Info} 方式2: acme DNS API mode，需要提供Cloudflare Global API Key${Plain}"
    echo -e "${Info} 如域名属于免费域名，则推荐使用方式1进行申请${Plain}"
    echo -e "${Info} 如域名非免费域名且使用Cloudflare进行解析，使用方式2进行申请${Plain}"
    read -p "请选择你想使用的方式，输入数字1或者2后回车: " method
    echo -e "${Info} 你所使用的方式为 ${method}${Plain}"

    if [ "${method}" == "1" ]; then
        ssl_cert_issue_standalone
    elif [ "${method}" == "2" ]; then
        ssl_cert_issue_by_cloudflare
    else
        echo -e "${Error} 输入无效，请检查你的输入，脚本将退出...${Plain}"
        exit 1
    fi
}

install_acme(){
    cd ~
    echo -e "${Info} 开始安装acme脚本...${Plain}"
    curl https://get.acme.sh | sh
    if [ $? -ne 0 ]; then
        echo -e "${Error} acme安装失败${Plain}"
        return 1
    else
        echo -e "${Success} acme安装成功${Plain}"
    fi
    return 0
}

#method for standalone mode
ssl_cert_issue_standalone(){
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${Error} 安装 acme 失败，请检查日志${Plain}"
            exit 1
        fi
    fi
    
    if [[ x"${release}" == x"centos" ]]; then
        yum install socat -y
    else
        apt install socat -y
    fi
    if [ $? -ne 0 ]; then
        echo -e "${Error} 无法安装socat，请检查错误日志${Plain}"
        exit 1
    else
        echo -e "${Success} socat安装成功${Plain}"
    fi
    
    certPath=/root/cert
    if [ ! -d "$certPath" ]; then
        mkdir $certPath
    fi
    
    local domain=""
    read -p "请输入你的域名: " domain
    echo -e "${Warning} 你输入的域名为: ${domain}，正在进行域名合法性校验...${Plain}"
    
    local currentCert=$(~/.acme.sh/acme.sh --list | grep ${domain} | wc -l)
    if [ ${currentCert} -ne 0 ]; then
        local certInfo=$(~/.acme.sh/acme.sh --list)
        echo -e "${Error} 域名合法性校验失败，当前环境已有对应域名证书，不可重复申请${Plain}"
        echo -e "${Info} $certInfo${Plain}"
        exit 1
    else
        echo -e "${Info} 域名合法性校验通过${Plain}"
    fi
    
    local WebPort=80
    read -p "请输入你所希望使用的端口，如回车将使用默认80端口: " WebPort
    if [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        echo -e "${Error} 你所选择的端口 ${WebPort} 为无效值，将使用默认80端口进行申请${Plain}"
        WebPort=80
    fi
    echo -e "${Info} 将会使用 ${WebPort} 进行证书申请，请确保端口处于开放状态${Plain}"
    
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --httpport ${WebPort}
    if [ $? -ne 0 ]; then
        echo -e "${Error} 证书申请失败，原因请参见报错信息${Plain}"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        echo -e "${Success} 证书申请成功，开始安装证书${Plain}"
    fi
    
    ~/.acme.sh/acme.sh --installcert -d ${domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${domain}.cer --key-file /root/cert/${domain}.key \
        --fullchain-file /root/cert/fullchain.cer

    if [ $? -ne 0 ]; then
        echo -e "${Error} 证书安装失败，脚本退出${Plain}"
        rm -rf ~/.acme.sh/${domain}
        exit 1
    else
        echo -e "${Success} 证书安装成功，开启自动更新${Plain}"
    fi
    
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${Error} 自动更新设置失败，脚本退出${Plain}"
        ls -lah cert
        chmod 755 $certPath
        exit 1
    else
        echo -e "${Success} 证书已安装且已开启自动更新${Plain}"
        ls -lah cert
        chmod 755 $certPath
    fi
}

#method for DNS API mode
ssl_cert_issue_by_cloudflare(){
    echo -E ""
    echo -e "${Warning} ******使用说明******${Plain}"
    echo -e "${Info} 该脚本将使用Acme脚本申请证书，使用时需保证:${Plain}"
    echo -e "${Info} 1. 知晓Cloudflare注册邮箱${Plain}"
    echo -e "${Info} 2. 知晓Cloudflare Global API Key${Plain}"
    echo -e "${Info} 3. 域名已通过Cloudflare解析到当前服务器${Plain}"
    echo -e "${Info} 4. 该脚本申请证书默认安装路径为/root/cert目录${Plain}"
    confirm "我已确认以上内容[y/n]" "y"
    if [ $? -eq 0 ]; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${Error} 无法安装acme，请检查错误日志${Plain}"
            exit 1
        fi
        
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        fi
        
        echo -e "${Tip} 请设置域名:${Plain}"
        read -p "Input your domain here: " CF_Domain
        echo -e "${Warning} 你的域名设置为: ${CF_Domain}，正在进行域名合法性校验...${Plain}"
        
        local currentCert=$(~/.acme.sh/acme.sh --list | grep ${CF_Domain} | wc -l)
        if [ ${currentCert} -ne 0 ]; then
            local certInfo=$(~/.acme.sh/acme.sh --list)
            echo -e "${Error} 域名合法性校验失败，当前环境已有对应域名证书，不可重复申请${Plain}"
            echo -e "${Info} $certInfo${Plain}"
            exit 1
        else
            echo -e "${Info} 域名合法性校验通过${Plain}"
        fi
        
        echo -e "${Tip} 请设置API密钥:${Plain}"
        read -p "Input your key here: " CF_GlobalKey
        echo -e "${Tip} 请设置注册邮箱:${Plain}"
        read -p "Input your email here: " CF_AccountEmail
        
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            echo -e "${Error} 修改默认CA为Let's Encrypt失败，脚本退出${Plain}"
            exit 1
        fi
        
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            echo -e "${Error} 证书签发失败，脚本退出${Plain}"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            echo -e "${Success} 证书签发成功，安装中${Plain}"
        fi
        
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
            --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
            --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            echo -e "${Error} 证书安装失败，脚本退出${Plain}"
            rm -rf ~/.acme.sh/${CF_Domain}
            exit 1
        else
            echo -e "${Success} 证书安装成功，开启自动更新${Plain}"
        fi
        
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            echo -e "${Error} 自动更新设置失败，脚本退出${Plain}"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            echo -e "${Success} 证书已安装且已开启自动更新${Plain}"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

#add for cron jobs,including sync geo data,check logs and restart x-ui
cron_jobs(){
    clear
    echo -e "
  ${Green}定时任务管理${Plain}
  ${Green}0.${Plain}  返回主菜单
  ${Green}1.${Plain}  开启定时更新geo
  ${Green}2.${Plain}  关闭定时更新geo
  ${Green}3.${Plain}  开启定时删除xray日志
  ${Green}4.${Plain}  关闭定时删除xray日志
  "
    echo && read -p "请输入选择 [0-4]: " num
    case "${num}" in
    0)
        show_menu
        ;;
    1)
        enable_auto_update_geo
        ;;
    2)
        disable_auto_update_geo
        ;;
    3)
        enable_auto_clear_log
        ;;
    4)
        disable_auto_clear_log
        ;;
    *)
        echo -e "${Error} 请输入正确的数字 [0-4]${Plain}"
        ;;
    esac
}

#update geo data
update_geo(){
    echo -e "${Info} 正在更新 geo 数据...${Plain}"
    
    mv ${PATH_FOR_GEO_IP} ${PATH_FOR_GEO_IP}.bak 2>/dev/null
    curl -s -L -o ${PATH_FOR_GEO_IP} ${URL_FOR_GEO_IP}
    if [[ $? -ne 0 ]]; then
        echo -e "${Error} 更新 geoip.dat 失败${Plain}"
        mv ${PATH_FOR_GEO_IP}.bak ${PATH_FOR_GEO_IP} 2>/dev/null
    else
        echo -e "${Success} 更新 geoip.dat 成功${Plain}"
        rm -f ${PATH_FOR_GEO_IP}.bak 2>/dev/null
    fi
    
    mv ${PATH_FOR_GEO_SITE} ${PATH_FOR_GEO_SITE}.bak 2>/dev/null
    curl -s -L -o ${PATH_FOR_GEO_SITE} ${URL_FOR_GEO_SITE}
    if [[ $? -ne 0 ]]; then
        echo -e "${Error} 更新 geosite.dat 失败${Plain}"
        mv ${PATH_FOR_GEO_SITE}.bak ${PATH_FOR_GEO_SITE} 2>/dev/null
    else
        echo -e "${Success} 更新 geosite.dat 成功${Plain}"
        rm -f ${PATH_FOR_GEO_SITE}.bak 2>/dev/null
    fi
    
    systemctl restart x-ui
    echo -e "${Success} geo 数据更新完成，面板已重启${Plain}"
}

enable_auto_update_geo(){
    echo -e "${Info} 正在开启自动更新geo数据...${Plain}"
    crontab -l >/tmp/crontabTask.tmp 2>/dev/null
    echo "00 4 */2 * * x-ui geo > /dev/null" >>/tmp/crontabTask.tmp
    crontab /tmp/crontabTask.tmp
    rm /tmp/crontabTask.tmp
    echo -e "${Success} 自动更新geo数据已开启${Plain}"
}

disable_auto_update_geo(){
    crontab -l | grep -v "x-ui geo" | crontab -
    if [[ $? -ne 0 ]]; then
        echo -e "${Error} 取消自动更新geo数据失败${Plain}"
    else
        echo -e "${Success} 自动更新geo数据已取消${Plain}"
    fi
}

#clear xray log
clear_log(){
    echo -e "${Info} 正在清除xray日志...${Plain}"
    local filePath=''
    if [[ $# -gt 0 ]]; then
        filePath=$1
    else
        echo -e "${Error} 未输入有效文件路径，脚本退出${Plain}"
        exit 1
    fi
    echo -e "${Info} 日志路径为: ${filePath}${Plain}"
    if [[ ! -f ${filePath} ]]; then
        echo -e "${Error} 日志文件不存在: ${filePath}${Plain}"
        exit 1
    fi
    fileSize=$(ls -la ${filePath} --block-size=M 2>/dev/null | awk '{print $5}' | awk -F 'M' '{print$1}')
    if [[ ${fileSize} -gt ${DEFAULT_LOG_FILE_DELETE_TRIGGER} ]]; then
        rm $1
        if [[ $? -ne 0 ]]; then
            echo -e "${Error} 清除日志文件失败: ${filePath}${Plain}"
        else
            echo -e "${Success} 清除日志文件成功: ${filePath}${Plain}"
            systemctl restart x-ui
        fi
    else
        echo -e "${Info} 当前日志大小为 ${fileSize}M，小于 ${DEFAULT_LOG_FILE_DELETE_TRIGGER}M，将不会清除${Plain}"
    fi
}

#enable auto delete log
enable_auto_clear_log(){
    echo -e "${Info} 正在设置定时清除xray日志...${Plain}"
    local accessfilePath=''
    local errorfilePath=''
    accessfilePath=$(cat ${PATH_FOR_CONFIG} | jq .log.access 2>/dev/null | tr -d '"')
    errorfilePath=$(cat ${PATH_FOR_CONFIG} | jq .log.error 2>/dev/null | tr -d '"')
    if [[ ! -n ${accessfilePath} && ! -n ${errorfilePath} ]]; then
        echo -e "${Error} 配置文件中的日志文件路径无效，脚本退出${Plain}"
        exit 1
    fi
    
    if [[ -f ${accessfilePath} ]]; then
        crontab -l >/tmp/crontabTask.tmp 2>/dev/null
        echo "30 4 */2 * * x-ui clear ${accessfilePath} > /dev/null" >>/tmp/crontabTask.tmp
        crontab /tmp/crontabTask.tmp
        rm /tmp/crontabTask.tmp
        echo -e "${Success} 定时清除日志已设置: ${accessfilePath}${Plain}"
    else
        echo -e "${Error} accesslog 不存在，将不会为其设置定时清除${Plain}"
    fi

    if [[ -f ${errorfilePath} ]]; then
        crontab -l >/tmp/crontabTask.tmp 2>/dev/null
        echo "30 4 */2 * * x-ui clear ${errorfilePath} > /dev/null" >>/tmp/crontabTask.tmp
        crontab /tmp/crontabTask.tmp
        rm /tmp/crontabTask.tmp
        echo -e "${Success} 定时清除日志已设置: ${errorfilePath}${Plain}"
    else
        echo -e "${Error} errorlog 不存在，将不会为其设置定时清除${Plain}"
    fi
}

#disable auto delete log
disable_auto_clear_log(){
    crontab -l | grep -v "x-ui clear" | crontab -
    if [[ $? -ne 0 ]]; then
        echo -e "${Error} 取消定时清除xray日志失败${Plain}"
    else
        echo -e "${Success} 定时清除xray日志已取消${Plain}"
    fi
}

show_usage(){
    echo -e "┌───────────────────────────────────────────────────────┐
│  x-ui 控制菜单用法（子命令）：                        │
│                                                       │
│  ${Blue}x-ui${Plain}              - 管理脚本                         │
│  ${Blue}x-ui start${Plain}        - 启动                             │
│  ${Blue}x-ui stop${Plain}         - 停止                             │
│  ${Blue}x-ui restart${Plain}      - 重启                             │
│  ${Blue}x-ui status${Plain}       - 当前状态                         │
│  ${Blue}x-ui settings${Plain}     - 当前设置                         │
│  ${Blue}x-ui enable${Plain}       - 开启开机自启                     │
│  ${Blue}x-ui disable${Plain}      - 关闭开机自启                     │
│  ${Blue}x-ui log${Plain}          - 查看日志                         │
│  ${Blue}x-ui banlog${Plain}       - 查看 Fail2ban 封禁日志           │
│  ${Blue}x-ui update${Plain}       - 更新                             │
│  ${Blue}x-ui legacy${Plain}       - 历史版本                         │
│  ${Blue}x-ui install${Plain}      - 安装                             │
│  ${Blue}x-ui uninstall${Plain}    - 卸载                             │
└───────────────────────────────────────────────────────┘"
}

show_menu(){
    echo -e "
  ${Green}x-ui 面板管理脚本${plain}\n
  ${Green}0.${Plain} 退出脚本
————————————————
  ${Green}1.${Plain} 安装 x-ui
  ${Green}2.${Plain} 更新 x-ui
  ${Green}3.${Plain} 卸载 x-ui
————————————————
  ${Green}4.${Plain} 重置用户名密码
  ${Green}5.${Plain} 重置面板设置
  ${Green}6.${Plain} 设置面板端口
  ${Green}7.${Plain} 查看当前面板信息
————————————————
  ${Green}8.${Plain} 启动 x-ui
  ${Green}9.${Plain} 停止 x-ui
  ${Green}10.${Plain} 重启 x-ui
  ${Green}11.${Plain} 查看 x-ui 状态
  ${Green}12.${Plain} 查看 x-ui 日志
————————————————
  ${Green}13.${Plain} 设置 x-ui 开机自启
  ${Green}14.${Plain} 取消 x-ui 开机自启
————————————————
  ${Green}15.${Plain} 一键安装 bbr (最新内核)
  ${Green}16.${Plain} 一键申请SSL证书(acme申请)
  ${Green}17.${Plain} 配置x-ui定时任务"
    show_status
    echo && read -p "请输入选择 [0-17]: " num

    case "${num}" in
    0)
        echo -e "${Tip} 感谢使用，再见！${Plain}"
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    17)
        check_install && cron_jobs
        ;;
    *)
        echo -e "${Error} 请输入正确的数字 [0-17]${Plain}"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    "geo")
        check_install 0 && update_geo
        ;;
    "clear")
        check_install 0 && clear_log $2
        ;;
    "cron")
        check_install && cron_jobs
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
