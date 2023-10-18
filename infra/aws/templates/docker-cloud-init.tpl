#cloud-config
hostname: ${hostname}

apt:
  sources:
    docker.list:
      source: deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 0EBFCD88

packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io

users:
  - default
  - name: ${ssh_user}
    gecos: ${ssh_user}
    lock_passwd: true
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: admin, sudo
    ssh_authorized_keys:
      - ${ssh_key}

write_files:
  - path: /etc/docker/daemon.json
    content: |
      {
        "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:${docker_port}"]
      }
  - path: /etc/systemd/system/docker.service.d/override.conf
    content: |
      # Disable flags to dockerd, all settings are done in /etc/docker/daemon.json
      [Service]
      ExecStart=
      ExecStart=/usr/bin/dockerd --iptables=false
    
runcmd:
  - systemctl daemon-reload
  - systemctl restart docker
  - usermod -aG docker ubuntu
  - usermod -aG docker ${ssh_user}
