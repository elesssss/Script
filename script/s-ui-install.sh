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

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${Error} 请以root权限运行此脚本 \n " && exit 1

check_arch(){
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
        echo -e "${Error} 检测到您的架构不支持，请联系作者！${Plain}"
        exit 1
    fi

    echo -e "${Info} 架构: ${Green}${arch}${Plain}"
}

check_release(){
    if [[ -e /etc/os-release ]]; then
        . /etc/os-release
        release=$ID
    elif [[ -e /usr/lib/os-release ]]; then
        . /usr/lib/os-release
        release=$ID
    fi
    os_version=$(echo $VERSION_ID | cut -d \" -f2 | cut -d . -f1)

    if [[ "${release}" == "arch" ]]; then
        echo -e "${Info} 您的系统是 Arch Linux${Plain}"
    elif [[ "${release}" == "parch" ]]; then
        echo -e "${Info} 您的系统是 Parch linux${Plain}"
    elif [[ "${release}" == "manjaro" ]]; then
        echo -e "${Info} 您的系统是 Manjaro${Plain}"
    elif [[ "${release}" == "armbian" ]]; then
        echo -e "${Info} 您的系统是 Armbian${Plain}"
    elif [[ "${release}" == "opensuse-tumbleweed" ]]; then
        echo -e "${Info} 您的系统是 OpenSUSE Tumbleweed${Plain}"
    elif [[ "${release}" == "centos" ]]; then
        if [[ ${os_version} -lt 9 ]]; then
            echo -e "${Error} 请使用CentOS 9或以上版本!${Plain}\n" && exit 1
        fi
    elif [[ "${release}" == "ubuntu" ]]; then
        if [[ ${os_version} -lt 22 ]]; then
            echo -e "${Error} 请使用Ubuntu 22或以上版本!${Plain}\n" && exit 1
        fi
    elif [[ "${release}" == "fedora" ]]; then
        if [[ ${os_version} -lt 36 ]]; then
            echo -e "${Error} 请使用Fedora 36或以上版本!${Plain}\n" && exit 1
        fi
    elif [[ "${release}" == "debian" ]]; then
        if [[ ${os_version} -lt 11 ]]; then
            echo -e "${Error} 请使用Debian 12或以上版本!${Plain}\n" && exit 1
        fi
    elif [[ "${release}" == "almalinux" ]]; then
        if [[ ${os_version} -lt 95 ]]; then
            echo -e "${Error} 请使用AlmaLinux 9.5或以上版本!${Plain}\n" && exit 1
        fi
    elif [[ "${release}" == "rocky" ]]; then
        if [[ ${os_version} -lt 95 ]]; then
            echo -e "${Error} 请使用Rocky Linux 9.5或以上版本!${Plain}\n" && exit 1
        fi
    elif [[ "${release}" == "ol" ]]; then
        if [[ ${os_version} -lt 8 ]]; then
            echo -e "${Error} 请使用Oracle Linux 8或以上版本!${Plain}\n" && exit 1
        fi
    else
        echo -e "${Error} 您的操作系统不支持此脚本.${Plain}\n"
        echo "请确保您正在使用以下受支持的操作系统之一:"
        echo "- Ubuntu 22.04+"
        echo "- Debian 12+"
        echo "- CentOS 9+"
        echo "- Fedora 36+"
        echo "- Arch Linux"
        echo "- Parch Linux"
        echo "- Manjaro"
        echo "- Armbian"
        echo "- AlmaLinux 9.5+"
        echo "- Rocky Linux 9.5+"
        echo "- Oracle Linux 8+"
        echo "- OpenSUSE Tumbleweed"
        exit 1
    fi
}

check_pmc(){
    check_release
    if [[ "$release" == "debian" || "$release" == "ubuntu" || "$release" == "kali" ]]; then
        updates="apt update -y"
        installs="apt install -y"
        apps=("wget" "curl" "tar")
    elif [[ "$release" == "opensuse-tumbleweed" ]]; then
        updates="zypper refresh"
        installs="zypper install -y"
        apps=("wget" "curl" "tar")
    elif [[ "$release" == "almalinux" || "$release" == "centos" || "$release" == "rocky" || "$release" == "oracle" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("wget" "curl" "tar")
    elif [[ "$release" == "fedora" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("wget" "curl" "tar")
    elif [[ "$release" == "arch" || "$release" == "manjaro" || "$release" == "parch"  ]]; then
        updates="pacman -Syu"
        installs="pacman -Syu --noconfirm"
        apps=("wget" "curl" "tar")
    fi
}

install_base(){
    check_pmc
    cmds=("wget" "curl" "tar")
    
    for i in "${!cmds[@]}"; do
        if ! which "${cmds[i]}" &>/dev/null; then
            DEPS+=("${apps[i]}")
        fi
    done
    
    if [ ${#DEPS[@]} -gt 0 ]; then
        echo -e "${Info} 安装依赖列表：${Green}${DEPS[*]}${Plain} 请稍后..."
        $updates 
        $installs "${DEPS[@]}" 
        echo -e "${Success} 依赖安装完成！${Plain}"
    else
        echo -e "${Success} 所有依赖已存在，不需要额外安装。${Plain}"
    fi
}

config_after_install(){
    /usr/local/s-ui/sui migrate &>/dev/null
    
    echo -e "${Warning} 安装/更新完成！出于安全考虑，建议修改面板设置。${Plain}"
    read -p "$(echo -e "${Tip} 您是否要继续进行修改 [y/n]？ ")" config_confirm
    if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
        echo -e "${Tip} 请输入${Yellow}面板端口${Plain} (默认值则留空）:"
        read config_port
        echo -e "${Tip} 请输入${Yellow}面板路径${Plain} (默认值则留空):"
        read config_path

        # Sub configuration
        echo -e "${Tip} 请输入${Yellow}订阅端口${Plain} (默认值则留空):"
        read config_subPort
        echo -e "${Tip} 请输入${Yellow}订阅路径${Plain} (默认值则留空):" 
        read config_subPath

        # Set configs
        echo -e "${Info} 正在初始化，请稍候...${Plain}"
        params=""
        [ -z "$config_port" ] || params="$params -port $config_port"
        [ -z "$config_path" ] || params="$params -path $config_path"
        [ -z "$config_subPort" ] || params="$params -subPort $config_subPort"
        [ -z "$config_subPath" ] || params="$params -subPath $config_subPath"
        /usr/local/s-ui/sui setting ${params}

        read -p "$(echo -e "${Tip} 您是否要更改管理员凭据 [y/n]? ")" admin_confirm
        if [[ "${admin_confirm}" == "y" || "${admin_confirm}" == "Y" ]]; then
            # First admin credentials
            read -p "$(echo -e "${Tip} 请设置您的用户名: ")" config_account
            read -p "$(echo -e "${Tip} 请设置您的密码: ")" config_password

            /usr/local/s-ui/sui admin -username ${config_account} -password ${config_password}
        else
            echo -e "${Info} 您当前的管理员凭据: ${Plain}"
            /usr/local/s-ui/sui admin -show 
        fi
    else
        echo -e "${Warning} 已取消配置修改。${Plain}"
        if [[ ! -f "/usr/local/s-ui/db/s-ui.db" ]]; then
            local usernameTemp=admin
            local passwordTemp=admin
            local portTemp=$(shuf -i10000-65000 -n1)
            local pathTemp=app
            local subPortTemp=2094
            local subPathTemp=sub
            
            echo -e "${Info} 检测到全新安装，使用默认登录信息:"
            echo -e "${Green}###############################################${Plain}"
            echo -e "${Green}用户名: ${usernameTemp}${Plain}"
            echo -e "${Green}密码: ${passwordTemp}${Plain}"
            echo -e "${Green}面板端口: ${portTemp}${Plain}"
            echo -e "${Green}面板路径: ${pathTemp}${Plain}"
            echo -e "${Green}订阅端口: ${subPortTemp}${Plain}"
            echo -e "${Green}订阅路径: ${subPathTemp}${Plain}"
            echo -e "${Green}###############################################${Plain}"
            echo -e "${Warning} 如果您忘记了登录信息，您可以输入 ${Green}s-ui${Plain} 进入配置菜单"
            
            /usr/local/s-ui/sui admin -username ${usernameTemp} -password ${passwordTemp} &>/dev/null
            /usr/local/s-ui/sui setting -port ${portTemp} -path ${pathTemp} -subPort ${subPortTemp} -subPath ${subPathTemp} &>/dev/null
        else
            echo -e "${Info} 检测到升级安装，将保留原有设置。${Plain}"
            echo -e "${Warning} 如果您忘记了登录信息，您可以输入 ${Green}s-ui${Plain} 进入配置菜单"
        fi
    fi
}

prepare_services(){
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        echo -e "${Warning} 停止 sing-box 服务... ${Plain}"
        systemctl stop sing-box
        rm -f /usr/local/s-ui/bin/sing-box /usr/local/s-ui/bin/runSingbox.sh /usr/local/s-ui/bin/signal
        echo -e "${Success} sing-box 服务已停止并清理${Plain}"
    fi
    if [[ -e "/usr/local/s-ui/bin" ]]; then
        echo -e "${Green}###############################################################${Plain}"
        echo -e "${Warning} /usr/local/s-ui/bin${Plain} 目录是否存在!"
        echo -e "${Tip} 请检查内容并在迁移后手动删除。 ${Plain}"
        echo -e "${Green}###############################################################${Plain}"
    fi
    systemctl daemon-reload
}

install_s-ui(){
    check_arch
    cd /tmp/

    if [ $# == 0 ]; then
        echo -e "${Info} 正在获取最新版本信息...${Plain}"
        last_version=$(curl -Ls "https://api.github.com/repos/alireza0/s-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${Error} 无法获取 s-ui 版本，这可能是由于 GitHub API 限制所致，请稍后再试${Plain}"
            exit 1
        fi
        echo -e "${Success} 已获取 S-UI 最新版本: ${Green}${last_version}${Plain}，开始安装..."
        wget -N --no-check-certificate -O /tmp/s-ui-linux-${arch}.tar.gz https://github.com/alireza0/s-ui/releases/download/${last_version}/s-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${Error} 下载 s-ui 失败，请确保您的服务器能够访问 GitHub ${Plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/alireza0/s-ui/releases/download/${last_version}/s-ui-linux-${arch}.tar.gz"
        echo -e "${Info} 开始安装 S-UI v${last_version}${Plain}"
        wget -N --no-check-certificate -O /tmp/s-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${Error} 下载 s-ui v${last_version} 失败，请确认该版本是否存在。${Plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/s-ui/ ]]; then
        echo -e "${Info} 检测到已安装的 S-UI，正在停止服务...${Plain}"
        systemctl stop s-ui
    fi

    echo -e "${Info} 正在解压文件...${Plain}"
    tar zxvf s-ui-linux-${arch}.tar.gz
    rm s-ui-linux-${arch}.tar.gz -f

    echo -e "${Info} 正在下载管理脚本...${Plain}"
    wget -O /usr/bin/s-ui -N --no-check-certificate https://raw.githubusercontent.com/elesssss/Script/main/script/s-ui.sh
    chmod +x /usr/bin/s-ui
    
    cp -rf s-ui /usr/local/
    cp -f s-ui/*.service /etc/systemd/system/
    rm -rf s-ui
    config_after_install
    prepare_services
    systemctl enable s-ui --now
    echo -e ""
    echo -e "${Green}s-ui v${last_version}${Plain} 安装完成，现在已经正常运行了..."
    echo -e "${Info} 您可以通过以下 URL 访问面板:"${Green}
    /usr/local/s-ui/sui uri
    echo -e "${Plain}"
    echo -e ""
    s-ui help
}

install_base
install_s-ui $1
