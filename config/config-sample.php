<?php

$deploy_environment = 'development'; // development, testing, staging, production
$deploy_url = 'your_url'; // eg. mywordpress.com

$secrets['server_name'] = $deploy_url;
$secrets['prefix'] = 'FOTFPREFIX_';
if (file_exists('db_prefix'))
	$secrets['prefix'] = trim(file_get_contents('db_prefix'));
else if (defined('ABSPATH'))
	$secrets['prefix'] = trim(file_get_contents(ABSPATH.'../../config/db_prefix'));

// Gigya API key (get from gigya platform)
$secrets['gigya_api_key'] = '';
$secrets['gigya_secret_key'] = '';

// Obtain hashes from https://api.wordpress.org/secret-key/1.1/salt/
$secrets['auth_key'] = '';
$secrets['secure_auth_key'] = '';
$secrets['logged_in_key'] = '';
$secrets['nonce_key'] = '';
$secrets['auth_salt'] = '';
$secrets['secure_auth_salt'] = '';
$secrets['logged_in_salt'] = '';
$secrets['nonce_salt'] = '';


// Database credentials
$secrets['database_host'] = '127.0.0.1';
$secrets['database_name'] = 'database_name';
$secrets['database_user'] = 'database_username';
$secrets['database_pass'] = 'database_password';
