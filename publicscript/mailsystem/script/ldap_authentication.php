<?php

// how to install
// # yum install php-devel php-ldap

error_reporting(0);

// write syslog
function _writelog($message) {
	openlog("nginx-mail-proxy", LOG_PID, LOG_MAIL);
	syslog(LOG_INFO,"$message") ;
	closelog();
}

// ldap authentication
function _ldapauth($server,$port,$dn,$passwd) {
	$conn = ldap_connect($server, $port);
	if ($conn) {
		ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
		$bind = ldap_bind($conn, $dn, $passwd);
		if ($bind) {
			ldap_close($conn);
			return True;
		} else {
			ldap_close($conn);
			return False;
		}
	} else {
		return False;
	}
}

function _mail_proxy($server,$port,$base,$filter,$attribute,$proxyport) {
	$message = "" ;
	$proxyhost = _ldapsearch($server,$port,$base,$filter,$attribute);

	if ( $proxyhost === '' ) {
		// proxyhost is not found
		$message = "proxy=failure" ;
		header('Content-type: text/html');
		header('Auth-Status: Invalid login') ;
	} else {
		// proxyhost is found
		$proxyip = gethostbyname($proxyhost);

		$message = sprintf('proxy=%s:%s', $proxyhost, $proxyport );
		header('Content-type: text/html');
		header('Auth-Status: OK') ;
		header("Auth-Server: $proxyip") ;
		header("Auth-Port: $proxyport") ;
	}
	return $message ;
}

// ldap search
function _ldapsearch($server,$port,$base,$filter,$attribute) {

	$conn = ldap_connect($server, $port);
	if ($conn) {
		ldap_set_option($conn, LDAP_OPT_PROTOCOL_VERSION, 3);
		$sresult = ldap_search($conn, $base, $filter, array($attribute));
		$info = ldap_get_entries($conn, $sresult);
		if ( $info[0][$attribute][0] != "" ) {
			return $info[0][$attribute][0];
		}
	}
	return "" ;
}

// set $env from nginx
$env['meth']    = getenv('HTTP_AUTH_METHOD');
$env['user']    = getenv('HTTP_AUTH_USER');
$env['passwd']  = getenv('HTTP_AUTH_PASS');
$env['salt']    = getenv('HTTP_AUTH_SALT');
$env['proto']   = getenv('HTTP_AUTH_PROTOCOL');
$env['attempt'] = getenv('HTTP_AUTH_LOGIN_ATTEMPT');
$env['client']  = getenv('HTTP_CLIENT_IP');
$env['host']    = getenv('HTTP_CLIENT_HOST');
$env['port']    = getenv('HTTP_PORT');
$env['helo']    = getenv('HTTP_AUTH_SMTP_HELO');
$env['from']    = getenv('HTTP_AUTH_SMTP_FROM');
$env['to']      = getenv('HTTP_AUTH_SMTP_TO');

$log = "" ;

// protocol port map
$portmap = array(
	"smtp" => 25,
	"pop3" => 110,
	"imap" => 143,
);

// port searvice name map
$protomap = array(
	"995" => "pops",
	"993" => "imaps",
	"110" => "pop",
	"143" => "imap",
	"587" => "smtp",
	"465" => "smtps",
);

// ldap setting
$ldap = array(
	"host" => "_LDAP_SERVER_",
	"port" => 389,
	"basedn" => "",
	"filter" => "(&(mailRoutingAddress=" . $env['user'] . "))",
	"attribute" => "mailhost",
	"dn" => "",
	"passwd" => "",
);

// split uid and domain
$spmra = preg_split('/\@/', $env['user']) ;

// make dn
foreach (preg_split("/\./", $spmra[1]) as $value) {
        $ldap['dn'] = $ldap['dn'] . 'dc=' . $value . ',' ;
}
$tmpdn = preg_split('/,$/',$ldap['dn']);
$ldap['dn'] = 'uid=' . $spmra[0] . ',ou=People,' . $tmpdn[0];

// set search attribute
if ( $env['proto'] === 'smtp' ) {
	$ldap['attribute'] = 'sendmailmtahost' ;
}

// set log
$log = sprintf('meth=%s, user=%s, client=%s, proto=%s', $env['meth'], $env['user'], $env['client'], $protomap[$env['port']]);

// set password
$ldap['passwd'] = urldecode($env['passwd']) ;

// ldap authentication
if ( _ldapauth($ldap['host'],$ldap['port'],$ldap['dn'],$ldap['passwd'])) {
	// authentication successful
	$log = sprintf ('auth=successful, %s', $log) ;
	$proxyport = $portmap[$env['proto']];
	$result = _mail_proxy($ldap['host'],$ldap['port'],$ldap['basedn'],$ldap['filter'],$ldap['attribute'],$proxyport);
	$log = sprintf ('%s, %s', $log,$result) ;
} else {
	// authentication failure
	// $log = sprintf('auth=failure, %s, passwd=%s', $log, $ldap['passwd']);
	$log = sprintf('auth=failure, %s', $log);
	header('Content-type: text/html');
	header('Auth-Status: Invalid login') ;
}

_writelog($log);
exit;
?>
