sudo rm -f /etc/apache2/sites-enabled/*
sudo find /etc/apache2/sites-available/ -type f -not -name '*default*.conf' -delete
sudo find /etc/php/ -path "*/fpm/pool.d/*" -type f -not -name "www.conf" -delete
#sudo rm -f /vagrant/logs/*/*
#sudo rm -f /vagrant/ssl/*