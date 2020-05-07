# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: certificates
#
# Copyright 2020, P. van der Velde
#

# Loop over all the certificate files and install them
# Taken from: https://serverfault.com/a/769155

# Get the Chef::CookbookVersion for this cookbook
log 'cookbook name' do
  message "Getting the cookbook collection for: #{cookbook_name}"
  level :info
end

cb = run_context.cookbook_collection[cookbook_name]

log "cookbook collection for #{cookbook_name}" do
  message "Found a collection with #{cb.files_for('files')&.length} files."
  level :info
end

# Loop over the array of files (use the & as a nil check)
cb.files_for('files')&.each do |cbf|
  # cbf['path'] is relative to the cookbook root, eg
  #   'files/default/foo.txt'
  # cbf['name'] strips the first two directories, eg
  #   'foo.txt'
  filepath = cbf['path']

  next unless filepath.include? '.crt'

  filename = File.basename(filepath)
  filename_without_extension = File.basename(filepath, '.crt')

  log "Processing #{filepath}" do
    message "Processing for path: #{filepath}; name: #{filename}; without extension: #{filename_without_extension}"
    level :info
  end

  trusted_certificate filename_without_extension do
    action :create
    content "cookbook_file://certificates/#{filename}"
  end
end
