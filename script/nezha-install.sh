#!/bin/sh

NZ_BASE_PATH="/var/nezha"
NZ_AGENT_PATH="${NZ_BASE_PATH}/agent"
NZ_AGENT_SERVICE="/lib/systemd/system/agent.service"

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


err() {
    printf "${Red}%s${Nc}\n" "$*" >&2
}

success() {
    printf "${Green}%s${Nc}\n" "$*"
}

info() {
	printf "${Yellow}%s${Nc}\n" "$*"
}

sudo() {
    myEUID=$(id -ru)
    if [ "$myEUID" -ne 0 ]; then
        if command -v sudo > /dev/null 2>&1; then
            command sudo "$@"
        else
            err "ERROR: sudo is not installed on the system, the action cannot be proceeded."
            exit 1
        fi
    else
        "$@"
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
        apps=("wget" "unzip" "grep" "openssl")
    elif [[ "$release" == "alpine" ]]; then
        updates="apk update -f"
        installs="apk add -f"
        apps=("wget" "unzip" "grep" "openssl")
    elif [[ "$release" == "almalinux" || "$release" == "rocky" || "$release" == "oracle" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        check_install="dnf list installed"
        apps=("wget" "unzip" "grep" "openssl")
    elif [[ "$release" == "centos" ]]; then
        updates="yum update -y"
        installs="yum install -y"
        apps=("wget" "unzip" "grep" "openssl")
    elif [[ "$release" == "fedora" ]]; then
        updates="dnf update -y"
        installs="dnf install -y"
        apps=("wget" "unzip" "grep" "openssl")
    fi
}

install_base(){
    check_pmc
    cmds=("wget" "unzip" "grep" "openssl")
    echo -e "${Info} 你的系统是${Red} $release $os_version ${Nc}"
    echo

    for g in "${!apps[@]}"; do
        if ! which "${apps[$g]}" &> /dev/null; then
            CMDS+=(${cmds[g]})
            DEPS+=("${apps[$g]}")
        fi
    done
    
    if [ ${#DEPS[@]} -gt 0 ]; then
        echo -e "${Tip} 安装依赖列表：${Green}${CMDS[@]}${Nc} 请稍后..."
        $updates 
        $installs "${DEPS[@]}" 
    else
        echo -e "${Info} 所有依赖已存在，不需要额外安装。"
    fi
}

geo_check() {
    api_list="https://blog.cloudflare.com/cdn-cgi/trace https://developers.cloudflare.com/cdn-cgi/trace"
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    set -- "$api_list"
    for url in $api_list; do
        text="$(curl -A "$ua" -m 10 -s "$url")"
        endpoint="$(echo "$text" | sed -n 's/.*h=\([^ ]*\).*/\1/p')"
        if echo "$text" | grep -qw 'CN'; then
            isCN=true
            break
        elif echo "$url" | grep -q "$endpoint"; then
            break
        fi
    done
}

env_check() {
    mach=$(uname -m)
    case "$mach" in
        amd64|x86_64)
            os_arch="amd64"
            ;;
        i386|i686)
            os_arch="386"
            ;;
        aarch64|arm64)
            os_arch="arm64"
            ;;
        *arm*)
            os_arch="arm"
            ;;
        s390x)
            os_arch="s390x"
            ;;
        riscv64)
            os_arch="riscv64"
            ;;
        mips)
            os_arch="mips"
            ;;
        mipsel|mipsle)
            os_arch="mipsle"
            ;;
        *)
            err "Unknown architecture: $uname"
            exit 1
            ;;
    esac

    system=$(uname)
    case "$system" in
        *Linux*)
            os="linux"
            ;;
        *Darwin*)
            os="darwin"
            ;;
        *FreeBSD*)
            os="freebsd"
            ;;
        *)
            err "Unknown architecture: $system"
            exit 1
            ;;
    esac
}

init() {
    install_base
    env_check

    ## China_IP
    if [ -z "$CN" ]; then
        geo_check
        if [ -n "$isCN" ]; then
            CN=true
        fi
    fi

    if [ -z "$CN" ]; then
        GITHUB_URL="github.com"
    else
        GITHUB_URL="gitee.com"
    fi
}

install() {
    echo "Installing..."

    if [ -z "$CN" ]; then
        NZ_AGENT_URL="https://${GITHUB_URL}/nezhahq/agent/releases/latest/download/nezha-agent_${os}_${os_arch}.zip"
    else
        _version=$(curl -m 10 -sL "https://gitee.com/api/v5/repos/naibahq/agent/releases/latest" | awk -F '"' '{for(i=1;i<=NF;i++){if($i=="tag_name"){print $(i+2)}}}')
        NZ_AGENT_URL="https://${GITHUB_URL}/naibahq/agent/releases/download/${_version}/nezha-agent_${os}_${os_arch}.zip"
    fi

    if command -v wget >/dev/null 2>&1; then
        _cmd="wget --timeout=60 -O /tmp/nezha-agent_${os}_${os_arch}.zip \"$NZ_AGENT_URL\" >/dev/null 2>&1"
    elif command -v curl >/dev/null 2>&1; then
        _cmd="curl --max-time 60 -fsSL \"$NZ_AGENT_URL\" -o /tmp/nezha-agent_${os}_${os_arch}.zip >/dev/null 2>&1"
    fi

    if ! eval "$_cmd"; then
        err "Download nezha-agent release failed, check your network connectivity"
        exit 1
    fi

    sudo mkdir -p $NZ_AGENT_PATH

    sudo unzip -qo /tmp/nezha-agent_${os}_${os_arch}.zip -d $NZ_AGENT_PATH &&
        sudo rm -rf /tmp/nezha-agent_${os}_${os_arch}.zip
        mv /var/nezha/agent/nezha-agent /var/nezha/agent/agent
        chmod +x /var/nezha/agent/agent

    path="$NZ_AGENT_PATH/config.yml"

    touch_service

    cat >${path} <<-EOF
client_secret: your_agent_secret
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 3
self_update_period: 0
server: data.example.com:8008
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: false
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: your_uuid
EOF


    if [ $# -lt 3 ]; then
        echo "请先在管理面板上添加Agent，记录下密钥" &&
        read -ep "请输入一个解析到面板所在IP的域名（不可套CDN）: " nz_grpc_host &&
        read -ep "请输入面板RPC端口 (默认值 8008): " nz_grpc_port &&
        read -ep "请输入Agent 密钥: " agent_secret
        if [[ -z "${nz_grpc_host}" || -z "${agent_secret}" ]]; then
            echo -e "${Red}所有选项都不能为空${Nc}"
            exit 1
        fi
        if [[ -z "${nz_grpc_port}" ]]; then
            nz_grpc_port=8008
        fi
        your_uuid=$(openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.*\)/\1-\2-\3-\4-\5/')
    elif [ $# -eq 4 ]; then
        nz_grpc_host=$1
        nz_grpc_port=$2
        agent_secret=$3
        your_uuid=$4
        shift 4
        if [ $# -gt 0 ]; then
            args=" $*"
        fi
    else
        nz_grpc_host=$1
        nz_grpc_port=$2
        agent_secret=$3
        shift 3
        if [ $# -gt 0 ]; then
            args=" $*"
        fi
        your_uuid=$(openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.*\)/\1-\2-\3-\4-\5/')
    fi
    
    sed -i "s/data.example.com/${nz_grpc_host}/" ${path}
    sed -i "s/8008/${nz_grpc_port}/" ${path}
    sed -i "s/your_agent_secret/${agent_secret}/" ${path}
    sed -i "s/your_uuid/${your_uuid}/" ${path}
    systemctl restart agent
    success "nezha-agent successfully installed"
}

touch_service() {
    cat >${NZ_AGENT_SERVICE} <<-EOF
[Unit]
Description=Nezha Agent
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/var/nezha/agent/agent -c /var/nezha/agent/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now agent
}

uninstall() {
    echo "Uninstalling Nezha Agent..."
    sudo systemctl stop agent
    sudo systemctl disable agent
    sudo rm -rf "$NZ_BASE_PATH" "$NZ_AGENT_SERVICE"
    sudo systemctl daemon-reload
    success "Nezha Agent uninstalled successfully."
}

if [ "$1" = "uninstall" ]; then
    uninstall
    exit
fi

init
install "$@"
