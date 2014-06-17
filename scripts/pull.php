<?php

defined('DS') or define('DS', DIRECTORY_SEPARATOR);

require_once('config/config.php');
require_once('config/environments.php');
require_once('config/remote.php');

$cli = "php-cli wp-cli.phar --path=web".DS."wp";

// Pull remote database
echo "Pulling remote database from $ssh_host...\n";
exec("ssh -l $ssh_user $ssh_host \"mysqldump --user=$mysql_user --password='$mysql_pw' $mysql_db\" > scripts".DS."pull.sql", $output);
foreach ($output as $line) echo "$line\n";

echo "Determing database prefix...";

// Read in file until we can find the table prefix
$file = @fopen('scripts'.DS.'pull.sql', "r") ;  
if ($file===false) die('Could not read pull.sql!');

$prefix = '';

// while there is another line to read in the file
while (!feof($file))
{
    // Get the current line that the file is reading
    $line = fgets($file);
    $match = preg_match('/CREATE TABLE `(.*)_.*`/', $line, $prefix);
    
    if ($match) {
    	$prefix = $prefix[1];
    	break;
    }
}

fclose($file);

// Die if we couldn't find the prefix
if (empty($prefix)) die('Couldn\'t determine prefix!');

echo "$prefix\n";

// Replace prefix
echo "Replacing prefix $prefix...\n";
exec("sed -i.bak 's/${prefix}_/FOTFPREFIX_/' scripts".DS."pull.sql", $output);
foreach ($output as $line) echo "$line\n";

// Import database
echo "Importing database...\n";
exec("$cli db import scripts".DS."pull.sql", $output);
foreach ($output as $line) echo "$line\n";

// Replace URLs
echo "Replacing prefix $prefix...\n";
exec("$cli search-replace \"${prefix}_\" \"FOTFPREFIX_\"", $output);
foreach ($output as $line) echo "$line\n";

echo "Replacing URLs...\n";
exec("$cli search-replace \"$ssh_host\" \"$deploy_url\"", $output);
foreach ($output as $line) echo "$line\n";

// Install Wordpress plugins/themes depending on environment
$dir = 'web'.DS.'app'.DS.'plugins'.DS;
$env = isset($environments[$deploy_environment]) ? $environments[$deploy_environment] : $environments['default'];
foreach (scandir($dir) as $plugin) {
	if (is_dir($dir . $plugin) && $plugin != '.' && $plugin != '..') {

		// Determine whether to activate the plugin
		$action = isset($env[$plugin]) ? $env[$plugin] : $action = $env['default'];
		exec("$cli plugin $action $plugin", $output);
        foreach ($output as $line) echo "$line\n";
	}
}

// Clean up
echo "Cleaning up...\n";
foreach (glob('scripts'.DS.'pull.sql*') as $filename) {
   unlink($filename);
}
