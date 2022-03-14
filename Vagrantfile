# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "hashicorp/bionic64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  #
  config.vm.network "forwarded_port", guest: 8443, host_ip: "127.0.0.1", host: 8443, id: "nifiUI"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  config.vm.network "forwarded_port", guest: 9404, host: 9404, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 9092, host: 9092, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 8080, host: 8080, host_ip: "127.0.0.1"
  config.vm.network "forwarded_port", guest: 8000, host: 8000, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y build-essential golang-go jq
    apt-get install -y awscli
    apt-get install -y openjdk-11-jdk
    runuser vagrant -c "wget -c -nv -P /vagrant/downloads https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
    dpkg -i -E /vagrant/downloads/amazon-cloudwatch-agent.deb
    cp /vagrant/common-config.toml /opt/aws/amazon-cloudwatch-agent/etc/common-config.toml

  SHELL

  config.vm.provision "shell", privileged: false,  inline: <<-SHELL
    wget -c -nv -P /vagrant/downloads https://dlcdn.apache.org/nifi/1.15.3/nifi-1.15.3-bin.tar.gz
    rm -rf nifi-1.15.3 || true
    tar xzf /vagrant/downloads/nifi-1.15.3-bin.tar.gz
    wget -c -nv -P /vagrant/downloads https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.16.1/jmx_prometheus_javaagent-0.16.1.jar
    mv nifi-1.15.3/conf/bootstrap.conf{,.old} || true
    mv nifi-1.15.3/conf/nifi.properties{,.old} || true
    cp /vagrant/bootstrap.conf nifi-1.15.3/conf/bootstrap.conf 
    cp /vagrant/nifi.properties nifi-1.15.3/conf/nifi.properties


  SHELL
end
