def hgup_file
  return ::File.join(Chef::Config[:file_cache_path],"hgup")
end

def hg_connection_command
  case node['platform']
  when "windows"
    cmd = ""
  else
    key_param = new_resource.key.nil? ? "" : "-i #{new_resource.key}"
    cmd = "--ssh 'ssh #{key_param} -o StrictHostKeyChecking=no'"
  end
  return cmd
end
