# 首次运行脚本前请执行 [pip3 install sqlalchemy requests pymysql] 或者 [apt install -y python3-sqlalchemy python3-requests python3-pymysql]
# 需要 sqlalchemy >= 1.4.46  pip3 install sqlalchemy==1.4.46

import requests
from sqlalchemy import create_engine, MetaData, Table, select
from sqlalchemy.sql import desc
from time import sleep

# 配置 Telegram 机器人
TG_BOT_TOKEN = '<替换为你的机器人token>'
TG_CHAT_ID = '<替换为你的TG ID>'

# 数据库配置
DB_HOST = '<替换为你的数据库地址>'
DB_PORT = '<替换为你的数据库端口>'
DB_NAME = '<替换为你的数据库名>'
DB_USER = '<替换为你的数据库用户名>'
DB_PASSWORD = '<替换为你的数据库密码>'

# 支付方式映射
payment_types = {1: '支付宝', 2: '微信', 7: 'TRX', 8: 'USDT'}

# 设置数据库连接
engine = create_engine(f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")
metadata = MetaData()
TABLE_NAME = 'pay_order'
pay_order = Table(TABLE_NAME, metadata, autoload_with=engine)

# 获取最新的支付成功订单
def get_latest_order():
    with engine.connect() as connection:
        s = select(*pay_order.c).where(pay_order.c.status == '1').order_by(desc(pay_order.c.trade_no))
        result = connection.execute(s).fetchone()
        return dict(result._mapping) if result else None

# 初始化最新订单
last_order = get_latest_order()

try:
    while True:
        new_order = get_latest_order()
        
        if new_order and (not last_order or last_order.get('trade_no') != new_order.get('trade_no')):
            last_order = new_order  # 更新最新订单
            
            # 发送 Telegram 通知
            text = (
                f"🎉 易支付新订单 🎉\n"
                f"———————————————\n"
                f"🔗 订单号：{last_order['trade_no']}\n"
                f"💴 订单金额：{last_order['money']}\n"
                f"⚖️ 商品名称：{last_order['name']}\n"
                f"💰 支付方式：{payment_types.get(last_order['type'], '未知')}"
            )

            # **终端输出通知**
            print(text)

            # **发送到 Telegram**
            url = f"https://api.telegram.org/bot{TG_BOT_TOKEN}/sendMessage?chat_id={TG_CHAT_ID}&text={text}"
            try:
                response = requests.get(url, timeout=5)  # 设置超时时间 5 秒

                if response.status_code == 200:
                    status = "成功"
                else:
                    status = "失败"
                print(f"Telegram 通知: {status}")
            except requests.exceptions.Timeout:
                print("⚠️ 发送 Telegram 消息超时，请检查网络连接！")

        sleep(30)  # 每 30 秒检查一次
except KeyboardInterrupt:
    print("\n程序已安全退出")
