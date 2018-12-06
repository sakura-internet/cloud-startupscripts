#!/bin/bash

# @sacloud-name "Jupyter Notebook"
# @sacloud-once
#
# @sacloud-require-archive distro-centos distro-ver-7.*
#
# @sacloud-desc-begin
# pyenv, Anaconda,Jupyterをインストールするスクリプトです。
# このスクリプトは、CentOS7.Xでのみ動作します。
# サーバ作成後、Webブラウザで以下のURL（サーバのIPアドレスと設定したポート）にアクセスしてください。
#   http://サーバのIPアドレス:設定したポート/
# アクセスした後、設定したJupyterのパスワードでログインしてください。
# このスクリプトは完了までに20分程度時間がかかります
# @sacloud-desc-end
# @sacloud-password required JP "Jupyterのログインパスワード設定"
# @sacloud-text required default=49152 integer min=49152 max=65534 JPORT "port番号変更(49152以上、65534以下を指定してください)"

# コントロールパネルの入力値を変数へ代入
password=@@@JP@@@
port=@@@JPORT@@@
user="jupyter"
home="/home/$user"

# ユーザーの作成
if ! cat /etc/passwd | awk -F : '{ print $1 }' | egrep ^$user$; then
    adduser $user
fi

echo "[1/5] Pythonのインストールに必要なライブラリをインストール中"
yum update -y
yum -y install git readline-devel zlib-devel bzip2-devel sqlite-devel openssl-devel
echo "[1/5] Pythonのインストールに必要なライブラリをインストールしました"

echo "[2/5] pyenvをインストール中..."
git clone https://github.com/yyuu/pyenv $home/.pyenv
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> $home/.bash_profile
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> $home/.bash_profile
echo 'eval "$(pyenv init -)"' >> $home/.bash_profile
chown -R $user:$user $home/.pyenv
echo "[2/5] pyenvをインストールしました"

echo "[3/5] Anaconda,chainer,tensorflowのインストール中..."
#Anaconda3系
su -l $user -c "yes | pyenv install anaconda3-4.3.1"
su -l $user -c "pyenv global anaconda3-4.3.1"
su -l $user -c "pyenv rehash"
su -l $user -c "yes | conda create --name py3.5 python=3.5 anaconda"
cat << EOF > /tmp/ana3.sh
source /home/$user/.pyenv/versions/anaconda3-4.3.1/bin/activate py3.5
conda install jupyter ipykernel
jupyter kernelspec install-self --user
pip install chainer
pip install https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.12.0-cp35-cp35m-linux_x86_64.whl
EOF
chmod 755 /tmp/ana3.sh
su -l $user -c "/bin/bash /tmp/ana3.sh"

#Anaconda2系
su -l $user -c "yes | pyenv install anaconda2-4.3.1"
su -l $user -c "pyenv global anaconda2-4.3.1"
su -l $user -c "pyenv rehash"
su -l $user -c "yes | conda create --name py2.7 python=2.7 anaconda"
cat << EOF > /tmp/ana2.sh
source /home/$user/.pyenv/versions/anaconda2-4.3.1/bin/activate py2.7
conda install jupyter ipykernel
jupyter kernelspec install-self --user
pip install chainer
pip install https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.12.0-cp27-none-linux_x86_64.whl
EOF
chmod 755 /tmp/ana2.sh
su -l $user -c "/bin/bash /tmp/ana2.sh"
echo "[3/5] Anaconda,chainer,tensorflowをインストールしました"

echo "[4/5] 設定ポートの解放中..."
firewall-cmd --add-port=$port/tcp --zone=public --permanent
firewall-cmd --reload
echo "[4/5] 設定ポートを解放しました"

echo "[5/5] Jupyterの実行中..."
su -l $user -c "jupyter notebook --generate-config"
hashedp=`su -l $user -c "python -c 'from notebook.auth import passwd; print(passwd(\"${password}\",\"sha256\"))'"`
echo "c.NotebookApp.password = '$hashedp'" >> $home/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.port = $port" >> $home/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.open_browser = False" >> $home/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.ip = '*'" >> $home/.jupyter/jupyter_notebook_config.py
echo "c.InlineBackend.rc = {
    'font.family': 'meiryo',
}"
echo "c.NotebookApp.notebook_dir = '$home'" >> $home/.jupyter/jupyter_notebook_config.py

cat << EOF > /etc/systemd/system/jupyter.service
[Unit]
Description = jupyter daemon

[Service]
ExecStart = /home/$user/.pyenv/shims/jupyter notebook --ip=0.0.0.0
Restart = always
Type = simple
User = $user

[Install]
WantedBy = multi-user.target
EOF

systemctl enable jupyter
systemctl start jupyter
echo "[5/5] Jupyterの実行しました"
echo "スタートアップスクリプトの処理が完了しました"
