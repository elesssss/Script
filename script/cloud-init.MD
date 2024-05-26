使用 rc.local 文件
编辑 /etc/rc.local 文件:
如果该文件不存在，创建它，并确保它是可执行的：

```
vim /etc/rc.local
```
在文件中添加命令:
```
#!/bin/bash
cp -f /etc/network/interfaces.bak /etc/network/interfaces
systemctl restart networking
exit 0
```
```
chmod +x /etc/rc.local
```
启用 rc-local 服务:
如果 rc-local 服务未启用，创建一个服务文件 /etc/systemd/system/rc-local.service：
```
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
```
启用并启动 rc-local 服务：
```
systemctl enable --now rc-local
```
最后执行
```
systemctl restart networking && reboot
```
