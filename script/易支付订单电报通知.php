// 首先去易支付数据库新增 tg_chat_id 条目，mysql语句 ALTER TABLE pay_user ADD COLUMN tg_chat_id varchar(255) DEFAULT NULL;

// ./user/userinfo.php 大约80行下面添加以下代码，
				<div class="form-group">
					<label class="col-sm-2 control-label">电报ID</label>
					<div class="col-sm-9">
						<div class="input-group">
						<input class="form-control" type="text" name="tg_chat_id" value="<?php echo $userrow['tg_chat_id']?>" placeholder="请输入你的Telegram Chat ID">
						<a href="javascript:setTGid()" class="input-group-addon" id="checkbind">修改绑定</a>
						</div>
					</div>
				</div>

// ./user/userinfo.php 大约255行下面添加以下代码，
function setTGid(){
	var tg_chat_id = $('input[name="tg_chat_id"]').val().trim();
	if (tg_chat_id !== '' && !/^-?\d+$/.test(tg_chat_id)) {
		layer.alert('Telegram Chat ID 必须是纯数字，可为负数（群组或频道）！', {icon: 2});
		return false;
	}

	// 空输入提示解绑
	var tipMsg = tg_chat_id === ''
		? '是否确认解绑电报ID？解绑后订单通知不可用！'
		: '是否确认绑定电报ID？绑定后可以通知到机器人';

	// 成功提示也根据操作变化
	var successMsg = tg_chat_id === ''
		? '解绑电报ID成功！'
		: '绑定电报ID成功！';

	var confirmobj = layer.confirm(tipMsg, {
	  btn: ['确定','取消']
	}, function(){
		$.ajax({
			type : 'POST',
			url : 'ajax2.php?act=setTGid',
			data : {
				submit: 'do',
				tg_chat_id: tg_chat_id
			},
			dataType : 'json',
			success : function(data) {
				if(data.code == 0){
					layer.alert(successMsg, {icon:1});
				}else{
					layer.alert(data.msg, {icon:2});
				}
			},
			error:function(data){
				layer.msg('服务器错误');
				return false;
			}
		});
		layer.close(confirmobj);
	}, function(){
		layer.close(confirmobj);
	});
}

// ./user/ajax2.php 大约320行下面添加以下代码，
case 'setTGid':
	$uid = $userrow['uid']; 
	$tg_chat_id = isset($_POST['tg_chat_id']) ? trim($_POST['tg_chat_id']) : '';
	if($tg_chat_id !== '' && !preg_match('/^-?\d+$/', $tg_chat_id)){
		exit(json_encode(['code'=>-1,'msg'=>'Telegram Chat ID 格式不正确，可为负数（群组/频道）']));
	}
	if(isset($_POST['submit'])){
		$sql = "UPDATE pre_user SET `tg_chat_id` = :tg_chat_id WHERE uid = :uid";
		$params = [ ':tg_chat_id' => $tg_chat_id, ':uid' => $uid ];
		if($DB->exec($sql, $params) !== false){
			exit(json_encode(['code'=>0,'msg'=>'绑定电报ID成功']));
		}else{
			exit(json_encode(['code'=>-1,'msg'=>'绑定电报ID失败 ['.$DB->error().']']));
		}
	}
break;

// ./admin/set.php 大约30行下面添加以下代码，
	<div class="form-group">
	  <label class="col-sm-2 control-label">电报机器人token</label>
	  <div class="col-sm-10"><input type="text" name="tg_bot_token" value="<?php echo $conf['tg_bot_token']; ?>" class="form-control" required/></div>
	</div><br/>

// api创建新订单通知
// ./includes/lib/api/Pay.php 大约180行下面添加以下代码，
            // 通知电报机器人
            $tg_chat_id_row = $DB->getRow("SELECT tg_chat_id FROM pay_user WHERE uid='{$pid}' LIMIT 1");
            $tg_chat_id = $tg_chat_id_row && !empty($tg_chat_id_row['tg_chat_id']) ? $tg_chat_id_row['tg_chat_id'] : '';
            if (!empty($tg_chat_id)){
            	$tg_bot_token_row = $DB->getRow("SELECT v FROM pay_config WHERE k='tg_bot_token' LIMIT 1");
            	$tg_bot_token = $tg_bot_token_row && !empty($tg_bot_token_row['v']) ? $tg_bot_token_row['v'] : '';
            	$text = "🕒 新订单待支付\n"
            		. "———————————————\n"
            		. "🔗 订单号：{$trade_no}\n"
            		. "💴 金额：{$money} 元\n"
            		. "📦 商品名称：{$name}\n"
            		. "💰 支付方式：{$submitData['typename']}";
            	$url = "https://api.telegram.org/bot{$tg_bot_token}/sendMessage?chat_id={$tg_chat_id}&text=" . urlencode($text);
            	@file_get_contents($url);
            }

// 订单支付完成通知
// ./includes/lib/Payment.php 大约200行下面添加以下代码，
                // === Telegram 通知 ===
                $tg_chat_id_row = $DB->getRow("SELECT tg_chat_id FROM pay_user WHERE uid='{$order['uid']}' LIMIT 1");
                $tg_chat_id = $tg_chat_id_row && !empty($tg_chat_id_row['tg_chat_id']) ? $tg_chat_id_row['tg_chat_id'] : '';
                if (!empty($tg_chat_id)){
                	$pay_type_row = $DB->getRow("SELECT showname FROM pay_type WHERE id='{$order['type']}' LIMIT 1");
                	$pay_type_name = $pay_type_row && !empty($pay_type_row['showname']) ? $pay_type_row['showname'] : '';
                	$tg_bot_token_row = $DB->getRow("SELECT v FROM pay_config WHERE k='tg_bot_token' LIMIT 1");
                	$tg_bot_token = $tg_bot_token_row && !empty($tg_bot_token_row['v']) ? $tg_bot_token_row['v'] : '';
                	$text = "✅ 新订单已支付\n"
                    	. "———————————————\n"
                    	. "🔗 订单号：{$order['trade_no']}\n"
                    	. "💴 金额：{$order['money']}\n"
                    	. "📦 商品名称：{$order['name']}\n"
                    	. "💰 支付方式：{$pay_type_name}";
                	$url = "https://api.telegram.org/bot{$tg_bot_token}/sendMessage?chat_id={$tg_chat_id}&text=" . urlencode($text);
                	@file_get_contents($url);
                }

// 完事儿了就可以去管理员后台 -系统设置- 页面添加电报机器人token，商户则在 -个人资料- 页面绑定电报id，可以是群组or频道id，也可以是电报账号的id。
