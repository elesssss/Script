#!/bin/bash
# 删除2天以前备份

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

# 设置备份参数
backup_times=1
run_backup_dir="/var/dnmp"  # 备份目标文件夹的路径
back_name1="nginx"  # 要备份的文件夹1
back_name2="service"  # 要备份的文件夹2
back_name3="www"  # 要备份的文件夹3
backup_dir="/opt/dnmp_backup" # 存放备份文件的路径
date=$(date +%Y%m%d_%H%M%S)  # 执行备份的时间
backup_file="dnmp_${date}.tar.gz"  # 备份文件名
min="2880" # 保留备份的时间
backup_log="/root/backup.log" # 备份日志

# 创建备份目录（如果不存在）
if [ ! -e "$backup_dir" ]; then
	mkdir -p "$backup_dir"
fi

# 删除2天以前的备份
find "$backup_dir" -type f -mmin +$min -exec rm -rf {} \; > /dev/null 2>&1

# 执行备份
dnmp_backup() {
	if tar -zcvf "$backup_dir/$backup_file" -C "$run_backup_dir" "$back_name1" "$back_name2" "$back_name3" >/dev/null 2>&1; then
		size=$(du "$backup_dir/$backup_file" -sh | awk '{print $1}')
		echo -e "$(date) 备份 $back_name($size) $GREEN成功$NC"
	else
		echo -e "$(date) 备份 $back_name $RED失败$NC"
	fi
}

# 循环备份
for (( i = 0; i < $backup_times; i++ )); do
	dnmp_backup >> "$backup_log" 2>&1
done

echo "备份结束,结果查看 $backup_log"
du "$backup_dir"/*"$date"* -sh | awk '{print "文件:" $2 ",大小:" $1}'

gdrive sync upload  --keep-local --delete-extraneous ${backup_dir} 1sAX8TKJRjRXvJraSSTSsi_15ocOjlNXf
