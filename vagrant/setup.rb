class Skeleton
  def Skeleton.configure(config, settings)
    # Configure The Box
    config.vm.box = "ubuntu/focal64"
    config.vm.hostname = settings["hostname"] ||= "vagrant.local"
    domains = []

    vmIP = settings["ip"] ||= "192.168.121.7"
    hostIP = vmIP.split(".");
    hostIP.pop
    hostIP.push(1)
    hostIP = hostIP.join(".")

    # Configure A Private Network IP
    config.vm.network :private_network, ip: vmIP

    if settings['networking'][0]['public']
      config.vm.network "public_network", type: "dhcp"
    end

    # Configure A Few VirtualBox Settings
    config.vm.provider "virtualbox" do |vb|
      vb.name = 'vagrant'
      if settings.has_key?("gui")
        vb.gui = settings["gui"]
      end
      vb.customize [
        "modifyvm", :id,
        "--memory", settings["memory"] ||= "2048",
        "--cpus", settings["cpus"] ||= "1",
        "--ostype", "Debian_64",
        #"--cpuexecutioncap", settings["cpuexecutioncap"] ||= "80",
        #"--ioapic", settings["ioapic"] ||= "on",
        #"--graphicscontroller", settings["graphicscontroller"] ||= "vmsvga",
        "--audio", "none",
        "--usb", "off",
        "--usbehci", "off",
        "--natdnshostresolver1", settings["natdnshostresolver"] ||= "on",
        "--natdnsproxy1", settings["natdnsproxy"] ||= "on",
      ]
    end

    config.vm.provision "file",
      source: "./vagrant/stubs/vagrant-cli.ini",
      destination: "/home/vagrant/stubs/vagrant-cli.ini"

    if settings.has_key?("php") && settings['sites'].kind_of?(Array)
      settings["sites"].each do |site|
        phpVersion = site["php"] ||= "8.1"
        unless settings["php"].include?(phpVersion)
          settings["php"].push(phpVersion)
        end
      end
    end

    if settings.has_key?("php")
      settings["php"].each do |php|
        config.vm.provision "file",
          source: "./vagrant/stubs/php#{php}",
          destination: "/home/vagrant/stubs/"
      end
    else
      config.vm.provision "file",
        source: "./vagrant/stubs",
        destination: "/home/vagrant/"
    end

    config.vm.provision "shell",
      privileged: true,
      args: [hostIP, settings["timezone"] ||= "Etc/UTC"],
      path: "./vagrant/install.sh"

    configFiles = [ "apache", "redis", "db", "php", "nvm" ]
    configFiles.each do |app|
      config.vm.provision "shell",
        privileged: true,
        args: [hostIP],
        path: "./vagrant/configure-" + app + ".sh"
    end

    # Configure Port Forwarding To The Box
    #config.vm.network "forwarded_port", guest: 22, host: 2222
    config.vm.network "forwarded_port", guest: 80, host: 8000
    config.vm.network "forwarded_port", guest: 443, host: 44300
    config.vm.network "forwarded_port", guest: 3306, host: 33060

    # Add Custom Ports From Configuration
    if settings.has_key?("ports")
      settings["ports"].each do |port|
        config.vm.network "forwarded_port",
          guest: port["guest"],
          host: port["host"],
          protocol: port["protocol"] ||= "tcp"
      end
    end

   # Configure Mailtrap.io for Postfix
    if settings.has_key?("mailtrap") && settings["mailtrap"].has_key?("username") && settings["mailtrap"].has_key?("password")
         config.vm.provision "shell",
           privileged: true,
           args: [settings["mailtrap"]["username"], settings["mailtrap"]["password"]],
           path: "./vagrant/configure-postfix.sh"
    end

    # Register All Of The Configured Shared Folders
    if settings['folders'].kind_of?(Array)
      settings["folders"].each do |folder|
        config.vm.synced_folder folder["map"], folder["to"], type: folder["type"] ||= nil
      end
    end

    # Add Configured Apache Sites
    if settings['sites'].kind_of?(Array)
      config.vm.provision "shell",
        privileged: true,
        path: "./vagrant/clear-apache-sites.sh"

      settings["sites"].each do |site|
        ssl = site["ssl"] || false
        ssl = ssl ? "1" : "0"
        domains.append(site["hostname"])

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

    config.vm.provision "shell",
      privileged: true,
      inline: <<-SH
services="apache2";
for f in /etc/php/*; do
  if [ ! -d "${f}" ]; then
    continue;
  fi;
  dir=${f##*/}
  services="$services php$dir-fpm";
done;
systemctl restart $services

SH

    if Vagrant.has_plugin? 'vagrant-hostsupdater'
      # Remove hosts when suspending too
      config.hostsupdater.remove_on_suspend = true
      config.hostsupdater.aliases = domains
    else
      config.trigger.after :up do |trigger|
        trigger.name = "Hosts to point in"
        trigger.info = "Please make sure add the configured hosts to your hosts file"
      end
    end

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

    # Configure All Of The Configured Databases
    if settings['databases'].kind_of?(Array)
      settings["databases"].each do |db|
        config.vm.provision "shell",
          privileged: true,
          path: "./vagrant/create-db.sh",
          args: [db]
      end
    end

    # Install Composer On Every Provision
    config.vm.provision "shell",
      privileged: true,
      run: "always",
      path: "./vagrant/composer.sh",
      args: [ settings['composer'] ||= "1" ]
  end
end
