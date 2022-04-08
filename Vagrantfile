require 'json'
require 'yaml'

phpYamlPath = File.expand_path("./Vagrant.yml")
afterScriptPath = File.expand_path("./vagrant/customize.sh")

require_relative 'vagrant/setup.rb'

Vagrant.configure("2") do |config|
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
  Skeleton.configure(config, YAML::load(File.read(phpYamlPath)))

  if File.exists? afterScriptPath then
    config.vm.provision "shell", path: afterScriptPath
  end
end
