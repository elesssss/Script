#!/bin/bash
#
# 输出字体颜色
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[0;33m"
NC="\033[0m"
GREEN_ground="\033[42;37m" # 全局绿色
RED_ground="\033[41;37m"   # 全局红色
Info="${GREEN}[信息]${NC}"
Error="${RED}[错误]${NC}"
Tip="${YELLOW}[注意]${NC}"

clear
echo -e "${GREEN}#####################################${NC}"
echo -e "${GREEN}#           ${RED}OpenVPN 一键脚本        ${GREEN}#${NC}"
echo -e "${GREEN}#         作者: ${YELLOW}你挺能闹啊🍏        ${GREEN}#${NC}"
echo -e "${GREEN}#####################################${NC}"
echo ""

if [[ $(whoami) != "root" ]]; then
	echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法 继续操作，请更换ROOT账号或使用 ${GREEN_ground}sudo su${NC} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。"
	exit 1
fi

# Discard stdin. Needed when running from an one-liner which includes a newline
read -N 999999 -t 0.001

# Detect OpenVZ 6
if [[ $(uname -r | cut -d "." -f 1) -eq 2 ]]; then
	echo -e "${Error}系统运行的是旧内核，与此安装程序不兼容。"
	exit 1
fi


# 检查系统
os=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|centOS" | head -n 1)
if [[ "$os" == "Debian" || "$os" == "Ubuntu" ]]; then
	if ! command -v wget &>/dev/null; then
		echo -e "${Info}开始安装依赖！"
		apt update -y
		apt install -y wget openssl
	fi
	if ! command -v openssl &>/dev/null; then
		echo -e "${Info}开始安装依赖！"
		apt update -y
		apt install -y openssl
	fi
	group_name="nogroup"
elif [[ "$os" == "centOS" ]]; then
	if ! command -v wget &>/dev/null; then
		echo -e "${Info}开始安装依赖！"
		yum update -y
		yum install -y wget openssl
	fi
		if ! command -v openssl &>/dev/null; then
		echo -e "${Info}开始安装依赖！"
		yum update -y
		yum install -y openssl
	fi
	group_name="nobody"
else
	echo -e "${Error}很抱歉，你的系统不受支持！"
	exit 1
fi

# Detect environments where $PATH does not include the sbin directories
if ! grep -q sbin <<< "$PATH"; then
	echo '${Error}$PATH 不包括 sbin。尝试使用 "su - "代替 "su"。'
	exit 1
fi


if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
	echo -e "${Error}系统没有可用的 TUN 设备。
	运行此安装程序前需要启用 TUN。"
	exit 1
fi

new_client () {
	# Generates the custom client.ovpn
	{
	cat /etc/openvpn/server/client-common.txt
	echo "<ca>"
	cat /etc/openvpn/server/easy-rsa/pki/ca.crt
	echo "</ca>"
	echo "<cert>"
	sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt
	echo "</cert>"
	echo "<key>"
	cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key
	echo "</key>"
	echo "<tls-crypt>"
	sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
	echo "</tls-crypt>"
	} > ~/"$client".ovpn
}

getipv4(){
	ipv4=$(wget -qO- -4 -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ipv4}" ]]; then
		ipv4=$(wget -qO- -4 -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ipv4}" ]]; then
			ipv4=$(wget -qO- -4 -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ipv4}" ]]; then
				ipv4="IPv4_Error"
			fi
		fi
	fi
}

getipv6(){
	ipv6=$(wget -qO- -6 -t1 -T3 ifconfig.co)
	if [[ -z "${ipv6}" ]]; then
		ipv6="IPv6_Error"
	fi
}

if [[ ! -e /etc/openvpn/server/server.conf ]]; then
	# If system has a single IPv4, it is selected automatically. Else, ask the user
	echo -e "${Tip}如果本机是NAT服务器（谷歌云、微软云、阿里云等，网卡绑定的IP为 10.xx.xx.xx 开头的），则需要指定公网 IPv4。"
	read -e -p "(默认：自动检测 IPv4 地址):" ip
	if [[ -z "${ip}" ]]; then
		getipv4
		if [[ "${ipv4}" == "IPv4_Error" ]]; then
			echo -e "	IPv4 : ${Error} 没有公网 IPv4。"
		else
			ip="${ipv4}"
			echo -e "	IPv4 : ${RED_ground} ${ip} ${NC}"
		fi
	fi
	echo -e "${Tip}如果本机是NAT服务器（谷歌云、微软云、阿里云等），则需要指定公网 IPv6。"
	read -e -p "(默认：自动检测 IPv6 地址):" ip6
	if [[ -z "${ip6}" ]]; then
		getipv6
		if [[ "${ipv6}" == "IPv6_Error" ]]; then
			echo -e "	IPv6 : ${Error} 没有公网 IPv6。"
		else
			ip6="${ipv6}"
			echo -e "	IPv6 : ${RED_ground} ${ip6} ${NC}"
		fi
	fi
	echo
	echo "OpenVPN 应使用哪种协议？"
	echo "   1) TCP (推荐)"
	echo "   2) UDP"
	read -p "协议 [默认：1]: " protocol
	until [[ -z "$protocol" || "$protocol" =~ ^[12]$ ]]; do
		echo -e "${Error}$protocol: 请输入正确的数字。"
		read -p "协议 [1]: " protocol
	done
	case "$protocol" in
		1|"") 
			protocol=tcp
			;;
		2) 
			protocol=udp
			;;
	esac
	echo
	echo -e "	协议 : ${RED_ground} $protocol ${NC}"
	echo
	while true; do
		echo "OpenVPN 应监听哪个端口？"
		read -e -p "(默认：随机生成): " port
		[[ -z "${port}" ]] && port=$(shuf -i 40000-60000 -n 1)
		echo $((port + 0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${port} -ge 40000 && ${port} -le 60000 ]]; then
				echo
				echo -e "	端口 : ${RED_ground} ${port} ${NC}"
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
		echo "输入错误, 请输入正确的端口。"
		fi
	done
	echo
	echo "为用户选择 DNS 服务器："
	echo "   1) 跟随系统"
	echo "   2) Google"
	echo "   3) 1.1.1.1"
	echo "   4) OpenDNS"
	echo "   5) Quad9"
	echo "   6) AdGuard"
	read -p "DNS 服务器 [默认：1]: " dns
	until [[ -z "$dns" || "$dns" =~ ^[1-6]$ ]]; do
		echo -e "${Error}$dns: 请输入正确的数字。"
		read -p "DNS 服务器 [默认：1]: " dns
	done
	echo
	echo "请输入第一个用户的名称："
	read -e -p "默认随机生成：" client
     if [ -z "$client" ]; then
     	client=$(openssl rand -base64 6)
     fi
     echo -e "	用户名 : ${RED_ground} $client ${NC}"
	echo
	echo -e "${Info}OpenVPN 安装已准备就绪。"
	# Install a firewall if firewalld or iptables are not already available
	read -n1 -r -p "按任意键继续..."
	# If running inside a container, disable LimitNPROC to prevent conflicts
	if systemd-detect-virt -cq; then
		mkdir /etc/systemd/system/openvpn-server@server.service.d/ 2>/dev/null
		echo "[Service]
		LimitNPROC=infinity" > /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
	fi
	if [[ "$os" == "Debian" || "$os" == "Ubuntu" ]]; then
		apt update -y
		apt install -y --no-install-recommends openvpn ca-certificates
	elif [[ "$os" == "centOS" ]]; then
		yum update -y
		yum install -y epel-release
		yum install -y openvpn ca-certificates tar
	fi

	# Get easy-rsa
	easy_rsa_url='https://ghproxy.com/https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.7/EasyRSA-3.1.7.tgz'
	mkdir -p /etc/openvpn/server/easy-rsa/
	{ wget -qO- "$easy_rsa_url" 2>/dev/null || curl -sL "$easy_rsa_url" ; } | tar xz -C /etc/openvpn/server/easy-rsa/ --strip-components 1
		chown -R root:root /etc/openvpn/server/easy-rsa/
		cd /etc/openvpn/server/easy-rsa/
		# Create the PKI, set up the CA and the server and client certificates
		./easyrsa --batch init-pki
		./easyrsa --batch build-ca nopass
		./easyrsa --batch --days=3650 build-server-full server nopass
		./easyrsa --batch --days=3650 build-client-full "$client" nopass
		./easyrsa --batch --days=3650 gen-crl
		# Move the stuff we need
		cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server
		# CRL is read with each client connection, while OpenVPN is dropped to nobody
		chown nobody:"$group_name" /etc/openvpn/server/crl.pem
		# Without +x in the directory, OpenVPN can't run a stat() on the CRL file
		chmod o+x /etc/openvpn/server/
		# Generate key for tls-crypt
		openvpn --genkey --secret /etc/openvpn/server/tc.key
		# Create the DH parameters file using the predefined ffdhe2048 group
		echo '-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----' > /etc/openvpn/server/dh.pem
		# Generate server.conf
		echo "local $ip
port $port
proto $protocol
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-crypt tc.key
topology subnet
server 10.8.0.0 255.255.255.0" > /etc/openvpn/server/server.conf
		# IPv6
		if [[ -z "$ip6" ]]; then
			echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server/server.conf
		else
			echo 'server-ipv6 fddd:1194:1194:1194::/64' >> /etc/openvpn/server/server.conf
			echo 'push "redirect-gateway def1 ipv6 bypass-dhcp"' >> /etc/openvpn/server/server.conf
		fi
		echo 'ifconfig-pool-persist ipp.txt' >> /etc/openvpn/server/server.conf
		# DNS
		case "$dns" in
			1|"")
				# Locate the proper resolv.conf
				# Needed for systems running systemd-resolved
				if grep '^nameserver' "/etc/resolv.conf" | grep -qv '127.0.0.53' ; then
					resolv_conf="/etc/resolv.conf"
				else
					resolv_conf="/run/systemd/resolve/resolv.conf"
				fi
				# Obtain the resolvers from resolv.conf and use them for OpenVPN
				grep -v '^#\|^;' "$resolv_conf" | grep '^nameserver' | grep -v '127.0.0.53' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | while read line; do
				echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server/server.conf
			done
			;;
		2)
			echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server/server.conf
			;;
		3)
			echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 1.0.0.1"' >> /etc/openvpn/server/server.conf
			;;
		4)
			echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server/server.conf
			;;
		5)
			echo 'push "dhcp-option DNS 9.9.9.9"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 149.112.112.112"' >> /etc/openvpn/server/server.conf
			;;
		6)
			echo 'push "dhcp-option DNS 94.140.14.14"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 94.140.15.15"' >> /etc/openvpn/server/server.conf
			;;
	esac
	echo 'push "block-outside-dns"' >> /etc/openvpn/server/server.conf
	echo "keepalive 10 120
cipher AES-256-CBC
user nobody
group $group_name
persist-key
persist-tun
verb 3
crl-verify crl.pem" >> /etc/openvpn/server/server.conf
	if [[ "$protocol" = "udp" ]]; then
		echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf
	fi
	# Enable net.ipv4.ip_forward for the system
	echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn-forward.conf
	# Enable without waiting for a reboot or service restart
	echo 1 > /proc/sys/net/ipv4/ip_forward
	if [[ -n "$ip6" ]]; then
		# Enable net.ipv6.conf.all.forwarding for the system
		echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-openvpn-forward.conf
		# Enable without waiting for a reboot or service restart
		echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
	fi
	# If the server is behind NAT, use the correct IP address
	[[ -n "$public_ip" ]] && ip="$public_ip"
	# client-common.txt is created so we have a template to add further users later
	echo "client
dev tun
proto $protocol
remote $ip $port
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
ignore-unknown-option block-outside-dns
verb 3" > /etc/openvpn/server/client-common.txt
	# Enable and start the OpenVPN service
	systemctl enable --now openvpn-server@server.service
	# Generates the custom client.ovpn
	new_client
	clear
	echo -e "${GREEN}#####################################${NC}"
	echo -e "${GREEN}#           ${RED}OpenVPN 一键脚本        ${GREEN}#${NC}"
	echo -e "${GREEN}#         作者: ${YELLOW}你挺能闹啊🍏        ${GREEN}#${NC}"
	echo -e "${GREEN}#####################################${NC}"
	echo ""
	echo -e "${Info}OpenVPN 安装完成！"
	OpenVPNport=$(lsof -i | grep openvpn | awk '{print $9}' | cut -d: -f2)
	echo -e "${Info}OpenVPN 端口 ${GREEN}$OpenVPNport${NC}"
	echo -e "${Info}用户配置在" ~/"$client.ovpn"
	echo -e "${Info}再次运行此脚本即可添加新用户。"
else
	clear
	echo -e "${GREEN}#####################################${NC}"
	echo -e "${GREEN}#           ${RED}OpenVPN 一键脚本        ${GREEN}#${NC}"
	echo -e "${GREEN}#         作者: ${YELLOW}你挺能闹啊🍏        ${GREEN}#${NC}"
	echo -e "${GREEN}#####################################${NC}"
	echo ""
	echo -e "${Info}OpenVPN 已经安装。"
	OpenVPNport=$(lsof -i | grep openvpn | awk '{print $9}' | cut -d: -f2)
	echo -e "${Info}OpenVPN 端口 ${GREEN}$OpenVPNport${NC}"
	echo
	echo "选择一个选项:"
	echo "   1) 添加新用户"
	echo "   2) 删除现有客户"
	echo "   3) 卸载 OpenVPN"
	echo "   0) 退出"
	read -p "选项: " option
	until [[ "$option" =~ ^[0-3]$ ]]; do
		echo -e "${Error}请输入正确的数字 [0-3]"
		exit 1
	done
	case "$option" in
		1)
			echo
			echo "输入用户名："
			read -p "用户名: " unsanitized_client
			client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
			while [[ -z "$client" || -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt ]]; do
				echo -e "${Error}$client: 无效用户名。"
				read -p "用户名: " unsanitized_client
				client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
			done
			cd /etc/openvpn/server/easy-rsa/
			./easyrsa --batch --days=3650 build-client-full "$client" nopass
			# Generates the custom client.ovpn
			new_client
			echo
			echo -e "${Info}$client 已添加。配置在:" ~/"$client.ovpn"
			exit
			;;
		2)
			# This option could be documented a bit better and maybe even be simplified
			# ...but what can I say, I want some sleep too
			number_of_clients=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
			if [[ "$number_of_clients" = 0 ]]; then
				echo
				echo -e "${Error}没有现有用户！"
				exit
			fi
			echo
			echo "选择要删除的用户："
			tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
			read -p "用户: " client_number
			until [[ "$client_number" =~ ^[0-9]+$ && "$client_number" -le "$number_of_clients" ]]; do
				echo -e "${Error}请输入正确的数字。"
				read -p "用户: " client_number
			done
			client=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)
			echo
			read -p "确认 $client 删除？ [y/N]: " revoke
			until [[ "$revoke" =~ ^[yYnN]*$ ]]; do
				echo -e "${Error}$revoke: 选择无效。"
				read -p "确认 $client 删除？ [y/N]: " revoke
			done
			if [[ "$revoke" =~ ^[yY]$ ]]; then
				cd /etc/openvpn/server/easy-rsa/
				./easyrsa --batch revoke "$client"
				./easyrsa --batch --days=3650 gen-crl
				rm -f /etc/openvpn/server/crl.pem
				cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
				rm -f ~/$client.ovpn
				# CRL is read with each client connection, when OpenVPN is dropped to nobody
				chown nobody:"$group_name" /etc/openvpn/server/crl.pem
				echo
				echo -e "${Info}$client 已删除！"
			else
				echo
				echo -e "${Error}$client 删除被中止！"
			fi
			exit
			;;
		3)
			echo
			read -p "确认卸载 OpenVPN？ [y/N]: " remove
			until [[ "$remove" =~ ^[yYnN]*$ ]]; do
				echo -e "${Error}$remove: 选择无效。"
				read -p "确认卸载 OpenVPN？ [y/N]: " remove
			done
			if [[ "$remove" =~ ^[yY]$ ]]; then
				port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
				protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
				systemctl disable --now openvpn-server@server.service
				rm -f /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
				rm -f /etc/sysctl.d/99-openvpn-forward.conf
				if [[ "$os" == "Debian" || "$os" == "Ubuntu" ]]; then
					rm -rf /etc/openvpn ~/*.ovpn
					apt remove --purge -y openvpn
					apt autoremove -y
				else
					# Else, OS must be centOS or Fedora
					rm -rf /etc/openvpn ~/*.ovpn
					yum remove -y openvpn
					yum autoremove -y
				fi
				echo
				echo -e "${Info}已卸载 OpenVPN ！"
			else
				echo
				echo -e "${Error}OpenVPN 卸载中止！"
			fi
			exit
			;;
		0)
			exit
			;;
	esac
fi
