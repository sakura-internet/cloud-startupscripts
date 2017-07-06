さくらのクラウド スタートアップスクリプト
====

スタートアップスクリプトは、新たにサーバを作成する際、任意の「スタートアップスクリプト」を選択することにより、起動時にそれらを自動的に実行する機能です。
さくらインターネットが提供しているパブリックスタートアップスクリプトを一覧です

詳細は[さくらのクラウドニュース](https://cloud-news.sakura.ad.jp/startup-script/)をご参照ください

# 提供中スタートアップスクリプト一覧

## LAMP
yumによりApache、MySQL、PHPをインストールし、LAMP構成を作成します。

## WordPress
yumにより、ApacheとMySQLをインストール・Wordpres向けの設定を自動的に行い、Wordpress最新バージョンをインストールします。
サーバ作成後はサーバのIPアドレスにWebブラウザでアクセスするとWordpress初期画面が表示される状態となります。

## Redmine
プロジェクト管理ソフトウェアのRedmineをインストールし、起動時に動作する状態に設定します。

## Git Clone
指定のGitリポジトリをcloneし、指定の実行ファイルを自動的に実行します。
拡張子が .yml のものは Ansible Playbook として解釈されます。


## Ruby on Rails
スクリプト言語RubyのフレームワークであるRuby on Railsをインストールします。


## ownCloud
ownCloudをセットアップするスクリプトです。
サーバ作成後はブラウザより「http://サーバIPアドレス/owncloud/」にアクセスすることでownCloudの設定が行えます。
 
※ownCloudのスタートアップスクリプトでインストールされるPHPのバージョンはownCloudの推奨バージョンより低くなっているため、5.3.8以降のバージョンにアップデートすることを推奨します。


## Sacloud CLI
さくらのクラウドで提供しているSacloud CLIと、実行環境のnode.jsをインストールします。


## yum update
サーバ作成後の初回起動時のみ、コマンド”yum update”を実行します。実行完了後、サーバが再起動されます。
※CentOS6系またはScientific Linux6系のみで動作します


## apt-get update/upgrade
サーバ作成後の初回起動時のみ、コマンド”apt-get update”および”apt-get upgrade”を実行します。実行完了後、サーバが再起動されます。
※DebianまたはUbuntuのみで動作します


## lb-dsr
ロードバランス対象のサーバの初期設定を自動化するためのスクリプトです。
このスクリプトは、以下のアーカイブでのみ動作します
* CentOS 6.X
* CentOS 7.X
* SiteGuard Lite Ver3.X UpdateX (CentOS 6.X)
* SiteGuard Lite Ver3.X UpdateX (CentOS 7.X)


## RabbitMQ
メッセージキュー管理システムであるRabbitMQをインストールします。


## Drupal for Ubuntu
高機能CMSであるDrupalをインストールします。
※Ubuntu 14.04 または 16.04 でのみ動作します


## Drupal for CentOS 7
高機能CMSであるDrupalをインストールします。
※CentOS 7でのみ動作します


## WordPress for KUSANAGI8
KUSANAGI8 環境に WordPress をセットアップするスクリプトです。
本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/wordpress-for-kusanagi8/)を参照ください。


## zabbix-server
監視サーバであるzabbix-serverをインストールします。
本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/startup-script/zabbix-server/)を参照ください。
※CentOS7系のみで動作します


## zabbix-agent
zabbix-serverに対応するエージェントzabbix-agentをインストールします。
本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/startup-script/zabbix-agent/)を参照ください。
※CentOS7系のみで動作します


## hatohol-server
複数のzabbix-serverを統合管理するhatoholをインストールします。
※CentOS7系のみで動作します


## Magento
越境ECプラットフォームであるMagentoをインストールします。
本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/startup-script/magento/)を参照ください。
※Ubuntu 16系のみで動作します


## Mastodon
Twitterライクな投稿ができる分散型ソーシャルネットワーク「Mastodon」のインスタンス（サーバ）をセットアップします。
※CentOS7系のみで動作します


## Node-RED
ブラウザの操作だけででハードウェア・デバイスを制御できるプログラミング・ツール「Node-RED」をインストールします。
※CentOS7系のみで動作します


## SHIRASAGI 
Ruby、Ruby on Rails、MongoDBで動作する中・大規模サイト向けCMS「SHIRASAGI」をインストールします。
※CentOS7系のみで動作します


## Terraform for さくらのクラウド
インフラ構築や構成変更をコードで管理する“Infrastructure as Code“を実現するための、オープンソースのコマンドラインツール「Terraform」およびさくらのクラウドを利用するためのプラグインを一括でインストールします。詳細は「[Terraform for さくらのクラウド](https://cloud-news.sakura.ad.jp/startup-script/terraform-for-sakuracloud/)」をご確認ください。
※CentOS7系のみで動作します


## kibana
分析基盤としてElasticsearchとKibana、ログ収集のFluentdを一括しセットアップすることの出来るスタートアップスクリプトです。
インストール内容の詳細などは[SlideShare](https://www.slideshare.net/sakura_pr/sakura-cloudkibanaelasticsearchstartupscript)をご参照ください。
※CentOS7系のみで動作します


## Jupyter Notebook
データサイエンス環境としてAnacondaとウェブブラウザ上から手軽にプログラムを実行できるJupyter Notebookを一括でセットアップすることの出来るスタートアップスクリプトです。
インストール内容の詳細などは[SlideShare](https://www.slideshare.net/sakura_pr/sakura-cloud-startup-script-jupyter-notebook)をご参照ください。
※CentOS7系のみで動作します


## Vuls
オープンソースで開発が進められているLinux/FreeBSD向けの脆弱性スキャンツールです。
OSだけでなくミドルウェアやプログラム言語のライブラリなどもスキャンに対応しております。
また、エージェントレスで実行させることが出来、SSH経由でリモートのサーバのスキャンを行うことも可能です。
※CentOS7系のみで動作します