#! /bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 系统检测
OS=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|CentOS" | head -n 1)

if [[ $OS == "Debian" || $OS == "Ubuntu" ]]; then
    echo -e "检测到你的系统是 ${YELLOW}${OS}${NC}"
else
    echo -e "${RED}很抱歉，你的系统不受支持！${NC}"
    exit 1
fi

# 检测安装Python3的版本
VERSION=$(python3 -V 2>&1 | awk '{print $2}')

# 获取最新Python3版本
PY_VERSION=$(curl -s https://www.python.org/ | grep "downloads/release" | grep -o 'Python [0-9.]*' | grep -o '[0-9.]*')

# 卸载Python3旧版本
if [[ $VERSION == "3"* ]]; then
    echo -e "${YELLOW}你的Python3版本是${NC}${RED}${VERSION}${NC}，${YELLOW}最新版本是${NC}${RED}${PY_VERSION}${NC}"
    read -p "是否确认升级最新版Python3？默认不升级 [y/N]: " CONFIRM
    if [[ $CONFIRM == "y" ]]; then
        if [[ $OS == "CentOS" ]]; then
            echo ""
            rm-rf /usr/local/python3* >/dev/null 2>&1
        else
            apt --purge remove python3 python3-pip -y
            rm-rf /usr/local/python3* >/dev/null 2>&1
        fi
    else
        echo -e "${YELLOW}已取消升级Python3${NC}"
        exit 1
    fi
else
    echo -e "${RED}检测到没有安装Python3。${NC}"
    read -p "是否确认安装最新版Python3？默认安装 [Y/n]: " CONFIRM
    if [[ $CONFIRM != "n" ]]; then
        echo -e "${GREEN}开始安装最新版Python3...${NC}"
    else
        echo -e "${YELLOW}已取消安装Python3${NC}"
        exit 1
    fi
fi

# 安装相关依赖
if [[ $OS == "CentOS" ]]; then
    yum update
    yum groupinstall -y "development tools"
    yum install wget openssl-devel bzip2-devel libffi-devel zlib-devel -y
else
    apt update
    apt install wget build-essential libreadline-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev -y
fi

# 安装python3
cd /root/
wget https://www.python.org/ftp/python/${PY_VERSION}/Python-"$PY_VERSION".tgz
tar -zxf Python-${PY_VERSION}.tgz
cd Python-${PY_VERSION}
./configure --prefix=/usr/local/python3
make -j $(nproc)
make install
if [ $? -eq 0 ]; then
    rm -rf /usr/local/bin/python3* >/dev/null 2>&1
    rm -rf /usr/local/bin/pip3* >/dev/null 2>&1
    ln -sf /usr/local/python3/bin/python3 /usr/bin/python3
    ln -sf /usr/local/python3/bin/pip3 /usr/bin/pip3
    clear
    echo -e "${YELLOW}Python3安装${GREEN}成功，${NC}版本为：${NC}${GREEN}${PY_VERSION}${NC}"
else
    clear
    echo -e "${RED}Python3安装失败！${NC}"
    exit 1
fi
cd /root/ && rm -rf Python-${PY_VERSION}.tgz && rm -rf Python-${PY_VERSION}
