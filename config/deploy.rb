# Colorize Capistrano output
require 'capistrano_colors'
# Pull in RVM's capistrano tasks, so the right Ruby version is used
require 'rvm/capistrano'
# Pull in bundler's capistrano tasks, so bundle installs happen
require 'bundler/capistrano'

# Uncomment if you are using Rails' asset pipeline
load 'deploy/assets'

# Setup multi-stage extension
set :stages, %w(production staging qa)
# Enable multi-stage deployments
# NOTE: this require statement MUST be below the :stages declaration above
require 'capistrano/ext/multistage'

# Set initial variables
set :application, 'scholarsphere'
set :scm, :git
set :git_enable_submodules, 1
set :repository,  "git://github.com/psu-stewardship/#{application}.git"
set :branch, 'release'
set :deploy_to, "/opt/heracles/#{application}/#{application}-current"
set :deploy_via, :remote_cache
set :deploy_env, 'production'
# Provide your server username via: cap -S username=abc123 ...
set :user, fetch(:username)
set :runner, 'tomcat'
set :admin_runner, runner
set :group, 'tomcat'
# Provide a tunnel host:port via: cap -S tunnel=host.example.com:2222 ...
set :gateway, fetch(:tunnel, "")
set :keep_releases, 5
set :rvm_type, :system

# Allow password prompts to work
default_run_options[:pty] = true
# Use user's privkey, not server key
ssh_options[:forward_agent] = true

# Run setup tasks before each deploy
before 'deploy', 'deploy:setup'
# Bootstrap RVM stuff before each deploy
#before 'deploy', 'rvm:install_rvm'
#before 'deploy', 'rvm:install_ruby'
#before 'deploy', 'rvm:create_gemset'
# Cleanup old releases
after 'deploy:restart', 'deploy:cleanup'
# Automatically run DB migrations
after 'deploy:update_code', 'deploy:migrate'

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  desc 'Start deployment'
  task :start do ; end
  desc 'Stop deployment'
  task :stop do ; end
  desc 'Restart deployment'
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

# Here for testing
desc 'Run uname and whoami on a host (for testing)'
task :whats_up do
  run 'whoami'
  run 'uname -a'
end
