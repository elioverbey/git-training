<?php

defined('DS') or define('DS', DIRECTORY_SEPARATOR);

require_once('config'.DS.'config.php');
require_once('config'.DS.'environments.php');

$cli = "php-cli wp-cli.phar --path=web".DS."wp";

// Import the database
echo "Importing database".DS."current.sql...\n";
exec("$cli db import database".DS."current.sql", $output);
foreach ($output as $line) echo "$line\n";

// Replace URLs
echo "Updating URLs...\n";
exec("$cli search-replace \"FOTF_SITE_URL\" \"$deploy_url\"", $output);
foreach ($output as $line) echo "$line\n";

// Install Wordpress plugins/themes depending on environment
$dir = 'web'.DS.'app'.DS.'plugins'.DS;
$env = isset($environments[$deploy_environment]) ? $environments[$deploy_environment] : $environments['default'];
foreach (scandir($dir) as $plugin) {
	if (is_dir($dir . $plugin) && $plugin != '.' && $plugin != '..') {

		// Determine whether to activate the plugin
		$action = isset($env[$plugin]) ? $env[$plugin] : $action = $env['default'];
		exec("$cli plugin $action $plugin", $ouptut);
		foreach ($output as $line) echo "$line\n";
	}
}