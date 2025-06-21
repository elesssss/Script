# 首次运行脚本前请执行 [pip3 install sqlalchemy requests pymysql] 或者 [apt install -y python3-sqlalchemy python3-requests python3-pymysql]
# 需要 sqlalchemy >= 2.0.38  pip3 install sqlalchemy==2.0.38

import requests
from sqlalchemy import create_engine, MetaData, Table, select
from sqlalchemy.sql import desc
from time import sleep
import logging

# 配置 Telegram 机器人
TG_BOT_TOKEN = '<替换为你的机器人token>'
TG_CHAT_ID = '<替换为你的TG ID>'

# 数据库配置
DB_HOST = '<替换为你的数据库地址>'
DB_PORT = '<替换为你的数据库端口>'
DB_NAME = '<替换为你的数据库名>'
DB_USER = '<替换为你的数据库用户名>'
DB_PASSWORD = '<替换为你的数据库密码>'

# 数据库配置
DB_HOST = '168.138.199.140'
DB_PORT = '3305'
DB_NAME = 'epay'
DB_USER = 'root'
DB_PASSWORD = 'ryan1995'

# 配置日志 
logging.basicConfig(
    filename='log_epaybot',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    filemode='w'
)

# 设置数据库连接
engine = create_engine(f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
metadata = MetaData()

# 读取表结构
pay_order = Table('pay_order', metadata, autoload_with=engine)
pay_type_table = Table('pay_type', metadata, autoload_with=engine)

# 获取支付方式映射
def get_pay_type_map():
    with engine.connect() as conn:
        result = conn.execute(select(pay_type_table.c.id, pay_type_table.c.showname)).fetchall()
        return {row.id: row.showname for row in result}

# 获取最新订单（状态为0或1）
def get_latest_order():
    with engine.connect() as connection:
        s = select(*pay_order.c).where(pay_order.c.status.in_([0, 1])).order_by(desc(pay_order.c.trade_no))
        result = connection.execute(s).fetchone()
        return dict(result._mapping) if result else None

# 初始化
last_order = get_latest_order()
pay_method = get_pay_type_map()
order_status_cache = {}

try:
    while True:
        new_order = get_latest_order()

        if new_order and (not last_order or last_order.get('trade_no') != new_order.get('trade_no')):
            trade_no = new_order['trade_no']
            status = new_order['status']
            pay_type_id = new_order['type']
            pay_name = pay_method.get(pay_type_id)

            cached_status = order_status_cache.get(trade_no)

            # 若为新订单或状态发生变化
            if cached_status != status:
                order_status_cache[trade_no] = status  # 更新缓存

                if status == 0:
                    title = "🕒 新订单待支付"
                elif status == 1:
                    title = "✅ 新订单已支付"

                text = (
                    f"{title}\n"
                    f"———————————————\n"
                    f"🔗 订单号：{trade_no}\n"
                    f"💴 金额：{new_order['money']}\n"
                    f"📦 商品名称：{new_order['name']}\n"
                    f"💰 支付方式：{pay_name}"
                )

                # **终端输出通知**
                print(text)
                logging.info(text)

                # **发送到 Telegram机器人**
                url = f"https://api.telegram.org/bot{TG_BOT_TOKEN}/sendMessage?chat_id={TG_CHAT_ID}&text={text}"
                try:
                    response = requests.get(url, timeout=5)  # 设置超时时间 5 秒

                    # 根据响应状态判断通知是否成功
                    if response.status_code == 200:
                        status = "成功"
                        logging.info(f"Telegram 通知: {status}")
                    else:
                        status = "失败"
                        logging.error(f"Telegram 通知: {status}")

                    print(f"Telegram 通知: {status}")
                except requests.exceptions.Timeout:
                    print("⚠️ 发送 Telegram 消息超时，请检查网络连接！")

        sleep(30)  # 每 30 秒检查一次

except KeyboardInterrupt:
    print("\n程序已安全退出")
    logging.info("程序已安全退出")
