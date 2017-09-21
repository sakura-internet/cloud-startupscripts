# 概要
- このスクリプトは単体のメールサーバをセットアップします。
- セットアップにはサーバの作成から20分程度、お時間がかかります。
# 提供機能
- メール送信
    - SPF
    - DKIM 署名
    - DMARC
    - Virus Scan
    - SMTP-AUTH
    - STARTTLS
    - SMTP over TLS
- メール受信
    - SPF 認証
    - DKIM 認証
    - DMARC 検証
    - Virus Scan
    - STARTTLS
- メール参照
    - POP over TLS
    - IMAP over TLS
- Webmail
    - Roundcube
    - Rainloop
- ユーザ管理
    - phpldapadmin
- 他
    - Thunderbird の autoconfig機能
    - メールアーカイブ機能
    - マルチドメイン対応

# セットアップ手順
### 1. メールアドレス用ドメインの準備とAPIキーの登録
  - [ゼロからはじめるMastodon](http://knowledge.sakura.ad.jp/knowledge/8591/)のStep1からStep5を参照してください
### 2. サーバの作成
```
下記は example.com をドメインとした場合の例です
```
- "アーカイブ選択" で CentOS 7.x を選択
![create01](https://user-images.githubusercontent.com/7104966/30677348-40a0b3ae-9ec6-11e7-8ed3-a7f841196a0b.png)
- "ホスト名" はドメインを省いたものを入力 (例: mail と入力した場合、 mail.example.com というホスト名になります)
- "スタートアップアクリプト" で shell を選択
- "配置するスタートアップスクリプト"で MailSystem を選択
- "作成するメールアドレスのリスト" に初期セットアップ時に作成するメールアドレスを１行に1アドレス入力
![create02](https://user-images.githubusercontent.com/7104966/30677401-8a5291a2-9ec6-11e7-8219-dfec28f7bf90.png)
- "APIキー" を選択 (DNSのレコード登録に使用します)
- "セットアップ完了メールを送信する宛先" に、メールを受信できるアドレスを入力
![create03](https://user-images.githubusercontent.com/7104966/30677427-a4594988-9ec6-11e7-9f40-506e31c2e707.png)
- 必要な項目を入力したら作成

### 3. セットアップ完了メール の確認
- セットアップ完了後に、セットアップ情報を記述したメールが届きます
- RainLoop の admin パスワードはデフォルトの為、すぐに変更してください

```
SETUP START : Tue Sep 12 01:34:13 JST 2017
SETUP END   : Tue Sep 12 01:50:08 JST 2017

-- Mail Server Domain --
smtp server : example.com
pop  server : example.com
imap server : example.com

-- phpLDAPadmin --
LOGIN URL : https://example.com/phpldapadmin
LOGIN_DN  : cn=admin,dc=sacloud
PASSWORD  : ***********

-- Roundcube Webmail --
LOGIN URL : https://example.com/roundcube

-- RainLoop Webmail --
ADMIN URL      : https://example.com/rainloop/?admin
ADMIN USER     : admin
ADMIN PASSWORD : *****
LOGIN URL      : https://example.com/rainloop

-- Process Check --
OK: slapd
OK: opendkim
OK: dovecot
OK: clamav-milter
OK: clamd
OK: yenma
OK: postfix
OK: mysqld
OK: php-fpm
OK: nginx

-- example.com DNS Check --
OK: example.com A 27.133.152.XX
OK: example.com MX 10 example.com.
OK: example.com TXT "v=spf1 +ip4:27.133.152.XX -all"
OK: mail.example.com A 27.133.152.XX
OK: autoconfig.example.com A 27.133.152.XX
OK: _dmarc.example.com TXT "v=DMARC1\; p=reject\; rua=mailto:admin@example.com"
OK: _adsp._domainkey.example.com TXT "dkim=discardable"
OK: default._domainkey.example.com TXT "v=DKIM1\; k=rsa\; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDkviwuC8KvC6OP7HwUPQEZDA+ZnY1mRzZrCJcM4sMRhhVse7Cwy/VOldbIxGTAnsRSaLmmxcz96aiCftvctue7mzIvFscCDRm35PtAS5mvlWXRP1f2brHROLoc0rv7upliPdwNXmc7UhZ2b8/gJhSDw76nFiOiOG7/x5GkLCZLCQIDAQAB"

-- example.com TLS Check --
            Not Before: Sep 11 15:50:00 2017 GMT
            Not After : Dec 10 15:50:00 2017 GMT

-- print_version --
os: CentOS Linux release 7.3.1611 (Core) 
slapd: 2.4.40
opendkim: v2.11.0
dovecot: 2.2.32
dovecot-pigeonhole: 0.4.20
clamav-milter: 0.99.2
clamd: 0.99.2
yenma: v2.0.0-beta4
postfix: 2.10.1
mysql: Ver 15.1 Distrib 10.1.26-MariaDB
php-fpm: 5.4.16
nginx: 1.10.2
roundcube: 1.1.9
phpldapadmin: 1.2.3
rainloop: 1.10.5.192

-- create Mail Address and Password List --
user01@example.com: ***********
user02@example.com: ***********
archive@example.com: ***********
```
# システム構成
### 1. メール送受信
![infra01](https://user-images.githubusercontent.com/7104966/30677591-8bf4c9f2-9ec7-11e7-8e4b-5659399eb91d.png)
![infra02](https://user-images.githubusercontent.com/7104966/30677592-8bf50584-9ec7-11e7-9c46-0bca12659a96.png)
![infra03](https://user-images.githubusercontent.com/7104966/30677590-8bf45fda-9ec7-11e7-89c2-d518f1ce8f2b.png)
### 2. メール参照
![infra04](https://user-images.githubusercontent.com/7104966/30677593-8c071b20-9ec7-11e7-8b14-28e628fa3bc2.png)

# インストールアプリケーションと主な用途
- openldap
    - LDAPサーバ
    - メールアドレスの管理
- opendkim
    - 送信メールの DKIM 署名
- さくらのクラウドDNSへのレコード登録(PTRを除いた8レコード)
    - A レコード (メールドメイン用、ホスト名用、autoconfig用)
    - MX レコード
    - TXT レコード (SPF, DKIM, DKIM-ADSP, DMARC)
- dovecot, dovecot-pigeonhole
    - LMTP,POP,IMAP,ManageSieveサーバ
    - メール保存 (LMTP)
    - メール参照 (POP/IMAP)
    - メールフィルタリング (Sieve)
    - メール転送 (Sieve)
- clamav, clamav-milter
    - 送受信メールの ウィルススキャンサーバ
- yenma
    - 受信メールの SPF, DKIM, DMARC 検証サーバ
- postfix, postfix-inbound
    - メール送信サーバ(postfix)
    - メール受信サーバ(postfix-inbound)
- nginx, php-fpm
    - Webサーバ(HTTPS)
    - メールプロキシサーバ(SMTP Submission,SMTPS,POPS,IMAPS)
    - メールプロキシ用認証サーバ(HTTP)
- mariadb
    - roundcube用DB
- roundcube
    - Webメール
    - パスワード変更
    - メールフィルタ設定
- phpldapadmin
    - メールドメイン管理
    - メールアカウント管理
- DNS登録(PTR)
    - PTR レコード
- TLS対応(Lets Encrypt)
    - 証明書
- rainloop
    - Webメール
- thunderbird の autoconfig設定
    - Thunderbird へのアカウント登録簡略化
# セットアップ後の確認
## Rainloopでのログイン確認
- 管理ページ

![rainloop_admin](https://user-images.githubusercontent.com/7104966/30680306-cd3dba1a-9ed9-11e7-8a8a-fcad00f62761.png)
- Webメール

![rainloop_login](https://user-images.githubusercontent.com/7104966/30680305-cd39e4e4-9ed9-11e7-8c55-3e6548af81bf.png)

## Roundcubeでのログイン確認
- Webメール

![roundcube](https://user-images.githubusercontent.com/7104966/30680307-cd41f1ca-9ed9-11e7-81e6-19ff1c488d17.png)

## phpldapadminのログイン確認
- ログイン後、メールアドレスの追加/削除/パスワード変更などができる
    - メールアドレスの追加は、既存のユーザのレコードをコピーし、固有なIDのみ変更してください

![phpldapadmin](https://user-images.githubusercontent.com/7104966/30680400-580b6066-9eda-11e7-9c0d-d4c721fefb64.png)

## ThunderBirdへのアカウント追加
- autoconfigによりメールアドレスとパスワードの入力だけで設定が完了する

![thunderbird](https://user-images.githubusercontent.com/7104966/30680317-d9df3d70-9ed9-11e7-8168-fffb5fa4aa9d.png)

## 補足
- 1通のメールサイズは20MBまで、MBOXのサイズ、メッセージ数に制限はしていない
- adminアドレスはエイリアス設定をしている (下記のアドレス宛のメールは admin 宛に配送される)
 - admin,　root, postmaster, abuse, nobody, virus-report
- virus メールの対応
 - clamav-milter で検知した virus メールは postfix の queue に hold される
 - cron で毎分 hold された virus メールを調査し削除する。削除時に自ドメインの送信者or受信者に削除レポートを送信する
- 各種 milter(opendkim, yenma, clamav-milter) が正常に動作していない場合、postfixは tempfail を応答する
- メールの転送
 - 受信時の宛先を Envelope From に変更して転送することで SPF のみ対応している
 - 特定のメールアドレスに届いたメールを複数の宛先に転送する設定をすればメーリングリストのように使用することも可能
- メールアーカイブ機能
 - archive@domain というメールアドレスを作成すると、該当ドメインの全てのユーザの送信/受信メールが該当アドレスに複製配送(bcc)される
 - archive アドレスのメールボックスのみ cron で 1年経過したメールを削除する
- マルチドメイン対応方法
 - さくらのクラウドDNSに複数ゾーンを追加し、サーバ作成時に複数のドメイン分のメールアドレスを入力する

## コマンドでのメールアドレスの管理

```
・メールアドレスの確認
# ldapsearch -x mailroutingaddress=admin@example.com
dn: uid=admin,ou=People,dc=example,dc=com
objectClass: uidObject
objectClass: simpleSecurityObject
objectClass: inetLocalMailRecipient
objectClass: sendmailMTA
uid: sakura
mailHost: 127.0.0.1
sendmailMTAHost: 127.0.0.1
description: example.com
mailRoutingAddress: admin@example.com
mailLocalAddress: admin@example.com
mailLocalAddress: root@example.com
mailLocalAddress: postmaster@example.com
mailLocalAddress: abuse@example.com
mailLocalAddress: virus-report@example.com
mailLocalAddress: nobody@example.com

※)mailLocalAddress 宛のメールが mailRoutingAddress のMBOXに配送される
*)nginx mail proxy は mailHost に POP/IMAP を Proxy する
※)nginx mail proxy は sendmailTMAHost に SMTP を Proxy する
*)postfix-inbound は mailHost に LMTP で配送をする
*)postfix-inbound は admin の description に記述されているドメイン宛のメールを自ホスト宛と判断している

・パスワード変更: archive@example.com のパスワードを xxxxxx に変更する(******は ROOT_DNのパスワード)
# ldappasswd -x -D "cn=admin,dc=sacloud" -w ****** -s xxxxxx "uid=archive,ou=People,dc=example,dc=com"

・メールアドレス無効化: foobar@example.com の ou を People から Disable に変更する
ldapmodify -D cn=admin,dc=sacloud -W
dn: uid=foobar,ou=People,dc=example,dc=com
changetype: modrdn
newrdn: uid=foobar
deleteoldrdn: 0
newsuperior: ou=Disable,dc=example,dc=com

・メールアドレス追加 (作成したメールアドレスのパスワードが最後に出力されます)
# /root/.sacloud-api/notes/startup-script-mailsystem/setup_scripts/_create_mailaddress.sh adduser@example.com

```
