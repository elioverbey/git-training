#!/bin/bash

# Force script to be run as root
# if [[ $EUID -ne 0 ]]; then
# 	echo "You must run this script as root!"
# 	exit 1
# fi

stage=$1
prod=$2
if [ "$stage" = "" ] || [ "$prod" = "" ]; then
	script=$(basename $0)
	echo "Usage: ${script} <path to stage> <path to prod>"
	exit 1
fi
if [ ! -e "$stage" ]; then
	echo "ERROR: Directory does not exist: $stage!"
	exit 1
fi
if [ ! -e "$prod" ]; then
	echo "ERROR: Directory does not exist: $prod!"
	exit 1
fi

v1=`ls -l ${prod}/current | awk '{print $11}' | xargs basename`
v2=$(($v1+1))
v0=$(($v1-1))

# Check for prod config.php first
if [ ! -e "${prod}/config.php" ]; then
	echo "ERROR: No config.php found!"
	exit 1
fi

# Dump stage database
if [ -f "${stage}/current/config/config.php" ]; then
	# Get current database credentials
	echo -n "Dumping stage database..."
	conf="${stage}/current/config/config.php"
	dbhost=`cat $conf | grep database_host | sed -E "s/.*'(.*)'.*/\1/g"`
	dbname=`cat $conf | grep database_name | sed -E "s/.*'(.*)'.*/\1/g"`
	dbuser=`cat $conf | grep database_user | sed -E "s/.*'(.*)'.*/\1/g"`
	dbpass=`cat $conf | grep database_pass | sed -E "s/.*'(.*)'.*/\1/g"`
	mysqldump --user="$dbuser" --password="$dbpass" --host="$dbhost" $dbname > "${stage}/current/database/push.sql"
	echo "done"

	# Backup prod database
	if [ -d "${prod}/current" ]; then
		
		echo -n "Backing up current database..."

		# Get current database credentials
		conf="${prod}/current/config/config.php"
		dbhost=`cat $conf | grep database_host | sed -E "s/.*'(.*)'.*/\1/g"`
		dbname=`cat $conf | grep database_name | sed -E "s/.*'(.*)'.*/\1/g"`
		dbuser=`cat $conf | grep database_user | sed -E "s/.*'(.*)'.*/\1/g"`
		dbpass=`cat $conf | grep database_pass | sed -E "s/.*'(.*)'.*/\1/g"`

		# Dump current database
		mysqldump --user="$dbuser" --password="$dbpass" --host="$dbhost" $dbname > "${prod}/current/backup.sql"

		echo "done"
	fi
else
	echo "ERROR: Unable to find stage config!"
	exit 1
fi

# Create new release directory
if [ -d "${prod}/releases" ]; then
	echo -n "Creating release directory $v2..."
	mkdir "${prod}/releases/$v2"
	echo "done"
else
	echo -n "Creating first release directory..."
	v='1'
	mkdir "${prod}/releases"
	mkdir "${prod}/releases/$v"
	echo "done"
fi

# Copy files to release directory
echo -n "Copying files..."
cp -r "${stage}/current/web" "${prod}/releases/$v2/"
cp -r "${stage}/current/config" "${prod}/releases/$v2/"
cp "${stage}/current/wp-cli.phar" "${prod}/releases/$v2/"
echo "done"

# Copy config.php, and robots.txt
if [ -f "${prod}/config.php" ]; then
	echo -n "Copying config.php..."
	cp -f "${prod}/config.php" "${prod}/releases/$v2/config/"
	echo "done"
else
	echo "WARNING: Unable to find config.php!"
fi
if [ -f "${prod}/robots.txt" ]; then
	echo -n "Copying robots.txt..."
	cp -f "${prod}/robots.txt" "${prod}/releases/$v2/web/"
	echo "done"
fi

# Import new database
echo -n "Updating database..."
conf="${prod}/releases/$v2/config/config.php"
dbhost=`cat $conf | grep database_host | sed -E "s/.*'(.*)'.*/\1/g"`
dbname=`cat $conf | grep database_name | sed -E "s/.*'(.*)'.*/\1/g"`
dbuser=`cat $conf | grep database_user | sed -E "s/.*'(.*)'.*/\1/g"`
dbpass=`cat $conf | grep database_pass | sed -E "s/.*'(.*)'.*/\1/g"`
mysql --user="$dbuser" --password="$dbpass" --host="$dbhost" $dbname < "${stage}/current/database/push.sql"
echo "done"

# Update URLs in database
echo -n "Updating URLs..."
host2=`cat $conf | grep deploy_url | head -n 1 | sed -E "s/.*'(.*)'.*/\1/g"`
conf="${stage}/current/config/config.php"
host1=`cat $conf | grep deploy_url | head -n 1 | sed -E "s/.*'(.*)'.*/\1/g"`
cd "${prod}/releases/$v2"
php-cli wp-cli.phar --path=web/wp search-replace $host1 $host2
echo "done"

# Get salts and keys
echo -n "Fetching new salts and keys..."
salts=`curl https://api.wordpress.org/secret-key/1.1/salt/`

# Parse salts and keys
nonce_salt=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`
salts=`echo $salts | sed -E "s/(.*;) define.*;/\1/g"`
logged_in_salt=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`
salts=`echo $salts | sed -E "s/(.*;) define.*;/\1/g"`
secure_auth_salt=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`
salts=`echo $salts | sed -E "s/(.*;) define.*;/\1/g"`
auth_salt=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`
salts=`echo $salts | sed -E "s/(.*;) define.*;/\1/g"`
nonce_key=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`
salts=`echo $salts | sed -E "s/(.*;) define.*;/\1/g"`
logged_in_key=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`
salts=`echo $salts | sed -E "s/(.*;) define.*;/\1/g"`
secure_auth_key=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`
salts=`echo $salts | sed -E "s/(.*;) define.*;/\1/g"`
auth_key=`echo $salts | sed -E "s/.*'(.*)'.*/\1/g" | sed -E 's/([\/&])/\\\\\1/g'`

# Update salts and keys
conf="${prod}/releases/$v2/config/config.php"
find=`grep "'auth_key'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${auth_key}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'auth_key'.*/${replace}/" $conf

find=`grep "'secure_auth_key'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${secure_auth_key}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'secure_auth_key'.*/${replace}/" $conf

find=`grep "'logged_in_key'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${logged_in_key}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'logged_in_key'.*/${replace}/" $conf

find=`grep "'nonce_key'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${nonce_key}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'nonce_key'.*/${replace}/" $conf

find=`grep "'auth_salt'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${auth_salt}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'auth_salt'.*/${replace}/" $conf

find=`grep "'secure_auth_salt'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${secure_auth_salt}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'secure_auth_salt'.*/${replace}/" $conf

find=`grep "'logged_in_salt'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${logged_in_salt}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'logged_in_salt'.*/${replace}/" $conf

find=`grep "'nonce_salt'" $conf`
replace=`echo $find | sed -E "s/(.*').*('.*)/\1${nonce_salt}\2/g" | sed -E 's/([\/&])/\\\\\1/g'`
sed -i.bak -E "s/.*'nonce_salt'.*/${replace}/" $conf
echo "done"

# Update plugins
env=${prod}/releases/$v2/config/environments.php
# Get the default action
default=$(sed -e '/production/,/)/!d' $env | grep default | sed -E "s/.*'(.*)'.*/\1/")
# Get list of plugins
plugins=($(ls -d ${prod}/releases/$v2/web/app/plugins/*/ | xargs -n1 basename))
for plugin in "${plugins[@]}"
do
	echo $plugin
	# Get specific action, falling back to default
	action=$(sed -e '/production/,/)/!d' $env | grep ${plugin} | sed -E "s/.*'(.*)'.*/\1/")
	if [ "$action" = "" ]; then action=$default; fi
	# Perform action
	cd "${prod}/releases/$v2"
	php-cli wp-cli.phar --path=web/wp plugin ${action} ${plugin}
done

# Copy htaccess
if [ -f "${prod}/htaccess.txt" ]; then
	echo -n "Copying .htaccess..."
	cp -f "${prod}/htaccess.txt" "${prod}/releases/$v2/web/.htaccess"
	echo "done"
fi

# Optimize images
echo "Optimizing images ..."
cd ${prod}/releases/$v2/web/app
find uploads -name *.jpg -o -name *.jpeg | xargs /usr/local/bin/jpegoptim -ot

# Update symlink
echo -n "Updating symlink..."
rm "${prod}/current"
ln -s "${prod}/releases/$v2" "${prod}/current"
echo "done"

# Clean up database (drop all tables without our prefix)
echo -n "Cleaning database..."
cd "${prod}/releases/$v2"
prefix=`cat config/db_prefix`
echo "SELECT CONCAT( 'DROP TABLE ', GROUP_CONCAT(table_name) , ';' )
	as statement
	FROM information_schema.tables 
    WHERE table_schema='$dbname' AND table_name NOT LIKE '${prefix}%';" > temp.sql
php-cli wp-cli.phar --path=web/wp db query < temp.sql | grep DROP > temp2.sql
php-cli wp-cli.phar --path=web/wp db query < temp2.sql
rm temp.sql temp2.sql
echo "done"

# Set permissions
echo -n "Updating permissions..."
chmod -R a-w "${prod}/releases/$v2/web"
chmod u+w "${prod}/releases/$v2/web/.htaccess"
chmod u+w "${prod}/releases/$v2/web/wp-config.php"
chmod u+w "${prod}/releases/$v2/web/app"
chmod -R u+w "${prod}/releases/$v2/web/app/cache"
chmod u+w "${prod}/releases/$v2/web/app/plugins"
chmod u+w "${prod}/releases/$v2/web/app/plugins/w3tc-wp-loader.php"
chmod u+w "${prod}/releases/$v2/web/app/uploads"
echo "done"

echo "Successfully deployed release $v2!"
