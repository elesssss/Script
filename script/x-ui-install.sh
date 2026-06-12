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

xui_folder="${XUI_MAIN_FOLDER:=/usr/local/x-ui}"
xui_service="${XUI_SERVICE:=/etc/systemd/system}"

arch(){
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${Error} 不支持的 CPU 架构！ ${Plain}" && exit 1 ;;
    esac
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
        apps=("curl" "tar" "jq")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        apps=("curl" "tar" "jq")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" || "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        apps=("curl" "tar" "jq")
    elif [[ "$release" == "fedora" || "$release" == "amzn" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("curl" "tar" "jq")
    elif [[ "$release" == "arch" || "$release" == "manjaro" || "$release" == "parch" ]]; then
        updates="pacman -Syu"
        installs="pacman -Syu --noconfirm"
        apps=("curl" "tar" "jq")
    elif [[ "$release" == "opensuse-tumbleweed" ]]; then
        updates="zypper refresh"
        installs="zypper -q install -y"
        apps=("curl" "tar" "jq")
    fi
}

install_base(){
    check_pmc
    cmds=("curl" "tar" "jq")

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

gen_random_string(){
    local length="$1"
    openssl rand -base64 $((length * 2)) \
        | tr -dc 'a-zA-Z0-9' \
        | head -c "$length"
}

config_after_install(){
    echo -e "${Info} 正在配置面板设置..."
    
    local existing_hasDefaultCredential=$(${xui_folder}/x-ui setting -show true | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    
    local URL_lists=(
        "https://api4.ipify.org"
        "https://ipv4.icanhazip.com"
        "https://v4.api.ipinfo.io/ip"
        "https://ipv4.myexternalip.com/raw"
        "https://4.ident.me"
        "https://check-host.net/ip"
    )
    local server_ip=""
    
    echo -e "${Info} 正在获取服务器公网 IP..."
    for ip_address in "${URL_lists[@]}"; do
        local response=$(curl -s -w "\n%{http_code}" --max-time 3 "${ip_address}" 2> /dev/null)
        local http_code=$(echo "$response" | tail -n1)
        local ip_result=$(echo "$response" | head -n-1 | tr -d '[:space:]"')
        if [[ "${http_code}" == "200" && "${ip_result}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            server_ip="${ip_result}"
            echo -e "${Success} 检测到服务器 IP: ${Green}${server_ip}${Plain}"
            break
        fi
    done

    if [[ -z "$server_ip" ]]; then
        echo -e "${Warning} 无法从任何服务商自动检测到服务器 IP。${Plain}"
        while [[ -z "$server_ip" ]]; do
            read -rp "$(echo -e "${Tip} 请输入服务器的公网 IPv4 地址: ")" server_ip
            server_ip="${server_ip// /}"
            if [[ ! "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo -e "${Error} 无效的 IPv4 地址，请重新输入。${Plain}"
                server_ip=""
            fi
        done
    fi

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_webBasePath=$(gen_random_string 18)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo ""
            local db_label="${Green}SQLite${Plain} (/etc/x-ui/x-ui.db)"

            read -rp "$(echo -e "${Tip} 是否自定义面板端口？(y/n, 默认随机端口): ")" config_confirm
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                while true; do
                    read -rp "$(echo -e "${Tip} 请输入面板端口 (10000-65535): ")" config_port
                    if [[ "$config_port" =~ ^[0-9]+$ ]] && [ "$config_port" -ge 10000 ] && [ "$config_port" -le 65535 ]; then
                        echo -e "${Info} 面板端口: ${Green}${config_port}${Plain}"
                        break
                    else
                        echo -e "${Error} 无效端口，请输入 10000-65535 之间的数字。${Plain}"
                    fi
                done
            else
                local config_port=$(shuf -i 10000-65535 -n 1)
                echo -e "${Info} 已生成随机端口: ${Green}${config_port}${Plain}"
            fi

            echo -e "${Info} 正在应用面板配置..."
            ${xui_folder}/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"

            # 强制使用 HTTP - 清除任何已存在的证书设置
            ${xui_folder}/x-ui cert -webCert "" -webCertKey "" > /dev/null 2>&1

            # 确保面板监听所有接口
            ${xui_folder}/x-ui setting -listenIP "0.0.0.0" > /dev/null 2>&1

            # Retrieve the API token for display
            local config_apiToken=$(${xui_folder}/x-ui setting -getApiToken true | grep -Eo 'apiToken: .+' | awk '{print $2}')

            # Display final credentials and access information
            echo ""
            echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
            echo -e "${Green}                    面板安装完成！                      ${Plain}"
            echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
            echo -e "${Green}用户名:     ${Plain}${config_username}"
            echo -e "${Green}密码:       ${Plain}${config_password}"
            echo -e "${Green}端口:       ${Plain}${config_port}"
            echo -e "${Green}Web根路径:  ${Plain}${config_webBasePath}"
            echo -e "${Green}访问地址:   ${Plain}${Yellow}http://${server_ip}:${config_port}/${config_webBasePath}${Plain}"
            echo -e "${Green}API Token:  ${Plain}${config_apiToken}"
            echo -e "${Green}═══════════════════════════════════════════════════════${Plain}"
            echo -e "${Warning} ⚠ 重要：请妥善保存这些凭据！${Plain}"
            echo -e "${Warning} ⚠ 面板使用纯 HTTP 协议，请确保在受信任的网络环境中使用。${Plain}"
            echo -e "${Warning} ⚠ 如需修改配置，请运行 ${Green}x-ui${Plain} 命令。${Plain}"
        else
            local config_webBasePath=$(gen_random_string 18)
            echo -e "${Warning} WebBasePath 缺失或太短，正在生成新路径...${Plain}"
            ${xui_folder}/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${Success} 新的 Web根路径: ${Green}${config_webBasePath}${Plain}"

            # 确保清除任何现有证书
            ${xui_folder}/x-ui cert -webCert "" -webCertKey "" > /dev/null 2>&1
            echo -e "${Info} 访问地址: ${Yellow}http://${server_ip}:${existing_port}/${config_webBasePath}${Plain}"
        fi
    else
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${Warning} 检测到默认凭据，正在进行安全更新...${Plain}"
            ${xui_folder}/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "${Success} 已生成新的随机登录凭据：${Plain}"
            echo -e "${Green}###############################################${Plain}"
            echo -e "${Green}用户名: ${Plain}${config_username}"
            echo -e "${Green}密码:   ${Plain}${config_password}"
            echo -e "${Green}###############################################${Plain}"
        else
            echo -e "${Success} 用户名、密码和 WebBasePath 已正确设置。${Plain}"
        fi

        # 确保清除任何现有证书
        ${xui_folder}/x-ui cert -webCert "" -webCertKey "" > /dev/null 2>&1
        echo -e "${Info} 访问地址: ${Yellow}http://${server_ip}:${existing_port}/${existing_webBasePath}${Plain}"
    fi

    #echo -e "${Info} 正在执行数据库迁移..."
    #${xui_folder}/x-ui migrate
    #echo -e "${Success} 数据库迁移完成！${Plain}"
}

install_x-ui(){
    install_base
    echo -e "${Info} 开始安装 x-ui 面板..."
    
    cd ${xui_folder%/x-ui}/

    # Download resources
    if [ $# == 0 ]; then
        echo -e "${Info} 正在获取最新版本信息..."
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${Warning} 正在尝试通过 IPv4 获取版本...${Plain}"
            tag_version=$(curl -4 -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            if [[ ! -n "$tag_version" ]]; then
                echo -e "${Error} 获取 x-ui 版本失败，可能是 GitHub API 限制，请稍后再试${Plain}"
                exit 1
            fi
        fi
        echo -e "${Success} 已获取 x-ui 最新版本: ${Green}${tag_version}${Plain}，开始安装..."
        curl -4fLRo ${xui_folder}-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${Error} 下载 x-ui 失败，请确保服务器可访问 GitHub ${Plain}"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"

        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${Error} 请使用更新的版本（至少 v2.3.5），退出安装。${Plain}"
            exit 1
        fi

        url="https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "${Info} 正在安装 x-ui ${tag_version}..."
        curl -4fLRo ${xui_folder}-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${Error} 下载 x-ui 版本失败，请检查该版本是否存在 ${Plain}"
            exit 1
        fi
    fi
    
    echo -e "${Info} 正在下载管理脚本..."
    curl -4fLRo /usr/bin/x-ui-temp https://raw.githubusercontent.com/elesssss/Script/main/script/x-ui.sh
    if [[ $? -ne 0 ]]; then
        echo -e "${Error} 下载 x-ui.sh 失败${Plain}"
        exit 1
    fi

    # Stop x-ui service and remove old resources
    if [[ -e ${xui_folder}/ ]]; then
        echo -e "${Info} 检测到已安装的 x-ui，正在停止服务..."
        if [[ $release == "alpine" ]]; then
            rc-service x-ui stop
        else
            systemctl stop x-ui
        fi
        # Kill any leftover mtg (MTProto) sidecars.
        pkill -f 'mtg-linux-[^ ]* run ' > /dev/null 2>&1 || true
        echo -e "${Info} 正在清理旧文件..."
        rm ${xui_folder}/ -rf
    fi

    # Extract resources and set permissions
    echo -e "${Info} 正在解压文件..."
    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f

    cd x-ui
    chmod +x x-ui
    chmod +x x-ui.sh

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
        if [[ -f bin/mtg-linux-$(arch) ]]; then
            mv bin/mtg-linux-$(arch) bin/mtg-linux-arm
            chmod +x bin/mtg-linux-arm
        fi
    fi
    chmod +x x-ui bin/xray-linux-$(arch)
    if [[ -f bin/mtg-linux-arm ]]; then
        chmod +x bin/mtg-linux-arm
    elif [[ -f bin/mtg-linux-$(arch) ]]; then
        chmod +x bin/mtg-linux-$(arch)
    fi

    # Update x-ui cli and set permission
    mv -f /usr/bin/x-ui-temp /usr/bin/x-ui
    chmod +x /usr/bin/x-ui
    mkdir -p /var/log/x-ui
    
    echo -e "${Info} 正在配置面板..."
    config_after_install

    # Etckeeper compatibility
    if [ -d "/etc/.git" ]; then
        if [ -f "/etc/.gitignore" ]; then
            if ! grep -q "x-ui/x-ui.db" "/etc/.gitignore"; then
                echo "" >> "/etc/.gitignore"
                echo "x-ui/x-ui.db" >> "/etc/.gitignore"
                echo -e "${Success} 已将 x-ui.db 添加到 /etc/.gitignore（etckeeper 兼容）${Plain}"
            fi
        else
            echo "x-ui/x-ui.db" > "/etc/.gitignore"
            echo -e "${Success} 已创建 /etc/.gitignore 并添加 x-ui.db（etckeeper 兼容）${Plain}"
        fi
    fi

    if [[ $release == "alpine" ]]; then
        echo -e "${Info} 正在配置 Alpine OpenRC 服务..."
        curl -4fLRo /etc/init.d/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.rc
        if [[ $? -ne 0 ]]; then
            echo -e "${Error} 下载 x-ui.rc 失败${Plain}"
            exit 1
        fi
        chmod +x /etc/init.d/x-ui
        rc-update add x-ui
        rc-service x-ui start
        echo -e "${Success} OpenRC 服务配置完成！${Plain}"
    else
        # Install systemd service file
        service_installed=false

        if [ -f "x-ui.service" ]; then
            echo -e "${Info} 在解压文件中找到 x-ui.service，正在安装...${Plain}"
            cp -f x-ui.service ${xui_service}/ > /dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                service_installed=true
            fi
        fi

        if [ "$service_installed" = false ]; then
            case "${release}" in
                ubuntu | debian | armbian)
                    if [ -f "x-ui.service.debian" ]; then
                        echo -e "${Info} 在解压文件中找到 x-ui.service.debian，正在安装...${Plain}"
                        cp -f x-ui.service.debian ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
                arch | manjaro | parch)
                    if [ -f "x-ui.service.arch" ]; then
                        echo -e "${Info} 在解压文件中找到 x-ui.service.arch，正在安装...${Plain}"
                        cp -f x-ui.service.arch ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
                *)
                    if [ -f "x-ui.service.rhel" ]; then
                        echo -e "${Info} 在解压文件中找到 x-ui.service.rhel，正在安装...${Plain}"
                        cp -f x-ui.service.rhel ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
            esac
        fi

        # If service file not found in tar.gz, download from GitHub
        if [ "$service_installed" = false ]; then
            echo -e "${Warning} 在 tar.gz 中未找到服务文件，正在从 GitHub 下载...${Plain}"
            case "${release}" in
                ubuntu | debian | armbian)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.debian > /dev/null 2>&1
                    ;;
                arch | manjaro | parch)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.arch > /dev/null 2>&1
                    ;;
                *)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.rhel > /dev/null 2>&1
                    ;;
            esac

            if [[ $? -ne 0 ]]; then
                echo -e "${Error} 从 GitHub 安装 x-ui.service 失败${Plain}"
                exit 1
            fi
            service_installed=true
        fi

        if [ "$service_installed" = true ]; then
            echo -e "${Info} 正在配置 systemd 服务单元...${Plain}"
            chown root:root ${xui_service}/x-ui.service > /dev/null 2>&1
            chmod 644 ${xui_service}/x-ui.service > /dev/null 2>&1
            systemctl daemon-reload
            systemctl enable x-ui
            systemctl start x-ui
            echo -e "${Success} systemd 服务配置完成！${Plain}"
        else
            echo -e "${Error} 安装 x-ui.service 文件失败${Plain}"
            exit 1
        fi
    fi

    echo -e "${Success} x-ui 安装完成，正在运行...${Plain}"
    echo -e 
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

install_x-ui $1
