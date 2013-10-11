use_inline_resources

action :sync do
  clone
  sync
end

action :clone do
  clone
end

def clone
  execute "clone repository #{new_resource.path}" do
    command "hg clone --rev #{new_resource.reference} #{hg_connection_command} #{new_resource.repository} #{new_resource.path}"
    user new_resource.owner
    group new_resource.group
    not_if "hg identify #{new_resource.path}"
  end
end

def sync
  execute "pull #{new_resource.path}" do
    command "hg unbundle #{bundle_file}"
    user new_resource.owner
    group new_resource.group
    cwd new_resource.path
    only_if "hg incoming --rev #{new_resource.reference} #{hg_connection_command} --bundle #{bundle_file} #{new_resource.repository}",
       :cwd => new_resource.path, 
       :user => new_resource.owner, 
       :group => new_resource.group
    notifies :run, "execute[update #{new_resource.path}]"
  end
  execute "update #{new_resource.path}" do
    command "hg update"
    user new_resource.owner
    group new_resource.group
    cwd new_resource.path
    action :nothing
  end
end

def bundle_file
  return ::File.join(Chef::Config[:file_cache_path], "mercurial.bundle")
end
