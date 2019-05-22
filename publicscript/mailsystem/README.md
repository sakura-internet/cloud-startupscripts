# 概要
- メールシステム
    - このスクリプトは単体のメールサーバをセットアップします。
    - セットアップにはサーバの作成から20分程度、お時間がかかります。
# 提供機能
- メール送信
    - SPF
    - DKIM 署名
    - DMARC
    - ARC 署名
    - Virus Scan
    - SMTP-AUTH
    - STARTTLS
    - SMTP over TLS
- メール受信
    - SPF 検証
    - DKIM 検証
    - DMARC 検証
    - ARC 検証
    - Virus Scan
    - Spam Check
    - STARTTLS
- メール参照
    - POP over TLS
    - IMAP over TLS
- Webmail
    - Roundcube
- ユーザ管理
    - phpldapadmin
- 他
    - Thunderbird の autoconfig 対応
    - メールアーカイブ機能
    - マルチドメイン対応

# セットアップ手順
### 1. メールアドレス用ドメインの準備とAPIキーの登録
- [ゼロからはじめるMastodon](http://knowledge.sakura.ad.jp/knowledge/8591/)のStep1からStep5をご覧ください
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
- メールが届かない場合は、サーバにログインしインストールログを確認してください

```
SETUP START : Tue Sep 12 01:34:13 JST 2017
SETUP END   : Tue Sep 12 01:50:08 JST 2017

-- Mail Server Domain --
smtp server : example.com
pop  server : example.com
imap server : example.com

-- Rspamd Webui --
LOGIN URL : https://example.com/rspamd
PASSWORD  : ***********

-- phpLDAPadmin --
LOGIN URL : https://example.com/phpldapadmin
LOGIN_DN  : cn=config
PASSWORD  : ***********

-- Roundcube Webmail --
LOGIN URL : https://example.com/roundcube

-- Process Check --
OK: slapd
OK: dovecot
OK: clamd
OK: rspamd
OK: redis-server
OK: postfix
OK: mysqld
OK: php-fpm
OK: nginx

-- Application Version --
os: CentOS Linux release 7.3.1611 (Core) 
slapd: 2.4.44
dovecot: 2.3.6
clamd: 0.101.2
postfix: 2.10.1
mysql: Ver 14.14 Distrib 5.7.26
php-fpm: 7.3.5
nginx: 1.12.2
roundcube: 1.4-git
phpldapadmin: 1.2.3

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
Validity:
 Not Before: May 16 05:52:58 2019 GMT
 Not After : Aug 14 05:52:58 2019 GMT
Subject Alternative Name:
 DNS:*.example.com, DNS:example.com

-- Mail Address and Password --
admin@example.com: ***********
user01@example.com: ***********
user02@example.com: ***********
archive@example.com: ***********
```
# インストールアプリケーションと主な用途
- openldap
    - LDAPサーバ
    - メールアドレスの管理
- usacloud
    - さくらのクラウドDNSへのレコード登録に使用
- さくらのクラウドDNSへのレコード登録(PTRを除いた8レコード)
    - A レコード (メールドメイン用、ホスト名用)
    - MX レコード
    - TXT レコード (SPF, DKIM, DKIM-ADSP, DMARC)
    - CNAME レコード (Thunderbird の autoconfig用)
- dovecot
    - LMTP,POP,IMAP,ManageSieveサーバ
    - メール保存 (LMTP)
    - メール参照 (POP/IMAP)
    - メールフィルタリング (Sieve)
    - メール転送 (Sieve)
- rspamd
    - 送信メールの DKIM, ARC 署名
    - 受信メールの SPF, DKIM, DMARC, ARC 検証
    - 受信メールの Spam Check
    - 送受信メールの Virus Scan (clamav と連携)
- clamav
    - 送受信メールの ウィルススキャンサーバ
- postfix, postfix-inbound
    - メール送信サーバ(postfix)
    - メール受信サーバ(postfix-inbound)
- nginx, php-fpm(7.3系)
    - Webサーバ(HTTPS)
    - メールプロキシサーバ(SMTP Submission,SMTPS,POPS,IMAPS)
    - メールプロキシ用認証サーバ(HTTP)
- mysql
    - roundcube用データベース
- roundcube(1.4系)
    - Webメール
    - パスワード変更
    - メールフィルタ設定
    - メール転送設定
- phpldapadmin
    - メールドメイン管理
    - メールアカウント管理
- DNS登録(PTR)
    - PTR レコード
- TLS対応(Lets Encrypt)
    - 証明書
- thunderbird の autoconfig設定
    - Thunderbird へのアカウント登録簡略化
## phpldapadminのログイン
- ログイン後、メールアドレスの追加/削除/無効化/パスワード変更などができる
    - メールアドレスの追加は、既存のユーザのレコードをコピーし、固有なIDのみ変更すること

![phpldapadmin](https://user-images.githubusercontent.com/7104966/30680400-580b6066-9eda-11e7-9c0d-d4c721fefb64.png)

## ThunderBirdへのアカウント追加
- autoconfigによりメールアドレスとパスワードの入力だけで設定が完了する

![thunderbird](https://user-images.githubusercontent.com/7104966/30680317-d9df3d70-9ed9-11e7-8168-fffb5fa4aa9d.png)

## 補足
- 1通のメールサイズは20MBまで、MBOXのサイズ、メッセージ数に制限はしていない
- adminアドレスはエイリアス設定をしている (下記のアドレス宛のメールは admin 宛に配送される)
    - admin, root, postmaster, abuse, nobody, dmarc-report
- virus メールの対応
    - clamavで Virus と判定したメールは reject される
- rspamd が正常に動作していない場合、postfixは tempfail を応答する
- メールアーカイブ機能
    - archive@ドメイン というメールアドレスを作成すると、該当ドメインの全てのユーザの送信/受信メールが該当アドレスに複製配送(bcc)される
    - archive アドレスのメールボックスのみ cron で 受信日時から1年経過したメールを削除する
- マルチドメイン設定方法
    - さくらのクラウドDNSに複数ゾーンを追加し、サーバ作成時に複数のドメインのメールアドレスを入力する
    - Thunderbird の autoconfig はマルチドメインに対応していない
- 各種OSSの設定、操作方法についてはOSSの公式のドキュメントをご参照ください

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
mailRoutingAddress: admin@example.com
mailLocalAddress: admin@example.com
mailLocalAddress: root@example.com
mailLocalAddress: postmaster@example.com
mailLocalAddress: abuse@example.com
mailLocalAddress: virus-report@example.com
mailLocalAddress: nobody@example.com

※)mailLocalAddress 宛のメールが mailRoutingAddress のMBOXに配送される
※)nginx mail proxy は mailHost に POP/IMAP を Proxy する
※)nginx mail proxy は sendmailTMAHost に SMTP を Proxy する
※)postfix-inbound は mailHost に LMTP で配送をする

・パスワード変更: archive@example.com のパスワードを xxxxxx に変更する(******は ROOT_DNのパスワード)
# ldappasswd -x -D "cn=config" -w ****** -s xxxxxx "uid=archive,ou=People,dc=example,dc=com"

・メールアドレス無効化: foobar@example.com の ou を People から Termed に変更する
ldapmodify -D cn=config -W
dn: uid=foobar,ou=People,dc=example,dc=com
changetype: modrdn
newrdn: uid=foobar
deleteoldrdn: 0
newsuperior: ou=Termed,dc=example,dc=com

・メールアドレス追加 (作成したメールアドレスのパスワードが出力されます)
# /root/.sacloud-api/notes/cloud-startupscripts/publicscript/mailsystem/tools/create_mailaddress.sh adduser@example.com

```
