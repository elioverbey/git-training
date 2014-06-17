# FOTF Wordpress

FOTF Wordpress is a Wordpress quickstarter that uses composer for dependencies and mina for deployment. Since the application is primarily PHP, many of the deployment scripts called by mina are written in PHP as well.


## Requirements

- Apache
- MySQL
- PHP 5.3+
- Composer (https://getcomposer.org)
- Mina (http://nadarei.co/mina/)
- jpegoptim (on the server only)

## Wordpress Setup

- Delete the .git directory (it's hidden, you may need to run `rm -rf .git` from terminal)
- Run `git init` in your new directory, or use a git GUI to create a repo in your directory
- Copy config/config-sample.php to config/config.php and customize:
	- `deploy_environment`
	- `deploy_url`
	- All of the `keys` and `salts`
	- `database_host`
	- `database_name`
	- `database_user`
	- `database_pass`
- Edit composer.json
	- Change the Wordpress version to your desired version (3 places to change it)
	- Add any wordpress plugins
- Run `composer install`
- Install Wordpress
- Run `mina prepare` to save your initial database schema
- If you didn't commit your changes in the previous step, do so now
- You are now ready to customize Wordpress!

For salts, you can use the following RegEx (in Sublime at least) to convert from WP format to our config format:
- Find: `define\('(.*?)'.*?'(.*)'\)`
- Replace: `$secrets['\L\1'] = '$2'`

## Deployment Setup

- Edit config/deploy.rb and configure
	- `domain`: the deployment server's domain name
	- `deploy_to`: the absolute path to the deployment directory on the server
	- `repository`: link to the repository for the site
	- `user`: SSH username for the deployment server (must be "-A username" to enable Agent Forwarding)
- Copy config/remote-sample.php to config/remote.php and customize

## Agent Forwarding

For deployment, you'll need to set up SSH keys with agent forwarding. 

- Generating SSH Keys: https://help.github.com/articles/generating-ssh-keys
- Agent forwarding: https://help.github.com/articles/using-ssh-agent-forwarding

## Tasks

### Setup New Server

Mina will automatically set up a deployment directory structure on the server by running `mina setup`.

### Prepare For Deployment

After making changes locally, you'll need to prepare for deployment which takes care exporting your database, versioning your changes, and pushing your changes to GitHub. 

`mina prepare`

You'll be prompted for a commit message -- just make a note about the changes you made. You'll also be prompted for a version which should be in the format `v1.0.0`. If the change was very small, increment the last digit such as `v1.0.1`, if the change included some new features or goals for the site, you may want to bump the version to something like `v1.1.0`, and if the changes were drastic, you should bump to `v2.0.0`. 

### Deploy

`mina deploy` will push all of your changes to the server and update the environment. After running `mina deploy`, you'll need to run `mina import` to reset your local installation. 

### Rollback

Run `mina rollback` to undo the latest deployment and revert to the previous version

### Import

`mina import` will import the latest database that you have locally (database/current.sql) and configure for your environment

### Pull

`mina pull` will pull down the remote database (config in config/remote.php) so you can stay up-to-date with the live site.

## Server Setup

### Environments

Every environment can have the following customized files which must be placed in the root site directory for each environment:

- `config.php` (**required**): copy config/config-sample.php and customize for each environment
- `.htaccess` (**optional**): for production, configure the plugins (such as cache) as desired, then copy the .htaccess file from /web/ into the root site directory
- `robots.txt` (**optional**): robots.txt should disallow access to all environments except prod

### Production

Every environment except production uses mina for deployment. Production is an identical copy of the files and database of staging with tighter permissions for security. There is a separate deployment script that works in conjunction with a Wordpress plugin (WP Publish) to publish the staging environment to production. The process works as follows:

1. The "publish" button is clicked within Wordpress which writes a "1" to the "publish" file in the root web directory of staging
2. A cron job running every minute runs the scripts/checkpublish.sh script and appends the output to the publish.log file in the root directory of the production site
3. If the checkpublish.sh script detects a "1" in the "publish" file, it sets the "publish" file to "0" and executes the proddeploy.sh script 
4. The proddeploy.sh script essentially does what mina deploy does with a few additional steps such as setting tighter permissions and optimizing images

Sample cron job: 

`* * * * *       /home/jdfotf/public_html/stagejimdaly.focusonthefamily.com/current/scripts/checkpublish.sh /home/jdfotf/public_html/jimdaly.focusonthefamily.com >> /home/jdfotf/public_html/jimdaly.focusonthefamily.com/publish.log`

* Note that prodrollback.sh must be run manually from the server in case of emergencies

## Gotchas

There are a few things that are helpful to know about the development/deployment process:

- **ALWAYS** `git pull` before making changes to avoid any conflicts
- **ALWAYS** `cd` into your site folder before running any `mina` tasks
- **ALWAYS** check if a Wordpress plugin is available for free from https://wordpress.org/plugins. If it is, you should add the package definition to composer.json and run `php composer.phar update` which will automatically download and install the plugin for you. Don't forget to configure environments.php for the plugin!
- If a plugin isn't available from https://wordpress.org/plugins or you purchased a plugin, you can manually install it, but be sure to add it to .gitignore (see .gitignore for syntax) so that it gets tracked
- `mina prepare` is only required if you make database changes (install/configure anything in Wordpress, update widgets, update content, etc.)
- `mina deploy` is simply a controller for deployment -- nothing is transferred from your local environment. In fact, you could run `mina deploy` without even having a local site set up, as long as the scripts are in place
- You can use `ssh-add -K ~/.ssh/id_rsa` to permanently add your key 
- If you want to track anything in the uploads folder, you must add it to .gitignore (see .gitignore for syntax and examples)
