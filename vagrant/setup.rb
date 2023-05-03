class Skeleton
  def Skeleton.configure(config, settings)
    # Configure The Box
    #config.vm.box = "ubuntu/focal64"
    #config.vm.box = "roboxes/ubuntu2004"
    config.vm.box = "roboxes/ubuntu2204"
    config.vm.hostname = settings["hostname"] ||= "vagrant.local"

    if settings.key?("networking")
      settings["networking"].each do |net|
        if net.key?("network")
          network = net["network"] ? "public_network" : "private_network"
        else
          network = "private_network"
        end

        config.vm.network network,
          ip: net["ip"] ||= nil,
          #netmask: net["netmask"] ||= nil,
          type: net["type"] ||= nil
      end
    end

    # Configure A Few VMWare Desktop Settings
    config.vm.provider :vmware_desktop do |v|
      #v.name = 'vagrant'
      if settings.key?("gui")
        v.gui = settings["gui"]
      end
      v.vmx["memsize"] = settings["memory"] ||= "2048"
      v.vmx["numvcpus"] = settings["cpus"] ||= "1"
    end

    # Configure A Few VirtualBox Settings
    config.vm.provider "virtualbox" do |vb|
      vb.name = 'vagrant'
      if settings.key?("gui")
        vb.gui = settings["gui"]
      end
      vb.customize [
        "modifyvm", :id,
        "--memory", settings["memory"] ||= "2048",
        "--cpus", settings["cpus"] ||= "1",
        "--natdnshostresolver1", settings["natdnshostresolver"] ||= "on",
        "--natdnsproxy1", settings["natdnsproxy"] ||= "on"
      ]
    end

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

    # Register All Of The Configured Shared Folders
    if settings['folders'].kind_of?(Array)
      config.vm.synced_folder ".", "/vagrant"

      settings["folders"].each do |folder|
        config.vm.synced_folder folder["map"],
          folder["to"],
          type: folder["type"] ||= nil
      end
    end

    self.syncFiles(config, settings)
    self.setupBox(config, settings)
    self.setupHosts(config, settings)
    self.setupSSH(config, settings)
    self.setupDatabase(config, settings)
    self.addComposer(config, settings)

    config.trigger.after :provision do |t|
      t.name = "SSL Trust"
      t.info = "Applying trust for box generated SSL"
      t.ruby do |env,machine|
        Skeleton.trustSSL(config, settings)
      end
    end

    config.trigger.before :destroy do |t|
      t.name = "SSL Untrust"
      t.info = "Removing trust for box generated SSL"
      t.ruby do |env,machine|
        self.untrustSSL(config, settings)
      end
    end
  end

  def self.syncFiles(config, settings)
    stubDirectory = "vagrant/stubs"
    stubFiles = [
      "apache2/",
      "mysql/",
      "openssl/",
      "nginx/",
    ]
    phpVersions = [
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
      phpVersions = []
      settings["php"].each do |php|
        phpVersions.push(php)
        stubFiles.push("php/php#{php}")
      end
      stubFiles.push("php/vagrant-cli.ini")
      stubFiles.push("php/vagrant-common.conf")
      stubFiles.push("php/vagrant-fpm-pool.conf")
    else
      stubFiles.push("php/")
    end

    stubFiles.each do |file|
      dirs = file.split("/")
      f = dirs.pop()
      dirs = dirs.join("/")
      config.vm.provision "file",
        source: "./#{stubDirectory}/#{file}",
        destination: "/home/#{stubDirectory}/#{dirs}/#{f}"
    end

    if settings.key?("dotnet") && settings['dotnet'].kind_of?(Array)
      settings["sites"].each do |site|
        netVersion = site["dotnet"] ||= "7.0"
        unless settings["dotnet"].include?(netVersion)
          settings["dotnet"].push(netVersion)
        end
      end
    end

    unless settings.key?("path")
      settings["path"] = Hash.new
    end

    unless settings.key?("mailtrap")
      settings["mailtrap"] = Hash.new
    end

    unless settings.key?("ssl")
      settings["ssl"] = Hash.new
    end

    configFile="/root/vagrant_conf.sh"
    configContent = [
      "touch #{configFile}",
      "echo 'export STUBROOT=\"/home/#{stubDirectory}\"' >> #{configFile}",
      "echo 'export DEBIAN_FRONTEND=\"noninteractive\"' >> #{configFile}",
      "echo 'export HOSTIP=\"#{self.getHostIp(settings)}\"' >> #{configFile}",
      "echo 'export TIMEZONE=\"#{settings["timezone"] ||= "Etc/UTC"}\"' >> #{configFile}",
      "echo 'export HTTPD=\"#{settings["httpd"] ||= "apache2"}\"' >> #{configFile}",
      "echo 'export PHP_VERSIONS=\"#{phpVersions.join(' ')}\"' >> #{configFile}",
      "echo 'export NGROK=\"#{settings["ngrok"] ||= ""}\"' >> #{configFile}",
      "echo 'export DOTNET=\"#{settings["dotnet"] ||= ""}\"' >> #{configFile}",
      "echo 'export MAILTRAP_USERNAME=\"#{settings["mailtrap"]["username"] ||= ""}\"' >> #{configFile}",
      "echo 'export MAILTRAP_PASSWORD=\"#{settings["mailtrap"]["password"] ||= ""}\"' >> #{configFile}",
      "echo 'export SITE_PATH=\"#{settings["path"]["site"] ||= "/vagrant/sites"}\"' >> #{configFile}",
      "echo 'export LOGS_PATH=\"#{settings["path"]["logs"] ||= "/vagrant/logs"}\"' >> #{configFile}",
      "echo 'export SSL_PATH=\"#{settings["ssl"]["path"] ||= "/vagrant/ssl"}\"' >> #{configFile}",
      "echo 'export SSL_HOST=\"#{settings["ssl"]["name"] ||= "$(hostname)"}\"' >> #{configFile}",
      "echo 'export SSL_DAYS=\"#{settings["ssl"]["days"] ||= "3650"}\"' >> #{configFile}",
    ]

    config.vm.provision "shell",
      privileged: true,
      inline: configContent.join("\n")

    config.vm.provision "shell",
      privileged: true,
      path: "./vagrant/install.sh"

  end

  def self.setupBox(config, settings)
    configFiles = [ "apache2", "nginx", "redis", "mariadb", "php", "nvm", "emscripten", "postfix" ]
    configFiles.each do |app|
      config.vm.provision "shell",
        privileged: true,
        path: "./vagrant/configure-" + app + ".sh"
    end

    # Configure Mailtrap.io for Postfix
    #if settings.key?("mailtrap") && settings["mailtrap"].key?("username") && settings["mailtrap"].key?("password")
    #  config.vm.provision "shell",
    #    privileged: true,
    #    args: [settings["mailtrap"]["username"], settings["mailtrap"]["password"]],
    #    path: "./vagrant/configure-postfix.sh"
    #end

    # Add Configured Sites
    if settings['sites'].kind_of?(Array)
      config.vm.provision "shell",
        privileged: true,
        path: "./vagrant/clear-sites.sh"

      settings["sites"].each do |site|
        ssl = site["ssl"] || false
        ssl = ssl ? "1" : "0"

        config.vm.provision "shell",
          privileged: true,
          args: [site["hostname"]],
          path: "./vagrant/create-certificate.sh"

        config.vm.provision "shell",
          privileged: true,
          args: [site["hostname"], site["to"], ssl, site["php"] ||= "8.1", site["404"] ||= ""],
          path: "./vagrant/create-site.sh"
      end
    end

    # Restart all installed HTTPD & PHP-FPM
    config.vm.provision "shell",
      privileged: true,
      path: "./vagrant/restart-service.sh"
  end

  def self.trustSSL(config, settings)
    caPath = "./ssl/ca.#{config.vm.hostname}.crt"

    keyChain = "/Library/Keychains/System.keychain"

    certCommand = "sudo security add-trusted-cert -d -r %s -k %s \"%s\""

    if Vagrant.has_plugin? 'vagrant-host-shell'
      config.vm.provision :host_shell do |host_shell|
        root = sprintf(certCommand, "trustRoot", keyChain, caPath)
        host_shell.inline = "echo \"** #{root}\"; #{root};"
      end
        
      settings["sites"].each do |site|
        config.vm.provision :host_shell do |host_shell|
          cert = sprintf(certCommand, "trustAsRoot", keyChain, site["hostname"])
          host_shell.inline = "echo \"** #{cert}\"; #{cert};"
        end
      end
    end
  end

  def self.untrustSSL(config, settings)
    keyChain = "/Library/Keychains/System.keychain"

    certCommand = "sudo security delete-certificate -t -c \"%s\" %s"
    searchCommand = "sudo security find-certificate -e \"%s@%s\" -a -Z | grep SHA-1 | sudo awk \'{system(\"security delete-certificate -t -Z \'$NF\' %s\")}\'"

    hostname = config.vm.hostname.split(".").first()

    if Vagrant.has_plugin? 'vagrant-host-shell'
      config.vm.provision :host_shell do |host_shell|
        host_shell.inline = sprintf(certCommand, hostname, keyChain)
      end
      settings["sites"].each do |site|
        config.vm.provision :host_shell do |host_shell|
          host_shell.inline = sprintf(certCommand, site["hostname"], keyChain)
        end
        config.vm.provision :host_shell do |host_shell|
          host_shell.inline = sprintf(certCommand, "*.#{site["hostname"]}", keyChain)
        end
        config.vm.provision :host_shell do |host_shell|
          host_shell.inline = sprintf(searchCommand, site["hostname"], config.vm.hostname, keyChain)
        end
      end
    end
  end

  def self.getHostIp(settings)
    hostIP = ""

    if hostIP.empty?
      hostIP = settings["networking"][0]["ip"].split(".");
      hostIP.pop
      hostIP.push(1)
      hostIP = hostIP.join(".")
    end

    return hostIP
  end

  def self.getDomains(settings)
    domains = []

    settings["sites"].each do |site|
      domains.append(site["hostname"])
    end

    return domains
  end

  def self.setupSSH(config, settings)
    if !Vagrant::Util::Platform.windows?
      # Configure The Public Key For SSH Access
      settings["authorize"].each do |key|
        if File.exists? File.expand_path(key) then
          config.vm.provision "shell",
            privileged: false,
            inline: "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo $1 | tee -a /home/vagrant/.ssh/authorized_keys",
            args: [File.read(File.expand_path(key))]
        end
      end
      # Copy The SSH Private Keys To The Box
      settings["keys"].each do |key|
        if File.exists? File.expand_path(key) then
          config.vm.provision "shell",
            privileged: false,
            inline: "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2",
            args: [File.read(File.expand_path(key)), key.split('/').last]
        end
      end
    end
  end

  def self.setupHosts(config, settings)
    if Vagrant.has_plugin? 'vagrant-hostsupdater'
      # Remove hosts when suspending too
      config.hostsupdater.remove_on_suspend = true
      config.hostsupdater.aliases = self.getDomains(settings)
    else
      config.trigger.after :up do |trigger|
        trigger.name = "Hosts to point in"
        trigger.info = "Please make sure add the configured hosts to your hosts file"
      end
    end
  end

  def self.setupDatabase(config, settings)
    # Configure All Of The Configured Databases
    if settings['databases'].kind_of?(Array)
      settings["databases"].each do |db|
        config.vm.provision "shell",
          privileged: true,
          path: "./vagrant/create-db.sh",
          args: [db]
      end
    end
  end

  def self.addComposer(config, settings)
    # Install Composer On Every Provision
    config.vm.provision "shell",
      privileged: true,
      run: "always",
      path: "./vagrant/composer.sh",
      args: [ settings['composer'] ||= "1" ]
  end
end
