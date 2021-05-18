<?php
  $LoginName = "";
  $raw = file_get_contents('php://input');
  $domain = preg_replace('/^autoconfig\./','',$_SERVER['HTTP_HOST']);
  header('Content-Type: application/xml');
?>
<?xml version="1.0"?>
<clientConfig version="1.1">
  <emailProvider id="sacloud">
    <domain><?php echo $domain; ?></domain>
    <displayName><?php echo $domain; ?></displayName>
    <displayShortName><?php echo $domain; ?></displayShortName>
    <incomingServer type="imap">
       <username>%EMAILADDRESS%</username>
       <hostname><?php echo $domain; ?></hostname>
       <port>993</port>
       <socketType>SSL</socketType>
       <authentication>password-cleartext</authentication>
    </incomingServer>
    <incomingServer type="pop3">
       <username>%EMAILADDRESS%</username>
       <hostname><?php echo $domain; ?></hostname>
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
       <hostname><?php echo $domain; ?></hostname>
       <port>465</port>
       <socketType>SSL</socketType>
       <authentication>password-cleartext</authentication>
    </outgoingServer>
  </emailProvider>
  <clientConfigUpdate url="https://autoconfig.<?php echo $domain; ?>/.well-known/autoconfig/mail/config-v1.1.xml" />
</clientConfig>
