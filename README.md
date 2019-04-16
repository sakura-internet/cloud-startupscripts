さくらのクラウド スタートアップスクリプト
====

スタートアップスクリプトは、新たにサーバを作成する際、任意の「スタートアップスクリプト」を選択することにより、起動時にそれらを自動的に実行する機能です。
さくらインターネットが提供しているパブリックスクリプトの一覧です。

詳細は[さくらのクラウドニュース](https://cloud-news.sakura.ad.jp/startup-script/)をご参照ください。

* [スタートアップスクリプトの登録をご希望の場合・登録のしかた](how-to-contribute.md)


# 提供中スタートアップスクリプト一覧

* [アプリケーション](#application)
* [開発ツール・開発環境・ミドルウェア](#development)
* [さくらのクラウド開発ツール・設定支援](#sacloud)
* [システム管理・運用](#admin)

## <a name="application">アプリケーション</a>

| 分類 | 名前 | 説明 |
| --- | --- | :--- |
| メール | [メールシステム](./publicscript/mailsystem/mailsystem.sh) | スタートアップスクリプトを実行するだけで、メールサーバやWeb UIのセットアップ、DNS設定、メールアドレス発行を自動的に行えるスクリプトです。詳しくは [ドキュメント](./publicscript/mailsystem/README.md) をご覧ください。 <br />※CentOS 7でのみ動作します |
| Wiki | [Crowi](./publicscript/crowi/crowi.sh) | Markdown形式で記述可能な組織用コミュニケーションツール[Crowi](http://site.crowi.wiki/)をセットアップするスクリプトです。サーバ作成後はブラウザより `http://サーバのIPアドレス/installer` にアクセスすることで設定が行えます。<br />※Ubuntu 16.04 でのみ動作します |
| Wiki | [Restyaboard](./publicscript/restyaboard/restyaboard.sh) |オープンソースのカンバンボードであるRestyaboard をセットアップします<br />サーバ作成後はブラウザより `http://サーバIPアドレス/` にアクセスすることで設定が行えます。<br />※CentOS7系のみで動作します |
| CMS | [Drupal for Ubuntu](./publicscript/drupal_for_ubuntu/drupal_for_ubuntu.sh) | 高機能CMSであるDrupalをインストールします。<br />※Ubuntu 16.04 でのみ動作します |
| CMS | [Drupal for CentOS 7](./publicscript/drupal_for_centos7/drupal_for_centos7.sh) | 高機能CMSであるDrupalをインストールします。<br />※CentOS 7でのみ動作します |
| CMS | [SHIRASAGI](./publicscript/shirasagi/shirasagi.sh) | Ruby、Ruby on Rails、MongoDBで動作する中・大規模サイト向けCMS「SHIRASAGI」をインストールします。 [公式サイトはこちら](http://www.ss-proj.org/)です。<br />※CentOS7系のみで動作します |
| CMS | [WordPress](./publicscript/wordpress_for_centos7/wordpress_for_centos7.sh) | yumにより、ApacheとMySQLをインストール・WordPress向けの設定を自動的に行い、WordPress最新バージョンをインストールします。<br />サーバ作成後はサーバのIPアドレスにWebブラウザでアクセスするとWordPress初期画面が表示される状態となります。 |
| CMS | [WordPress for KUSANAGI8](./publicscript/wordpress_for_kusanagi8/wordpress_for_kusanagi8.sh) | KUSANAGI8 環境に WordPress をセットアップするスクリプトです。<br />本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/wordpress-for-kusanagi8/)を参照ください。 |
| CMS | [baserCMS](./publicscript/basercms/basercms.sh) | Webサイト製作プラットフォーム、[baser CMS](https://basercms.net/) をインストールします。 |
| オンラインストレージ | [ownCloud](./publicscript/owncloud/owncloud.sh) | ownCloudをセットアップするスクリプトです。<br />サーバ作成後はブラウザより「`http://サーバIPアドレス/owncloud/`」にアクセスすることでownCloudの設定が行えます。<br />※ownCloudのスタートアップスクリプトでインストールされるPHPのバージョンはownCloudの推奨バージョンより低くなっているため、5.3.8以降のバージョンにアップデートすることを推奨します。 |
| オンラインストレージ | [Nextcloud](./publicscript/nextcloud/nextcloud.sh) | Nextcloudをセットアップするスクリプトです。<br />サーバ作成後はブラウザより「`http://サーバIPアドレス/nextcloud/`」にアクセスすることでNextcloudの設定が行えます。<br />*CentOS 7でのみ動作します |
| ECプラットフォーム | [Magento](./publicscript/magento/magento.sh) | 越境ECプラットフォームであるMagentoをインストールします。<br />本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/startup-script/magento/)を参照ください。<br />※Ubuntu 16系のみで動作します |
| SNS | [Mastodon](./publicscript/mastodon/mastodon.sh) | Twitterライクな投稿ができる分散型ソーシャルネットワーク「Mastodon」のインスタンス（サーバ）をセットアップします。<br />※CentOS7系のみで動作します |
| コミュニケーション | [Mattermost](./publicscript/mattermost/mattermost.sh) | オープンソースのチャット型コミュニケーションツール「 [Mattermost](https://github.com/mattermost/platform/blob/master/README.md) 」サーバや MySQL、DNS を同時にセットアップします。<br />※ CentOS7 系のみで動作します |
| 科学計算 | [Jupyter Notebook](./publicscript/jupyter_notebook/jupyter_notebook.sh) | データサイエンス環境としてAnacondaとウェブブラウザ上から手軽にプログラムを実行できるJupyter Notebookを一括でセットアップすることの出来るスタートアップスクリプトです。<br />インストール内容の詳細などは[SlideShare](https://www.slideshare.net/sakura_pr/sakura-cloud-startup-script-jupyter-notebook)をご参照ください。<br />※CentOS7系のみで動作します |
| 分析基盤 | [kibana](./publicscript/kibana/kibana.sh) | 分析基盤としてElasticsearchとKibana、ログ収集のFluentdを一括しセットアップすることの出来るスタートアップスクリプトです。<br />インストール内容の詳細などは[SlideShare](https://www.slideshare.net/sakura_pr/sakura-cloudkibanaelasticsearchstartupscript)をご参照ください。<br />※CentOS7系のみで動作します |


## <a name="development">開発ツール・開発環境・ミドルウェア</a>

| 分類 | 名前 | 説明 |
| --- | --- | :--- |
| SSL環境 | [Let's Encrypt](./publicscript/letsencrypt/letsencrypt.sh) | Nginx と certbot-auto をインストールし、入力したドメインで Let's Encrypt の TLS 証明書を取得します。また、さくらのクラウド DNS で、A レコードを追加します。<br />※CentOS7系のみで動作します。 |
| 開発支援 | [Git Clone](./publicscript/git_clone/git_clone.sh) | 指定のGitリポジトリをcloneし、指定の実行ファイルを自動的に実行します。<br />拡張子が .yml のものは Ansible Playbook として解釈されます。 |
| メッセージキュー管理 | [RabbitMQ](./publicscript/rabbitmq/rabbitmq.sh) | メッセージキュー管理システムであるRabbitMQをインストールします。 |
| 開発言語・フレームワーク | [Laravel](./publicscript/laravel/laravel.sh) | "Web職人のためのPHPフレームワーク" をインストールします。<br />※CentOS7系のみで動作します。 |
| 開発言語・フレームワーク | [LAMP](./publicscript/lamp/lamp.sh) | yumによりApache、MySQL、PHPをインストールし、LAMP構成を作成します。 |
| 開発言語・フレームワーク | [Node-RED](./publicscript/node-red/node-red.sh) | ブラウザの操作だけでハードウェア・デバイスを制御できるプログラミング・ツール「Node-RED」をインストールします。<br />※CentOS7系のみで動作します |
| 開発言語・フレームワーク | [Ruby on Rails](./publicscript/ruby_on_rails/ruby_on_rails.sh) | スクリプト言語RubyのフレームワークであるRuby on Railsをインストールします。 |
| プロジェクト管理 | [GitLab CE](./publicscript/gitlab/gitlab.sh) | GitHubライクなGitリポジトリ管理機能を持つモダン開発者向けプラットフォーム「[GitLab](https://about.gitlab.com)」をインストールします。<br />※推奨メモリは4GBです |
| プロジェクト管理 | [Redmine](./publicscript/redmine/redmine.sh) | プロジェクト管理ソフトウェアのRedmineをインストールし、起動時に動作する状態に設定します。 |
| オブジェクトストレージ | [Minio](./publicscript/minio/minio.sh) |  [minio](https://minio.io/) という管理用UIやAPIを備えるオブジェクトストレージサーバをインストールします。 例えば、fluent-plugin-dstat のデータ保存先としても活用可能であり、kibanaと連携してdstatの可視化も可能です<br />※Ubuntu 16.04のみで動作します |


## <a name="sacloud">さくらのクラウド開発ツール・設定支援</a>

| 分類 | 名前 | 説明 |
| --- | --- | :--- |
| 設定支援 | [lb-dsr](./publicscript/lb-dsr/lb-dsr.sh) | ロードバランス対象のサーバの初期設定を自動化するためのスクリプトです。<br />このスクリプトは、以下のアーカイブでのみ動作します<br />- CentOS 6.X<br />- CentOS 7.X |
| 設定支援 | [switching consoles for RancherOS](./publicscript/switching_consoles_for_rancheros/switching_consoles_for_rancheros.yml) | Rancher OSの標準のコンソールを設定するサンプルスクリプトです<br />このスクリプトは、以下のアーカイブでのみ動作します<br />- RancherOS |
| CLI | [Usacloud](./publicscript/usacloud/usacloud.sh) | さくらのクラウドをコマンドラインで操作する [Usacloud](https://github.com/sacloud/usacloud)  をインストールします。[Usacloud](https://github.com/sacloud/usacloud)  は、さくらインターネット公認のユーザーコミュニティが開発を進めているツールです 。<br />※CentOS7系のみで動作します |
| CLI | [Terraform for さくらのクラウド](./publicscript/terraform_for_sacloud/terraform_for_sacloud.sh) | インフラ構築や構成変更をコードで管理する“Infrastructure as Code“を実現するための、オープンソースのコマンドラインツール「Terraform」およびさくらのクラウドを利用するためのプラグインを一括でインストールします。詳細は「[Terraform for さくらのクラウド](https://cloud-news.sakura.ad.jp/startup-script/terraform-for-sakuracloud/)」をご確認ください。<br />※CentOS7系のみで動作します |


## <a name="admin">システム管理・運用</a>

| 分類 | 名前 | 説明 |
| --- | --- | :--- |
| パッケージ管理 | [yum update](./publicscript/yum_update/yum_update.sh) | サーバ作成後の初回起動時のみ、コマンド”yum update”を実行します。実行完了後、サーバが再起動されます。<br />※CentOS6系のみで動作します |
| パッケージ管理 | [apt-get update/upgrade](./publicscript/apt-get_update_upgrade/apt-get_update_upgrade.sh) | サーバ作成後の初回起動時のみ、コマンド”apt-get update”および”apt-get upgrade”を実行します。実行完了後、サーバが再起動されます。<br />※DebianまたはUbuntuのみで動作します |
| コンテナ管理 | [Docker/docker-compose](./publicscript/docker/docker.sh) | Dockerとdocker-composeコマンドをセットアップします。 |
| コンテナ管理 | [Rancher2セットアップ](./publicscript/rancher2_setup/rancher2_setup.sh) | Rancher サーバとウェブ UI を自動的にセットアップするスクリプトです。ui-driver-sakuracloud がセットアップされ、さくらのクラウド上で Kubernetes クラスタを素早くセットアップできます。<br />※CentOS7系のみで動作します |
| 監視 | [zabbix-server](./publicscript/zabbix-server/zabbix-server.sh) | 監視サーバであるzabbix-serverをインストールします。<br />本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/startup-script/zabbix-server/)を参照ください。<br />※CentOS7系のみで動作します |
| 監視 | [zabbix-agent](./publicscript/zabbix-agent/zabbix-agent.sh) | zabbix-serverに対応するエージェントzabbix-agentをインストールします。<br />本スクリプトの詳細は[マニュアル](https://cloud-news.sakura.ad.jp/startup-script/zabbix-agent/)を参照ください。<br />※CentOS7系のみで動作します |
| 監視 | [hatohol-server](./publicscript/hatohol-server/hatohol-server.sh) | 複数のzabbix-serverを統合管理するhatoholをインストールします。<br />※CentOS7系のみで動作します
| セキュリティ | [SiteGuard Lite](./publicscript/siteguardlite/siteguardlite.sh) | WAF(Web Application Firewall)は、これまでのL3ファイアウォールでは防御することが難しかった、Web上で動作するアプリケーションなどのL7への攻撃検知・防御や、アクセス制御機構などを提供するものです。さくらのクラウドではJP-Secure社が開発する純国産のホスト型WAF製品「 SiteGuard Lite 」をさくらのクラウド向け特別版として無料で提供しています。<br />※CentOS系のみで動作します |
| セキュリティ | [Vuls](./publicscript/vuls/vuls.sh) | オープンソースで開発が進められているLinux/FreeBSD向けの脆弱性スキャンツールです。OSだけでなくミドルウェアやプログラム言語のライブラリなどもスキャンに対応しております。また、エージェントレスで実行させることが出来、SSH経由でリモートのサーバのスキャンを行うことも可能です。<br />※CentOS7系のみで動作します |
| セキュリティ | [initial-setup](./publicscript/initial-setup/initial-setup.sh) | CentOSの基本的な初期設定（ユーザ作成、suコマンドの制限、SSHの制限）をします。<br /> ※CentOS6またはCentOS7のみで動作します |
| RDP環境 | [GNOME-xrdp](./publicscript/xrdp/xrdp.sh) | GNOMEデスクトップ環境と xrdp をインストールします。Microsoftのリモートデスクトップなどを使用してサーバに接続することができます。<br />※CentOS7系のみで動作します |
