#!/bin/bash
# @sacloud-name "BoltzEngine"
# @sacloud-desc-begin
#  - 説明 -
#  CentOS 7.x 環境にフェンリル株式会社が提供する BoltzEngine 及び BoltzMessenger がインストールされます。
#
#  このプログラムはさくらインターネット株式会社が提供するサービス上でご利用頂く限り、無償の機能制限版として無期限でご利用頂けます。
#  機能制限を解除したい場合は、別途有償契約を行う必要がございます。
#
#  - BoltzEngine について -
#   ・BoltzEngine - Fenrir Inc. : https://boltzengine.fenrir-inc.com/
#
#  - EULA -
#   ・BoltzEngine EULA : 	https://boltzengine.fenrir-inc.com/EULA
#   ・プライバシーポリシー : 	https://boltzengine.fenrir-inc.com/privacy
#
#  - 有償契約申込み -
#   ・さくらインターネット専用プラン : https://sakura.boltzengine.fenrir-inc.com/
#
#  - 動作推奨環境 -
#  　　OS：			CentOS 7.x ~
#  　　CPU：		2 コア以上
#  　　memory：	4 GB 以上
#  　　Disk：		10 GB 以上の空き容量
#  　　Network：	1 Gbps 以上
#
#  - 動作構成例 -
#  【単構成（無償）】
#  　[Enhanced LB (SSL)] - [Server (boltz-master + boltz-slave + Web + Admin + DB)]
#  【複構成（有償）】
#  　[Enhanced LB (SSL)] + [Server (boltz-master + Web + Admin)]
#  　　　　　　　　　　　+ [Server (boltz-slave)] x n台
# @sacloud-desc-end
# @sacloud-once
# @sacloud-require-archive distro-centos distro-ver-7.*
# @sacloud-tag @require-core>=2 @require-memory-gib>=4 @simplemode @tab-marketplace

# @sacloud-checkbox required EULA_ACCEPTED "利用規約 (EULA) に同意して利用する"

# @sacloud-text     required default=boltz DATABASE_USER          "[DB] 接続ユーザ名" ex="boltz"
# @sacloud-password required               DATABASE_PASSWORD      "[DB] パスワード"
# @sacloud-password required               DATABASE_ROOT_PASSWORD "[DB] rootパスワード"

# @sacloud-text             APNS_ISSUER "[APNs] Issuer ID (Develper Program の Team ID)"
# @sacloud-text             APNS_KEYID  "[APNs] Key ID (p8 ファイル作成時に同時に発行されるID)"
# @sacloud-text             APNS_TOPIC  "[APNs] Topic (アプリの Bundle ID)" ex="com.example.app.**********"
# @sacloud-textarea heredoc APNS_P8KEY  "[APNs] Private Key (p8 ファイルの内容)"

# @sacloud-textarea heredoc FCM_SERVICE_ACCOUNT "[FCM] サービスアカウントキーが含まれる JSON ファイルの中身"

# @sacloud-text ADM_CLIENTID     "[ADM] OAuth2 client ID" ex="amzn1.application-oa2-client.********************************"
# @sacloud-text ADM_CLIENTSECRET "[ADM] OAuth2 client secret" ex="01234567489abcdrf01234567489abcdrf01234567489abcdrf01234567489ab"

# @sacloud-text WEBPUSH_SUBJECT "[WebPush] 送信者 (subject)" ex="mailto:info@example.com"

set -eu
export LANG=C

: "set env" && {
    CUR=`pwd`

    if [[ -e "${CUR}/.env" ]]; then
        export $(cat "${CUR}/.env" | xargs)
    fi
}

: "pre check" && {
    : "EULA" && {
        if [[ -z '@@@EULA_ACCEPTED@@@' ]]; then
            echo "You must agree to the EULA" >&2
            exit 2
        fi
    }
}

: "install wget" && {
    yum -y update || exit 1
    yum -y install wget || exit 1
}

: "save .env" && {
    if [[ ! -e "${CUR}/.env" ]]; then
        echo "DATABASE_USER=\"@@@DATABASE_USER@@@\""                                        | tee    "${CUR}/.env"
        echo "DATABASE_PASSWORD=\"@@@DATABASE_PASSWORD@@@\""                                | tee -a "${CUR}/.env"
        echo "DATABASE_ROOT_PASSWORD=\"@@@DATABASE_ROOT_PASSWORD@@@\""                      | tee -a "${CUR}/.env"
        echo "APNS_ISSUER=\"@@@APNS_ISSUER@@@\""                                            | tee -a "${CUR}/.env"
        echo "APNS_KEYID=\"@@@APNS_KEYID@@@\""                                              | tee -a "${CUR}/.env"
        echo "APNS_TOPIC=\"@@@APNS_TOPIC@@@\""                                              | tee -a "${CUR}/.env"
        echo "ADM_CLIENTID=\"@@@ADM_CLIENTID@@@\""                                          | tee -a "${CUR}/.env"
        echo "ADM_CLIENTSECRET=\"@@@ADM_CLIENTSECRET@@@\""                                  | tee -a "${CUR}/.env"
        echo "WEBPUSH_SUBJECT=\"@@@WEBPUSH_SUBJECT@@@\""                                    | tee -a "${CUR}/.env"

        if [[ -e "${CUR}/.env" ]]; then
            export $(cat "${CUR}/.env" | xargs)
        fi
    fi
    [[ -z `cat "${CUR}/key.p8"` ]]               && cat > ${CUR}/key.p8               @@@APNS_P8KEY@@@
    [[ -z `cat "${CUR}/service-account.json"` ]] && cat > ${CUR}/service-account.json @@@FCM_SERVICE_ACCOUNT@@@
}

: "run boltzengine install script" && {
    wget -q https://repository.boltzengine.fenrir-inc.com/scripts/sakura/boltzengine-centos7-stable.sh -O ${CUR}/install.sh
    source ${CUR}/install.sh
}
