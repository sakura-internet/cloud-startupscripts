#!/bin/bash -ex

source $(dirname $0)/../config.source
echo "---- $0 ----"

#-- thunderbird 用 autoconfig を作成
mkdir -p ${HTTPS_DOCROOT}/.well-known/autoconfig/mail
chown -R nginx. ${HTTPS_DOCROOT}/.well-known

cat <<'_EOL_'>${HTTPS_DOCROOT}/.well-known/autoconfig/mail/config-v1.1.xml
<?xml version="1.0"?>
<clientConfig version="1.1">
    <emailProvider id="sakuravps">
      <domain>_DOMAIN_</domain>
      <displayName>_DOMAIN_</displayName>
      <displayShortName>_DOMAIN_</displayShortName>
      <incomingServer type="imap">
         <username>%EMAILADDRESS%</username>
         <hostname>_DOMAIN_</hostname>
         <port>993</port>
         <socketType>SSL</socketType>
         <authentication>password-cleartext</authentication>
      </incomingServer>
      <incomingServer type="pop3">
         <username>%EMAILADDRESS%</username>
         <hostname>_DOMAIN_</hostname>
         <port>995</port>
         <socketType>SSL</socketType>
         <authentication>password-cleartext</authentication>
         <pop3>
            <leaveMessagesOnServer>true</leaveMessagesOnServer>
            <downloadOnBiff>true</downloadOnBiff>
            <daysToLeaveMessagesOnServer>14</daysToLeaveMessagesOnServer>
         </pop3>
      </incomingServer>
      <outgoingServer type="smtp">
         <username>%EMAILADDRESS%</username>
         <hostname>_DOMAIN_</hostname>
         <port>465</port>
         <socketType>SSL</socketType>
         <authentication>password-cleartext</authentication>
      </outgoingServer>
    </emailProvider>
    <clientConfigUpdate url="https://_DOMAIN_/.well-known/autoconfig/mail/config-v1.1.xml" />
</clientConfig>
_EOL_

sed -i "s/_DOMAIN_/${FIRST_DOMAIN}/g" ${HTTPS_DOCROOT}/.well-known/autoconfig/mail/config-v1.1.xml

