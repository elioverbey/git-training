<?php

// Set plugins to enable/disable based on environment
$environments = array(
	'production' => array (
		'wp-publish' => 'deactivate',
		'default' => 'activate'
	),
	'staging' => array (
		'w3-total-cache' => 'deactivate',
		'default' => 'activate'
	),
	'default' => array (
		'wp-publish' => 'deactivate',
		'w3-total-cache' => 'deactivate',
		'default' => 'activate'
	)
);