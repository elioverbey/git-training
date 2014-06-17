<?php

$dir = dirname(__DIR__);

require_once("$dir/config/config.php");

$cli = "php-cli $dir/wp-cli.phar --path=$dir/web/wp";
$old_prefix = trim(file_get_contents("$dir/config/db_prefix"));
$dbname = $secrets['database_name'];

// Import backup database
exec("$cli db import $dir/database/backup.sql");

// Create a query to get all the tables that don't have the current prefix
file_put_contents('temp.sql', "SELECT CONCAT( 'DROP TABLE ', GROUP_CONCAT(table_name) , ';' )
	as statement
	FROM information_schema.tables 
    WHERE table_schema='$dbname' AND table_name NOT LIKE '${old_prefix}%';");
exec("$cli db query < temp.sql", $q);
file_put_contents('temp.sql', $q[1]);

// Drop the tables
exec("$cli db query < temp.sql");

// Clean up
unlink('temp.sql');