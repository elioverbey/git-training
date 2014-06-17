<?php

// Post-mina-deploy script to do any additional work

include_once('config/environments.php');
include_once('config/config.php');

$filename = 'database/current.sql';
$cli = 'php-cli wp-cli.phar --path=web/wp';
$rollback_exists = file_exists('../../current/config/db_prefix');

// Backup old database
if ($rollback_exists)
	exec("php-cli wp-cli.phar --path=../../current/web/wp db export ../../current/database/backup.sql");

// Generate random prefix
$characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
$new_prefix = '';
for ($i = 0; $i < 6; $i++) {
    $new_prefix .= $characters[rand(0, strlen($characters) - 1)];
}
$new_prefix .= '_';

// Store the new prefix
file_put_contents('config/db_prefix', $new_prefix);

// Replace prefix in SQL file
exec("sed -i 's/FOTFPREFIX_/$new_prefix/' $filename");

// Import new database
exec("$cli db import $filename");

// Replace urls
exec("$cli search-replace 'FOTF_SITE_URL' '$deploy_url'");
exec("$cli search-replace 'FOTFPREFIX_' '$new_prefix'");

// Install Wordpress plugins/themes depending on environment
$dir = 'web/app/plugins/';
$env = isset($environments[$deploy_environment]) ? $environments[$deploy_environment] : $environments['default'];
foreach (scandir($dir) as $plugin) {
	if (is_dir($dir . $plugin) && $plugin != '.' && $plugin != '..') {

		// Determine whether to activate the plugin
		$action = isset($env[$plugin]) ? $env[$plugin] : $action = $env['default'];
		exec("$cli plugin install $plugin");
		exec("$cli plugin $action $plugin");
	}
}

if ($rollback_exists) {
	// Export content from old version
	echo "Exporting content...";
	exec("php-cli wp-cli.phar --path=../../current/web/wp export --post_type=post", $output);
	foreach ($output as $line)
		echo "$line\n";
	echo "Importing content...";
	exec("$cli import --authors=create `ls | grep .xml`", $output);
	foreach ($output as $line)
		echo "$line\n";
}

// Clean up (drop all tables without our prefix
$dbname = $secrets['database_name'];
file_put_contents('temp.sql', "SELECT CONCAT( 'DROP TABLE ', GROUP_CONCAT(table_name) , ';' )
	as statement
	FROM information_schema.tables 
    WHERE table_schema='$dbname' AND table_name NOT LIKE '${new_prefix}%';");
exec("$cli db query < temp.sql", $q);
file_put_contents('temp.sql', $q[1]);
exec("$cli db query < temp.sql");
unlink('temp.sql');
