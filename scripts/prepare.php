<?php

defined('DS') or define('DS', DIRECTORY_SEPARATOR);

require_once('config'.DS.'config.php');

// Get args passed from command line
$message = str_replace('"', '\"', str_replace('\n', "\n", trim($argv[1])));
$version = trim($argv[2]);

$cli = "php-cli wp-cli.phar --path=web".DS."wp";

// Delete posts
echo "Deleting posts...\n";
exec("$cli post list --post_type=post", $output);
foreach ($output as $key=>$item) {
	$output[$key] = explode("\t", $item);
}

foreach ($output as $item) {
	$id = $item[0];
	if ($id!=='ID') {
		exec("$cli post delete \"$id\" --force", $output);
		foreach ($output as $line) echo "$line\n";
	}
}

// Delete orphan post_meta
echo "Cleaning post meta...\n";
file_put_contents('scripts'.DS.'temp.sql', "DELETE FROM `FOTFPREFIX_postmeta` WHERE `post_id` NOT IN (SELECT ID FROM `FOTFPREFIX_posts`)");
exec("$cli db query < scripts".DS."temp.sql", $output);
foreach ($output as $line) echo "$line\n";

// This sucks, but the best way I can think of to handle attachments is to use git
// to see what uploads are being tracked, and delete all attachments that aren't being 
// tracked. First we get an array of tracked uploads, then we loop through attachments
// and delete any that aren't in the tracked array.
echo "Getting tracked uploads...\n";
exec("git ls-files web".DS."app".DS."uploads", $tracked);

// Store the query to a file to get all attachments
file_put_contents('scripts'.DS.'temp.sql', "SELECT * FROM `FOTFPREFIX_posts` WHERE `post_type`='attachment';");

// Get all attachments
echo "Getting Wordpress attachments...\n";
exec("$cli db query < scripts".DS."temp.sql", $output);

// Convert to array
foreach ($output as $key=>$value)
	if (is_string($value))
		$output[$key] = explode("\t", $value);


// Loop through attachments
foreach ($output as $attachment) {
	if (isset($attachment[18])) {

		// Extract the relative path for the attachment
		$file = 'web'.substr($attachment[18], stripos($attachment[18], 'FOTF_SITE_URL')+13);
		
		// If the file is not being tracked, delete it from the database
		if (!in_array($file, $tracked)) {
			
			// Delete attachment
			$id = $attachment[0];
			if ($id!=='ID') {
				echo "Deleting attachment $id...\n";
				file_put_contents('scripts'.DS.'temp.sql', "DELETE FROM `FOTFPREFIX_posts` WHERE `ID`='$id';");
				exec("$cli db query < scripts".DS."temp.sql", $output);
				foreach ($output as $line) echo "$line\n";
			}
		}
	}
}

// Replace urls
echo "Updating URLs...\n";
exec("$cli search-replace \"$deploy_url\" \"FOTF_SITE_URL\"", $output);
foreach ($output as $line) echo "$line\n";

// Dump database
echo "Exporting database...\n";
exec("$cli db export database".DS."current.sql", $output);
foreach ($output as $line) echo "$line\n";

// Clean up
echo "Cleaning up...\n";
if (file_exists('scripts'.DS.'temp.sql'))
	unlink('scripts'.DS.'temp.sql');

// Git commit all and add version tag
if (!empty($message)) {

	exec("git add -A && git commit -m \"$message\"", $output);
	foreach ($output as $line) echo "$line\n";

	// Tag commit
	if (!empty($version)) {
		exec("git tag -a $version -m \"Version $version\"", $output);
		foreach ($output as $line) echo "$line\n";
	}

	// Git push
	exec("git push", $output);
	foreach ($output as $line) echo "$line\n";
}
