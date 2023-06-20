require 'json'
require 'yaml'
require 'fileutils'

phpYamlPath = File.expand_path("./vagrant.yml")
afterScriptPath = File.expand_path("./deployment/customize.sh")

require_relative 'deployment/setup.rb'

Vagrant.configure("2") do |config|
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
  Skeleton.configure(config, YAML::load(File.read(phpYamlPath)))

  if File.exists? afterScriptPath then
    config.vm.provision "shell", path: afterScriptPath
  end
end
