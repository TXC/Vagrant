class Skeleton
  @scriptDir = ''
  @hostIP = ''
  @defaultPhp = '8.2'
  @stubDir = '/vagrant/deployment/stubs'
  @features = Hash.new
  @phpVersions = Array.new

  def Skeleton.configure(config, settings)
    # Set The VM Provider
    if settings.has_key?('provider')
      ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider']
    elsif !ENV.has_key?('VAGRANT_DEFAULT_PROVIDER')
      ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] ||= 'virtualbox'
    end

    @scriptDir = File.dirname(__FILE__)
    
    # Configure The Box
    config.vm.box = settings['box'] ||= 'generic/ubuntu2004'
    config.vm.hostname = settings['hostname'] ||= 'vagrant.local'

    # Allow SSH Agent Forward from The Box
    config.ssh.forward_agent = true

    # Configure Verify Host Key
    if settings.has_key?('verify_host_key')
      config.ssh.verify_host_key = settings['verify_host_key']
    end

    # Override Default SSH port on the host
    if settings.has_key?('default_ssh_port')
      config.vm.network :forwarded_port,
        guest: 22,
        host: settings['default_ssh_port'],
        auto_correct: false,
        id: "ssh"
    end

    # Configure A Private Network IP
    if settings['ip'] != 'autonetwork'
      config.vm.network :private_network,
        ip: settings['ip'] ||= '192.168.234.234'
    else
      config.vm.network :private_network,
        ip: '0.0.0.0',
        auto_network: true
    end

    # Configure Additional Networks
    if settings.has_key?('networking')
      settings['networking'].each do |network|
        config.vm.network network['type'], 
          ip: network['ip'],
          mac: network['mac'],
          bridge: network['bridge'] ||= nil,
          netmask: network['netmask'] ||= '255.255.255.0'
      end
    end

    self.configureHyperVisor(config, settings)

    # Configure Port Forwarding To The Box
    # Add Custom Ports From Configuration
    if settings.key?("ports")
      settings["ports"].each do |port|
        config.vm.network "forwarded_port",
          guest: port["guest"],
          host: port["host"],
          protocol: port["protocol"] ||= "tcp"
      end
    end

    self.mountFolders(config, settings)
    self.configFile(config, settings)
    self.setupBox(config, settings)
    self.deploySites(config, settings)
    self.setupHosts(config, settings)
    self.setupSSH(config, settings)
    self.setupDatabase(config, settings)
    self.fixSystem(config, settings)


    config.trigger.before :destroy,
      name: "Backup",
      info: "Backing up...",
      run_remote: {
        name: "Backing up...",
        privileged: true,
        path: "./deployment/backup.sh"
      }

    if Vagrant::Util::Platform::darwin?
      config.trigger.after :up do |t|
        filename = "./ssl.trust.sh"
        t.name = "SSL Trust"
        t.info = "Applying trust for box generated SSL"
        Skeleton.trustSSL(config, settings, filename)
        t.run = {inline: "bash -c #{filename}"}
        #File.delete(filename)
      end

      config.trigger.before :destroy do |t|
        filename = "./ssl.untrust.sh"
        t.name = "SSL Untrust"
        t.info = "Removing trust for box generated SSL"
        Skeleton.untrustSSL(config, settings, filename)
        t.run = {inline: "bash -c #{filename}"}
        #File.delete(filename)
      end
    end
  end

  def self.getHostIp(settings)
    if @hostIP.empty?
      hostIP = settings["ip"].split(".");
      hostIP.pop
      hostIP.push(1)
      @hostIP = hostIP.join(".")
    end

    return @hostIP
  end

  def self.getDomains(settings)
    domains = []

    settings["sites"].each do |site|
      domains.append(site["hostname"])
    end

    return domains
  end

  def self.configureHyperVisor(config, settings)

    host = RbConfig::CONFIG['host_os']
    # Give VM 1/4 system memory & access to all cpu cores on the host
    if host =~ /darwin/
      cpus = `sysctl -n hw.ncpu`.to_i
      # sysctl returns Bytes and we need to convert to MB
      mem = `sysctl -n hw.memsize`.to_i / 1024 / 1024 / 4
    elsif host =~ /linux/
      cpus = `nproc`.to_i
      # meminfo shows KB and we need to convert to MB
      mem = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024 / 4
    else # sorry Windows folks, I can't help you
      cpus = 2
      mem = 2048
    end

    if mem < 2048
      mem = 2048
    end

    # Configure A Few VMware Settings
    ['vmware_fusion', 'vmware_workstation', 'vmware_player', 'vmware_desktop'].each do |vmware|
      config.vm.provider vmware do |v|
        v.vmx['displayName'] = settings['name'] ||= 'vagrant'
        v.vmx['memsize'] = settings['memory'] ||= mem
        v.vmx['numvcpus'] = settings['cpus'] ||= cpus
        v.vmx['guestOS'] = 'ubuntu-64'
        if settings.has_key?('gui') && settings['gui']
          v.gui = true
        end
      end
    end

    # Configure A Few VirtualBox Settings
    config.vm.provider "virtualbox" do |vb|
      vb.name = settings['name'] ||= 'vagrant'
      vb.customize ['modifyvm', :id, '--memory', settings['memory'] ||= mem]
      vb.customize ['modifyvm', :id, '--cpus', settings['cpus'] ||= cpus]
      vb.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
      vb.customize ['modifyvm', :id, '--natdnshostresolver1', settings['natdnshostresolver'] ||= 'on']
      vb.customize ['modifyvm', :id, '--ostype', 'Ubuntu_64']

      if settings.has_key?('gui') && settings['gui']
        vb.gui = true
      end
      # --paravirtprovider none|default|legacy|minimal|hyperv|kvm
      # Specifies which paravirtualization interface to provide to
      # the guest operating system.
      if settings.has_key?('paravirtprovider') && settings['paravirtprovider']
        vb.customize ['modifyvm', :id, '--paravirtprovider', settings['paravirtprovider'] ||= 'kvm']
      end
      
      if Vagrant::Util::Platform.windows?
        vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
      end
    end

    # Configure A Few Hyper-V Settings
    config.vm.provider "hyperv" do |h, override|
      h.vmname = settings['name'] ||= 'vagrant'
      h.memory = settings['memory'] ||= mem
      h.cpus = settings['cpus'] ||= cpus
      h.linked_clone = true
      if settings.has_key?('hyperv_mac') && settings['hyperv_mac']
        h.mac = settings['hyperv_mac']
      end
      if settings.has_key?('hyperv_maxmemory') && settings['hyperv_maxmemory']
        h.maxmemory = settings['hyperv_maxmemory']
      end
      if settings.has_key?('hyperv_enable_virtualization_extensions') && settings['hyperv_enable_virtualization_extensions']
        h.enable_virtualization_extensions = true
      end

      if Vagrant.has_plugin?('vagrant-hostmanager')
        override.hostmanager.ignore_private_ip = true
      end
    end

    # Configure A Few Parallels Settings
    config.vm.provider 'parallels' do |v|
      v.name = settings['name'] ||= 'vagrant'
      v.update_guest_tools = settings['update_parallels_tools'] ||= false
      v.memory = settings['memory'] ||= mem
      v.cpus = settings['cpus'] ||= cpus
    end

    # Configure libvirt settings
    config.vm.provider "libvirt" do |libvirt|
      libvirt.default_prefix = ''
      libvirt.memory = settings["memory"] ||= mem
      libvirt.cpu_model = settings["cpus"] ||= cpus
      libvirt.nested = "true"
      libvirt.disk_bus = "virtio"
      libvirt.machine_type = "q35"
      libvirt.disk_driver :cache => "none"
      libvirt.memorybacking :access, :mode => 'shared'
      libvirt.nic_model_type = "virtio"
      libvirt.driver = "kvm"
      libvirt.qemu_use_session = false
    end
  end

  def self.mountFolders(config, settings)
    # Register All Of The Configured Shared Folders
    if settings.include? 'folders'

      found = false
      settings['folders'].each do |folder|
        if folder['to'] == '/vagrant'
          found = true
          break
        end
      end
      if found == false
        settings['folders'].push({'map' => './', 'to' => '/vagrant'})
      end

      settings['folders'].each do |folder|
        if !File.exist? File.expand_path(folder['map'])
          config.vm.provision 'shell', inline: ">&2 echo \"Unable to mount '" + folder['map'] + "'. Please check your folders in Vagrant.yml\""
          break
        end

        mount_opts = []

        if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'hyperv'
          folder['type'] = 'smb'
        end
        if ENV['VAGRANT_DEFAULT_PROVIDER'] == 'libvirt'
          folder['type'] ||= 'virtiofs'
        end

        if folder['type'] == 'nfs'
          mount_opts = folder['mount_options'] ? folder['mount_options'] : ['actimeo=1', 'nolock']
        elsif folder['type'] == 'smb'
          mount_opts = folder['mount_options'] ? folder['mount_options'] : ['vers=3.02', 'mfsymlinks']

          smb_creds = {
            smb_host: folder['smb_host'],
            smb_username: folder['smb_username'],
            smb_password: folder['smb_password']
          }
        end

        # For b/w compatibility keep separate 'mount_opts', but merge with options
        options = (folder['options'] || {}).merge({ mount_options: mount_opts }).merge(smb_creds || {})

        # Double-splat (**) operator only works with symbol keys, so convert
        options.keys.each do |k|
          options[k.to_sym] = options.delete(k)
        end

        config.vm.synced_folder folder['map'],
                                folder['to'],
                                type: folder['type'] ||= nil,
                                **options

        # Bindfs support to fix shared folder (NFS) permission issue on Mac
        if folder['type'] == 'nfs' && Vagrant.has_plugin?('vagrant-bindfs')
          config.bindfs.bind_folder folder['to'],
                                    folder['to']
        end
      end
    end
  end

  def self.getFeatureSet(config, settings)
    if @features.empty?
      settings['features'].each do |feature|
        feature_name = feature.keys[0]
        feature_variables = feature[feature_name]

        # Check for boolean parameters
        # Compares against true/false to show that it really means "<feature>: <boolean>"
        if feature_variables == false
          config.vm.provision "shell", inline: "echo Ignoring feature: '#{feature_name}' because it is set to false\n"
          next
        elsif feature_variables == true
          # If feature_arguments is true, set it to empty, so it could be passed to script without problem
          feature_variables = {}
        end

        featureMap = {
          "name" => feature_name,
          "variables" => feature_variables
        }

        featureFile = @scriptDir + "/features/" + feature_name + ".sh"
        # Check if feature really exists
        if !File.exist? File.expand_path(featureFile)
          config.vm.provision "shell", inline: "echo Invalid feature: '#{feature_name}' \n"
          next
        else
          featureMap.store("path", File.expand_path(featureFile))
        end

        featureStub = @scriptDir + "/stubs/" + feature_name
        if File.exist? File.expand_path(featureStub) then
          featureMap.store("stub", {
            "local" => File.expand_path(featureStub),
            "remote" => @stubDir + "/" + feature_name
          })
        end

        @features.store(feature_name, featureMap)
      end
    end
    return @features
  end

  def self.phpFeatures(settings)
    if @phpVersions.empty?
      @phpVersions = [
        "5.6",
        "7.0", "7.1", "7.2", "7.3", "7.4",
        "8.0", "8.1", "8.2", "8.3"
      ]

      if settings.key?("php") && settings['sites'].kind_of?(Array)
        settings["sites"].each do |site|
          phpVersion = site["php"] ||= "8.2"
          unless settings["php"].include?(phpVersion)
            settings["php"].push(phpVersion)
          end
        end
      end

      if settings.key?("php")
        @phpVersions = []
        settings["php"].each do |php|
          @phpVersions.push(php)
        end
      end
    end
    return @phpVersions
  end

  def self.configFile(config, settings)
    features = self.getFeatureSet(config, settings)
    phpVersions = self.phpFeatures(settings)

    configFile = "/vagrant/.vagrant/config.sh"
    configContent = [
      "cat <<'EOF' > #{configFile}",

      "#!/bin/bash",
      "",
      "export STUBROOT=\"#{@stubDir}\"",
      "export DEBIAN_FRONTEND=\"noninteractive\"",
      "export CODENAME=$(lsb_release -c | awk \'{ print $2 }\')",
      "export RELEASE=$(lsb_release -r | awk \'{ print $2 }\')",
      "export HOSTNAME=$(hostname -s)",
      "export DOMAIN=$(hostname -d)",
      "export HOSTIP=\"#{self.getHostIp(settings)}\"",
      "export TIMEZONE=\"#{settings["timezone"] ||= "Etc/UTC"}\"",
      "",
      "export PHP_VERSIONS=\"#{phpVersions.join(' ')}\"",
      "export SITE_PATH=\"#{settings["path"]["site"] ||= "/vagrant/var/sites"}\"",
      "export BACKUP_PATH=\"#{settings["path"]["backup"] ||= "/vagrant/.vagrant/backup"}\"",
      "export LOGS_PATH=\"#{settings["path"]["logs"] ||= "/vagrant/var/log"}\"",
      "export SSL_PATH=\"#{settings["path"]["ssl"] ||= "/vagrant/var/ssl"}\"",
      "export SHA1_FILE=\"${SITE_PATH}/mysql/backup.sha1\"",
      "",
      "aptupdate () {\n  apt-get -qq -o Dpkg::Use-Pty=0 update > /dev/null 2>&1\n}",
      "aptupgrade () {\n  apt-get -qqy -o Dpkg::Use-Pty=0 upgrade > /dev/null 2>&1\n}",
      #"aptinstall () {\n  apt-get -qqy -o Dpkg::Use-Pty=0 install $@ > /dev/null 2>&1\n}",
      "aptinstall () {\n  apt-get -qqy -o Dpkg::Use-Pty=0 install $* > /dev/null 2>&1\n}",
      "aptcheck () {\n  /usr/bin/dpkg-query --show --showformat='\${db:Status-Status}\\n' $* > /dev/null 2>&1\n}",

      "EOF",
      ""
    ]

    #File.write("config.ini", configContent.join("\n"), mode: "w")

    config.vm.provision "shell",
      name: "Creating parameter file",
      privileged: true,
      inline: configContent.join("\n")

    features = self.getFeatureSet(config, settings)
    features.each do |name, feature|
      if feature.has_key?('stub')
        config.vm.provision "file",
          source: feature.dig("stub", "local"),
          destination: feature.dig("stub", "remote")
      end
    end

    config.vm.provision "shell",
      name: "Base installer",
      privileged: true,
      path: "./deployment/install.sh"

  end

  def self.setupBox(config, settings)
    features = self.getFeatureSet(config, settings)

    features.each do |name, feature|
      #if feature.has_key?('stub')
      #  config.vm.provision "file",
      #    source: feature.dig("stub", "local"),
      #    destination: feature.dig("stub", "remote")
      #end

      if feature.has_key?('variables')
        if !feature["variables"].kind_of?(Hash)
          if feature['variables'].methods.include? 'to_h'
            feature["variables"] = feature["variables"].to_h
          else
            var = Hash.new
            var.store("arg", feature["variables"])
            feature["variables"] = var
          end
        end
      end
      feature_args = feature['variables'].values

      config.vm.provision "shell",
        name: "Installing " + feature['name'],
        privileged: true,
        path: feature["path"],
        args: feature_args,
        env: feature["variables"]
    end
  end

  def self.deploySites(config, settings)
    # Add Configured Sites
    if settings['sites'].kind_of?(Array)
      config.vm.provision "shell",
        name: "Clearing all sites",
        privileged: true,
        path: "./deployment/clear-sites.sh"

      settings["sites"].each do |site|
        config.vm.provision "shell",
          name: "Creating certificate for " + site['hostname'],
          privileged: true,
          args: [site["hostname"]],
          path: "./deployment/create-certificate.sh"

        config.vm.provision "shell",
          name: "Deploying " + site['hostname'],
          privileged: true,
          args: [
            site["hostname"],
            site["to"],
            site.dig("ssl") ? "1" : "0",
            site["php"] ||= @defaultPhp,
            site["404"] ||= ""
          ],
          path: "./deployment/create-site.sh"
      end
    end
    # Restart all installed HTTPD & PHP-FPM
    config.vm.provision "shell",
      name: "Restarting services",
      privileged: true,
      path: "./deployment/restart-service.sh"
  end

  def self.setupSSH(config, settings)
    if !Vagrant::Util::Platform.windows?
      # Configure The Public Key For SSH Access
      settings["authorize"].each do |key|
        if File.exists? File.expand_path(key) then
          config.vm.provision "shell",
            name: "Copying SSH Public Key",
            privileged: false,
            inline: "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo $1 | tee -a /home/vagrant/.ssh/authorized_keys",
            args: [File.read(File.expand_path(key))]
          end
        end
      # Copy The SSH Private Keys To The Box
      settings["keys"].each do |key|
        if File.exists? File.expand_path(key) then
          config.vm.provision "shell",
            name: "Copying SSH Private Key",
            privileged: false,
            inline: "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2",
            args: [File.read(File.expand_path(key)), key.split('/').last]
        end
      end
    end
  end

  def self.setupHosts(config, settings)
    if Vagrant.has_plugin?('vagrant-hostsupdater')
      config.hostsupdater.remove_on_suspend = false
      config.hostsupdater.aliases = self.getDomains(settings)
    elsif Vagrant.has_plugin?('vagrant-hostmanager')
      config.hostmanager.enabled = true
      config.hostmanager.manage_host = true
      config.hostmanager.aliases = self.getDomains(settings)
    elsif Vagrant.has_plugin?('vagrant-goodhosts')
      config.goodhosts.aliases = self.getDomains(settings)
    end

    if Vagrant.has_plugin?('vagrant-notify-forwarder')
      config.notify_forwarder.enable = true
    end
  end

  def self.setupDatabase(config, settings)
    # Configure All Of The Configured Databases
    if settings['databases'].kind_of?(Array)
      settings["databases"].each do |db|
        config.vm.provision "shell",
          name: "Creating database '" + db + "'",
          privileged: true,
          path: "./deployment/create-db.sh",
          args: [db]
      end
    end
  end

  def self.trustSkeleton(config)
    return [
      "#!/bin/bash",
      "",
      "FULLPATH=$(realpath $0)",
      "DIRECTORY=$(dirname ${FULLPATH})",
      "SSL_ROOT_PATH=\"${DIRECTORY}/ssl\"",
      "KEYCHAIN=\"/Library/Keychains/System.keychain\"",
      "#HASH=\"SHA-1\"",
      "HASH=\"SHA-256\"",
      "",
      "source ./deployment/macos.security.sh",
      "",
    ]
  end

  def self.trustSSL(config, settings, fileName)
    hostname = config.vm.hostname.split(".").first()
    caPath = "ca.#{hostname}.crt"

    commands = self.trustSkeleton(config)
    commands.push("backup")
    commands.push("authorize")
    commands.push("")

    commands.push("checkAddCert \"#{caPath}\" \"trustRoot\"")
    settings["sites"].each do |site|
      commands.push("checkAddCert \"#{site['hostname']}.crt\"")
    end

    commands.push("")
    commands.push("deauthorize")
    commands.push("restore")

    File.write(fileName, commands.join("\n"), mode: "w")
    FileUtils.chmod("+x", fileName)
  end

  def self.untrustSSL(config, settings, fileName)
    hostname = config.vm.hostname.split(".").first()
    caPath = "ca.#{hostname}.crt"

    commands = self.trustSkeleton(config)
    commands.push("backup")
    commands.push("authorize")
    commands.push("")

    commands.push("removeCert \"#{caPath}\"")

    settings["sites"].each do |site|
      commands.push("removeCert \"#{site['hostname']}.crt\"")
    end

    commands.push("")
    commands.push("deauthorize")
    commands.push("restore")

    File.write(fileName, commands.join("\n"), mode: "w")
    FileUtils.chmod("+x", fileName)
  end

  def self.fixSystem(config, settings)
    # Turn off CFQ scheduler idling https://github.com/laravel/homestead/issues/896
    if settings.has_key?('disable_cfq')
      config.vm.provision 'shell' do |s|
        s.inline = 'sudo sh -c "echo 0 >> /sys/block/sda/queue/iosched/slice_idle"'
      end
      config.vm.provision 'shell' do |s|
        s.inline = 'sudo sh -c "echo 0 >> /sys/block/sda/queue/iosched/group_idle"'
      end
    end
  end
end
