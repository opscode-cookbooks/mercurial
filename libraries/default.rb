def hgup_file
  return ::File.join(Chef::Config[:file_cache_path],"hgup")
end
