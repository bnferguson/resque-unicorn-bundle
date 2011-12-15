# unicorn_rails -c /data/github/current/config/unicorn.rb -E production -D

rack_env = ENV['RACK_ENV'] || 'development'
app_name = "resque-web"
rack_root = (rack_env == "development" ? File.expand_path("../..", __FILE__) : "/www/#{app_name}" )


worker_processes (rack_env == 'production' ? 4 : 1)

# Load rails+github.git into the master before forking workers
# for super-fast worker spawn times
preload_app true

# Restart any workers that haven't responded in 30 seconds
timeout 30

stderr_path "log/unicorn-err.log"
stdout_path "log/unicorn-out.log"

# Listen on a Unix data socket
listen "/tmp/#{app_name}-#{rack_env}-unicorn.sock", :backlog => 2048

pid_dir = (rack_env == 'production' || rack_env == 'staging' ? "/var/run/unicorn" : "#{rack_root}/tmp")

pid "#{pid_dir}/#{app_name}-#{rack_env}-unicorn.pid"

##
# For REE and any copy on write compatible rubies.

# http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
if GC.respond_to?(:copy_on_write_friendly=)
  GC.copy_on_write_friendly = true
end


before_fork do |server, worker|
  ##
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.

  old_pid = "#{pid_dir}/#{app_name}-#{rack_env}-unicorn.pid.oldbin"

  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end


after_fork do |server, worker|
  port = 5000 + worker.nr

  child_pid = server.config[:pid].sub('.pid', ".#{port}.pid")
  system("echo #{Process.pid} > #{child_pid}")

  begin
    uid, gid = Process.euid, Process.egid
    user, group = 'root', 'root'
    target_uid = Etc.getpwnam(user).uid
    target_gid = Etc.getgrnam(group).gid
    worker.tmp.chown(target_uid, target_gid)
    if uid != target_uid || gid != target_gid
      Process.initgroups(user, target_gid)
      Process::GID.change_privilege(target_gid)
      Process::UID.change_privilege(target_uid)
    end
  rescue => e
    if rack_env == 'development'
      STDERR.puts "couldn't change user, oh well"
    else
      raise e
    end
  end
end




