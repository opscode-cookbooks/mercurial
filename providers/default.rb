use_inline_resources

# Support whyrun
def whyrun_supported?
  true
end

action :clean do
  if !current_resource.exists
    Chef::Log.info "#{ new_resource } does not exists and therefore cannot be cleaned"
  elsif !current_resource.clean
    converge_by("Clean #{ @new_resource }") do
      clean
    end
  else
    Chef::Log.info "#{ new_resource } already clean - nothing to do."
  end
end

action :sync do
  if current_resource.synced and current_resource.updated
    Chef::Log.info "#{ new_resource } already synced - nothing to do."
  else
    sync_action
  end
end

action :clone do
  if current_resource.exists
    Chef::Log.info "#{ new_resource } already exists - nothing to do."
  else
    clone_action
  end
end

def clone_action
  converge_by("Clone #{ @new_resource }") do
    clone
  end
end

def clone
  execute "clone repository #{new_resource.path}" do
    command "hg clone #{hg_connection_command} #{new_resource.repository} #{new_resource.path}"
    user new_resource.owner
    group new_resource.group
  end
  update
end

def sync_action
  if current_resource.exists
    converge_by("Sync #{ @new_resource }") do
      sync
    end
  else
    clone_action
  end
end

def sync
  execute "pull #{new_resource.path}" do
    command "hg unbundle -u #{bundle_file}"
    user new_resource.owner
    group new_resource.group
    cwd new_resource.path
    only_if { ::File.exists?(bundle_file) || repo_incoming? }
    notifies :delete, "file[#{bundle_file}]"
  end
  update

  file bundle_file do
    action :nothing
  end
end

def update
  execute "hg update for #{new_resource.path}" do
    command "hg update --rev #{new_resource.reference}"
    user new_resource.owner
    group new_resource.group
    cwd new_resource.path
  end
end

def clean
  execute "hg clean purge for #{new_resource.path}" do
    command "hg status --no-status --unknown | xargs --no-run-if-empty rm"  # equivalent of purge extension
    user new_resource.owner
    group new_resource.group
    cwd new_resource.path
  end
  execute "hg clean revert for #{new_resource.path}" do
    command "hg revert --no-backup --all"
    user new_resource.owner
    group new_resource.group
    cwd new_resource.path
  end
  update
end

def load_current_resource
  init
  @current_resource = Chef::Resource::Mercurial.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.path(@new_resource.path)
  if repo_exists?
    @current_resource.exists = true
    @current_resource.synced = !repo_incoming?
    @current_resource.updated = repo_updated?
    @current_resource.clean = repo_clean?
  end
end

def repo_exists?
  command = Mixlib::ShellOut.new("hg identify #{new_resource.path}").run_command
  Chef::Log.debug "'hg identify #{new_resource.path}' return #{command.stdout}"
  return command.exitstatus == 0
end

def repo_incoming?
  cmd = "hg incoming #{hg_connection_command} --bundle #{bundle_file} #{new_resource.repository}"
  command = Mixlib::ShellOut.new(cmd, :cwd => new_resource.path, :user => new_resource.owner, :group => new_resource.group).run_command
  Chef::Log.debug "#{cmd} return #{command.stdout}"
  return command.exitstatus == 0
end

def repo_clean?
  cmd = "hg status"
  command = Mixlib::ShellOut.new(cmd, :cwd => new_resource.path).run_command
  Chef::Log.debug "#{cmd} return #{command.stdout}"
  return (command.exitstatus == 0 and command.stdout == "")
end

def repo_updated?
  cmd_current_revision = "hg parent --template '{node}'"
  command = Mixlib::ShellOut.new(cmd_current_revision, :cwd => new_resource.path).run_command
  Chef::Log.debug "#{cmd_current_revision} return #{command.stdout}"
  current_revision = command.stdout

  cmd_desired_revision = "hg log --rev #{new_resource.reference} --template '{node}'"
  command = Mixlib::ShellOut.new(cmd_desired_revision, :cwd => new_resource.path).run_command
  Chef::Log.debug "#{cmd_desired_revision} return #{command.stdout}"
  desired_revision = command.stdout

  return current_revision == desired_revision
end

def init
  directory tmp_directory do
    owner new_resource.owner
    group new_resource.group
    recursive true
    mode 0755
  end
end

def tmp_directory
  ::File.join(Chef::Config[:file_cache_path], "mercurial", sanitize_filename(new_resource.path))
end

def bundle_file
  ::File.join(tmp_directory, "bundle")
end

def sanitize_filename(filename)
  filename.gsub(/[^0-9A-z.\-]/, '_')
end
