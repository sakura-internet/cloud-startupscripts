#!/bin/bash

# @sacloud-name "RabbitMQ"
# @sacloud-once
# @sacloud-desc-begin
# RabbitMQ 3.6.1をインストールします。
# このスクリプトは、CentOS6.Xでのみ動作します。
# サーバ作成後 http://サーバのIPアドレス:マネジメントポート番号/ に接続してください。
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-text required shellarg maxlen=16 default=admin username '初期ユーザ名'
# @sacloud-password required shellarg maxlen=16 password 'パスワード'
# @sacloud-text required shellarg integer min=1 max=65534 maxlen=5 default=5672 amqpport 'AMQPポート番号'
# @sacloud-text required shellarg integer min=1 max=65534 maxlen=5 default=15672 mgmtport 'マネジメントポート番号'
# @sacloud-text required shellarg maxlen=20 default=0.0.0.0/0 allowed_src_amqp 'AMQP接続元許可IPアドレス'
# @sacloud-text required shellarg maxlen=20 default=0.0.0.0/0 allowed_src_mgmt 'マネジメント接続元許可IPアドレス'


set -e
set -x

USERNAME=@@@username@@@
PASSWORD=@@@password@@@
AMQPPORT=@@@amqpport@@@
MGMTPORT=@@@mgmtport@@@
ALLOWED_SRC_AMQP=@@@allowed_src_amqp@@@
ALLOWED_SRC_MGMT=@@@allowed_src_mgmt@@@


yum localinstall -y https://www.rabbitmq.com/releases/erlang/erlang-18.2-1.el6.x86_64.rpm
yum localinstall -y https://www.rabbitmq.com/releases/rabbitmq-server/v3.6.1/rabbitmq-server-3.6.1-1.noarch.rpm

cat > /etc/rabbitmq/rabbitmq.config <<_EOF_
[
 {rabbit, [{tcp_listeners, [$AMQPPORT]}]},
 {rabbitmq_management, [{listener, [{port, $MGMTPORT}]}]}
].
_EOF_

iptables -A INPUT -i eth0 -p tcp -s "$ALLOWED_SRC_AMQP" --dport "$AMQPPORT" -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport "$AMQPPORT" -j DROP

iptables -A INPUT -i eth0 -p tcp -s "$ALLOWED_SRC_MGMT" --dport "$MGMTPORT" -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport "$MGMTPORT" -j DROP

/etc/init.d/iptables save
chkconfig iptables on

service rabbitmq-server start
chkconfig rabbitmq-server on
rabbitmq-plugins enable rabbitmq_management

rabbitmqctl delete_user guest || true

rabbitmqctl add_user "$USERNAME" "$PASSWORD"
rabbitmqctl set_user_tags "$USERNAME" administrator
rabbitmqctl set_permissions "$USERNAME" '.*' '.*' '.*'

exit 0