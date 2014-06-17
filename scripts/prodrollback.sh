#!/bin/bash

# Force script to be run as root
# if [[ $EUID -ne 0 ]]; then
# 	echo "You must run this script as root!"
# 	exit 1
# fi

prod=$1
if [ "$prod" = "" ]; then
	script=$(basename $0)
	echo "Usage: ${script} <path to prod>"
	exit 1
fi

if [ ! -e "$prod" ]; then
	echo "ERROR: Directory does not exist: $prod!"
	exit 1
fi

v1=`ls -lv ${prod}/current | awk '{print $11}' | xargs basename`
v0=$(($v1-1))

if [ ! -e "${prod}/current" ]; then
	echo "Nothing to roll back"
	exit 1
fi

# Determine previous version
if [ "$v1" -eq "1" ]; then
	echo "WARNING: No more versions to rollback!"
else
	
	echo "Starting rollback"

	# Update symlink
	echo -n "Updating symlink..."
	rm "${prod}/current"
	ln -sf "${prod}/releases/$v0" "${prod}/current"
	echo "done"

	# Import database
	echo -n "Importing database..."
	conf="${prod}/current/config/config.php"
	dbhost=`cat $conf | grep database_host | sed -E "s/.*'(.*)'.*/\1/g"`
	dbname=`cat $conf | grep database_name | sed -E "s/.*'(.*)'.*/\1/g"`
	dbuser=`cat $conf | grep database_user | sed -E "s/.*'(.*)'.*/\1/g"`
	dbpass=`cat $conf | grep database_pass | sed -E "s/.*'(.*)'.*/\1/g"`
	mysql --user="$dbuser" --password="$dbpass" --host="$dbhost" $dbname < "${prod}/current/backup.sql" # TODO: Update db path
	echo "done"

	# Clean up
	echo -n "Cleaning up..."
	chmod -R u+w "${prod}/releases/$v1/web"
	rm -rf "${prod}/releases/$v1"
	echo "done"

	echo "Successfully rolled back to version $v0!"
fi