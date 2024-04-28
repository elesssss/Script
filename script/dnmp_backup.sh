#!/bin/bash
# 删除2天以前备份

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

# 设置备份参数
run_backup_dir="/var/dnmp"  # 备份目标文件夹的路径
back_name1="nginx"  # 要备份的文件夹1
back_name2="service"  # 要备份的文件夹2
back_name3="www"  # 要备份的文件夹3
backup_dir="/opt/dnmp_backup" # 存放备份文件的路径
date=$(date +%Y%m%d_%H%M%S)  # 执行备份的时间
backup_file="dnmp_${date}.tar.gz"  # 备份文件名
min="2880" # 保留备份的时间
backup_log="/root/log_backup.log" # 备份日志

# 创建备份目录（如果不存在）
if [ ! -e "$backup_dir" ]; then
	mkdir -p "$backup_dir"
fi

# 删除2天以前的备份
find "$backup_dir" -type f -mmin +$min -exec rm -rf {} \; > /dev/null 2>&1

# 执行备份
dnmp_backup() {
	tar -zcvf "$backup_dir/$backup_file" -C "$run_backup_dir" "$back_name1" "$back_name2" "$back_name3" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "${Info} $(date) 备份 $Green成功$Nc"
		du "$backup_dir"/*"$date"* -sh | awk '{print "文件:" $2 ",大小:" $1}'
	else
		echo -e "${Error} $(date) 备份 $Red失败$Nc"
	fi
}

# 写入日志
dnmp_backup >> "$backup_log" 2>&1

echo -e "${Tip} 备份结束,结果查看 ${Green}tail -f $backup_log ${Nc}"

gdrive sync upload  --keep-local --delete-extraneous ${backup_dir} 1sAX8TKJRjRXvJraSSTSsi_15ocOjlNXf
