# 首次运行脚本前请执行 [pip3 install sqlalchemy requests pymysql] 或者 [pip3 install --break-system-packages sqlalchemy requests pymysql]

import requests
from sqlalchemy import create_engine, MetaData, Table, select
from sqlalchemy.sql import desc
from time import sleep

TG_BOT_TOKEN = '<替换为你的机器人token>'
TG_CHAT_ID = '<替换为你的TG ID>'
DB_HOST = '<替换为你的数据库地址>'
DB_PORT = '<替换为你的数据库端口>'
DB_NAME = '<替换为你的数据库名>'
DB_USER = '<替换为你的数据库用户名>'
DB_PASSWORD = '<替换为你的数据库密码>'
payment_types = {1: '支付宝', 2: '微信', 7: 'TRX', 8: 'USDT'} # 支付方式

# 设置用于MySQL连接的引擎
engine = create_engine(f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

metadata = MetaData()

# 读取数据库表结构
TABLE_NAME = 'pay_order'
pay_order = Table(TABLE_NAME, metadata, autoload_with=engine)

# 初始化，获取最新一条支付成功的订单
with engine.connect() as connection:
    s = select(pay_order).where(pay_order.c.status == '1').order_by(desc(pay_order.c.trade_no))
    result = connection.execute(s)
    last_order = result.fetchone()._asdict()  # Convert to dictionary

# 循环检查新的支付成功的订单
try:
    while True:
        with engine.connect() as connection:
            s = select(pay_order).where(pay_order.c.status == '1').order_by(desc(pay_order.c.trade_no))
            result = connection.execute(s)
            new_order = result.fetchone()._asdict()  # Convert to dictionary

            # 检查新的订单是否是刚刚检查过的订单
            if last_order['trade_no'] != new_order['trade_no']:
                last_order = new_order

                # 当有新的成功支付的订单时，发送通知到Telegram
                text = f"🎉易支付新订单🎉\n———————————————\n🔗订单号：{last_order['trade_no']}\n💴订单金额：{last_order['money']}\n⚖️商品名称：{last_order['name']}\n💰支付方式：{payment_types[last_order['type']]}"
                url = f"https://api.telegram.org/bot{TG_BOT_TOKEN}/sendMessage?chat_id={TG_CHAT_ID}&text={text}"
                requests.get(url)

        # 每30秒检查一次
        sleep(30)
except KeyboardInterrupt:
    print("\n程序已经安全退出")
