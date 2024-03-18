cat <<'EOF' > /root/db_backup.sh
#!/bin/bash
#删除2天以前备份

source /etc/profile #加载系统环境变量
set -o nounset      #引用未初始化变量时退出
#set -o errexit             #执行shell命令遇到错误时退出

user="root"
password="ryan1995"
host="localhost"
port="3306"
#需备份的数据库，用空格分开
db=("v2board" "acgfk" "epay")
#备份时加锁方式，
#MyISAM为锁表--lock-all-tables，
#InnoDB为锁行--single-transaction
lock="--skip-lock-tables"
mysql_path="/usr/bin"
backup_path="/var/lib/mysql/db_backup"
date=$(date +%Y%m%d_%H%M%S)
min=2880
backup_log="/root/backup.log"

#建立备份目录
if [ ! -e $backup_path ]; then
    mkdir -p $backup_path
fi

#删除以前备份
find $backup_path -type f -mmin +$min -exec rm -rf {} \; >/dev/null 2>&1

echo "开始备份数据库：${db[*]}"

#备份并压缩
backup_sql() {
    dbname=$1
    backup_name="${dbname}_${date}.sql"
    #-R备份存储过程，函数，触发器
    mysqldump -h $host -P $port -u $user -p$password $lock --default-character-set=utf8 --flush-logs -R $dbname >$backup_path/$backup_name
    if [[ $? == 0 ]]; then
        cd $backup_path
        tar zcpvf $backup_name.tar.gz $backup_name
        size=$(du $backup_name.tar.gz -sh | awk '{print $1}')
        rm -rf $backup_name
        echo "$date 备份 $dbname($size) 成功 "
    else
        cd $backup_path
        rm -rf $backup_name
        echo "$date 备份 $dbname 失败 "
    fi
}

#循环备份
length=${#db[@]}
for ((i = 0; i < $length; i++)); do
    backup_sql ${db[$i]} >>$backup_log 2>&1
done

echo "备份结束,结果查看 $backup_log"
du $backup_path/*$date* -sh | awk '{print "文件:" $2 ",大小:" $1}'

EOF
