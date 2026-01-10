#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
check_os() {
    if [[ -e /etc/os-release ]]; then
        . /etc/os-release
        release=$ID
    elif [[ -e /usr/lib/os-release ]]; then
        . /usr/lib/os-release
        release=$ID
    fi

    os_version="${VERSION_ID%%.*}"  # 取整数部分，避免错误

    # 检查最低系统要求
    if [[ "$release" == "ol" ]]; then
        release="oracle"
        if [[ "$os_version" -lt 8 ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 8 或更高版本${plain}" && exit 1
        fi
    elif [[ "$release" == "centos" ]]; then
        if [[ "$os_version" -lt 7 ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 7 或更高版本${plain}" && exit 1
        fi
    elif [[ "$release" == "fedora" ]]; then
        if [[ "$os_version" -lt 36 ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 36 或更高版本${plain}" && exit 1
        fi
    elif [[ "$release" == "openEuler" ]]; then
        if [[ "$os_version" -lt 2203 ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 22.03 或更高版本${plain}" && exit 1
        fi
    elif [[ "$release" == "ubuntu" ]]; then
        if [[ "$os_version" -lt 20 ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 20.04 或更高版本${plain}" && exit 1
        fi
    elif [[ "$release" == "amzn" ]]; then
        if [[ "$os_version" != "2023" ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 2023 或更高版本${plain}" && exit 1
        fi
    elif [[ "$release" == "debian" ]]; then
        if [[ "$os_version" -lt 10 ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 10 或更高版本${plain}" && exit 1
        fi
    elif [[ "$release" == "almalinux" || "$release" == "rocky" ]]; then
        if [[ "$os_version" -lt 8 ]]; then
            echo -e "${red}你的系统是 $release $os_version${plain}"
            echo -e "${red}请使用 $release 8.0 或更高版本${plain}" && exit 1
        fi
    else
        echo -e "${red}抱歉，此脚本不支持您的操作系统。"
        exit 1
    fi
}

check_pmc() {
    check_os
    if [[ "$release" == "debian" || "$release" == "ubuntu" || "$release" == "kali" || "$release" == "armbian" ]]; then
        updates="apt update -y"
        installs="apt install -y"
        apps=("wget" "curl" "tar" "jq")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        apps=("wget" "curl" "tar" "jq")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" || "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        apps=("wget" "curl" "tar" "jq")
    elif [[ "$release" == "fedora" || "$release" == "amzn" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("wget" "curl" "tar" "jq")
    elif [[ "$release" == "arch" || "$release" == "manjaro" || "$release" == "parch" ]]; then
        updates="pacman -Syu"
        installs="pacman -Syu --noconfirm"
        apps=("wget" "curl" "tar" "jq")
    elif [[ "$release" == "opensuse-tumbleweed" ]]; then
        updates="zypper refresh"
        installs="zypper -q install -y"
        apps=("wget" "curl" "tar" "jq")
    fi
}

install_base() {
    check_pmc
    cmds=("wget" "curl" "tar" "jq")
    echo -e "你的系统是${red} $release $os_version ${plain}"
    echo

    for i in "${!cmds[@]}"; do
        if ! which "${cmds[i]}" &>/dev/null; then
            DEPS+=("${apps[i]}")
        fi
    done
    
    if [ ${#DEPS[@]} -gt 0 ]; then
        echo -e " 安装依赖列表：${green}${CMDS[@]}${plain} 请稍后..."
        $updates 
        $installs "${DEPS[@]}" 
    else
        echo -e "${green} 所有依赖已存在，不需要额外安装。${plain}"
    fi
}

check_arch() {
    arch=$(arch)
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="amd64"
    elif [[ $arch == i*86 || $arch == "x86" ]]; then
        arch="386"
    elif [[ $arch == "aarch64" || $arch == "arm64" || $arch == armv8* ]]; then
        arch="arm64"
    elif [[ $arch == "armv7l" || $arch == "armv7" || $arch == arm* ]]; then
        arch="armv7"
    elif [[ $arch == "armv6l" || $arch == "armv6" ]]; then
        arch="armv6"
    elif [[ $arch == "armv5l" || $arch == "armv5" ]]; then
        arch="armv5"
    elif [[ $arch == "s390x" ]]; then
        arch="s390x"
    else
        echo -e "${red}检测到您的架构不支持，请联系作者！${plain}"
        exit 1
    fi

    echo "架构: ${arch}"
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}出于安全考虑，安装/更新完成后需要强制修改端口与账户密码${plain}"
    read -p "确认是否继续,如选择n则跳过本次端口与账户密码设定[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "请设置您的账户名:" config_account
        echo -e "${yellow}您的账户名将设定为:${config_account}${plain}"
        read -p "请设置您的账户密码:" config_password
        echo -e "${yellow}您的账户密码将设定为:${config_password}${plain}"
        read -p "请设置面板访问端口:" config_port
        echo -e "${yellow}您的面板访问端口将设定为:${config_port}${plain}"
        echo -e "${yellow}确认设定,设定中${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}账户密码设定完成${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}面板端口设定完成${plain}"
    else
        echo -e "${red}已取消设定...${plain}"
        if [[ ! -f "/etc/x-ui/x-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            local portTemp=$(echo $RANDOM)
            /usr/local/x-ui/x-ui setting -username ${usernameTemp} -password ${passwordTemp}
            /usr/local/x-ui/x-ui setting -port ${portTemp}
            echo -e "检测到您属于全新安装,出于安全考虑已自动为您生成随机用户与端口:"
            echo -e "###############################################"
            echo -e "${green}面板登录用户名:${usernameTemp}${plain}"
            echo -e "${green}面板登录用户密码:${passwordTemp}${plain}"
            echo -e "${red}面板登录端口:${portTemp}${plain}"
            echo -e "###############################################"
            echo -e "${red}如您遗忘了面板登录相关信息,可在安装完成后输入x-ui,输入选项7查看面板登录信息${plain}"
        else
            echo -e "${red}当前属于版本升级,保留之前设置项,登录方式保持不变,可输入x-ui后键入数字7查看面板登录信息${plain}"
        fi
    fi
}

install_x-ui() {
    systemctl stop x-ui &> /dev/null
    check_arch
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Lsk "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 x-ui 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 x-ui 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 x-ui 最新版本：${last_version}，开始安装"
        wget --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/MHSanaei/3x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 x-ui v$1"
        wget --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    case "${release}" in
        ubuntu | debian | debian | debian | debian | debian | debian | debian | debian | debian | debian | debian)
            cp -f x-ui/x-ui.service.debian /etc/systemd/system/x-ui.service
        ;;
        *)
            cp -f x-ui/x-ui.service.rhel /etc/systemd/system/x-ui.service
        ;;
    esac
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/elesssss/Script/main/script/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${last_version}${plain} 安装完成，面板已启动，"
    echo -e ""
    echo -e "x-ui 管理脚本使用方法: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - 显示管理菜单 (功能更多)"
    echo -e "x-ui start        - 启动 x-ui 面板"
    echo -e "x-ui stop         - 停止 x-ui 面板"
    echo -e "x-ui restart      - 重启 x-ui 面板"
    echo -e "x-ui status       - 查看 x-ui 状态"
    echo -e "x-ui enable       - 设置 x-ui 开机自启"
    echo -e "x-ui disable      - 取消 x-ui 开机自启"
    echo -e "x-ui log          - 查看 x-ui 日志"
    echo -e "x-ui v2-ui        - 迁移本机器的 v2-ui 账号数据至 x-ui"
    echo -e "x-ui update       - 更新 x-ui 面板"
    echo -e "x-ui install      - 安装 x-ui 面板"
    echo -e "x-ui uninstall    - 卸载 x-ui 面板"
    echo -e "x-ui geo          - 更新 geo  数据"
    echo -e "----------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_x-ui $1
