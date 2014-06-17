require 'mina/git'

# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :domain, 'www.yoursite.com'
set :deploy_to, '/path/to/the/site'
set :repository, 'git@github.com:focusonthefamily/yourrepo.git'
set :branch, 'master'

# Set git tag or commit from command line if it exists (eg. version=v1.0.0)
if !ENV['version'].nil?
  set :commit, ENV['version']
end

# Manually create these paths in shared/ in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, []

# Optional settings:
set :user, '-A YOUR_USERNAME'    # Username in the server to SSH to.
#   set :port, '30000'     # SSH port number.

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .rbenv-version to your repository.
  # invoke :'rbenv:load'

  # For those using RVM, use this to load an RVM version@gemset.
  # invoke :'rvm:use[ruby-1.9.3-p125@default]'
end

# Task to import current.sql locally
desc "Import current.sql locally"
task :import do
  system('php scripts/import.php')
end

# Task to pull remote database locally
desc "Pull remote database locally."
task :pull do
  system('php scripts/pull.php')
end

# Task to prepare for deployment (dump database, commit, tag, push)
desc "Prepare for deployment."
task :prepare => :environment do
  print "\nPlease enter a commit message: "
  msg = STDIN.gets.chomp.gsub('"', '\"')
  print "\nPlease enter a version number: "
  ver = STDIN.gets.chomp
  system('php scripts/prepare.php "'+msg+'" "'+ver+'"')
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task :setup => :environment do
  # queue! %[mkdir -p "#{deploy_to}/shared/web/app/uploads"]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    queue %[php composer.phar update]
    queue %[if [ -f "../../config.php" ]; then cp ../../config.php config; fi]
    queue %[php scripts/deploy.php]
    queue %[if [ ! -f "../../config.php" ]; then echo "---->Please create a config.php file!\n"; fi]
  end
end

desc "Rollback to previous verison."
task :rollback => :environment do
  queue %[echo "----> Start to rollback"]
  queue %[if [ $(ls #{deploy_to}/releases | wc -l) -gt 1 ]; then echo "---->Relink to previous release" && unlink #{deploy_to}/current && ln -s #{deploy_to}/releases/"$(ls #{deploy_to}/releases | tail -2 | head -1)" #{deploy_to}/current && echo "Remove old releases" && rm -rf #{deploy_to}/releases/"$(ls #{deploy_to}/releases | tail -1)" && echo "$(ls #{deploy_to}/releases | tail -1)" > #{deploy_to}/last_version && echo "Done. Rollback to v$(cat #{deploy_to}/last_version)" ; else echo "No more releases to rollback" ; fi]
  queue %[php #{deploy_to}/current/scripts/rollback.php]
end

# For help in making your deploy script, see the Mina documentation:
#
#  - http://nadarei.co/mina
#  - http://nadarei.co/mina/tasks
#  - http://nadarei.co/mina/settings
#  - http://nadarei.co/mina/helpers

