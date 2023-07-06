#!/bin/bash
#https://linux.how2shout.com/how-to-install-vaultwarden-on-ubuntu-22-04-lts-jammy/#1_Add_Dockers_GPG_Key
sudo apt update -y && sudo apt upgrade -y
#Add add the GPG key
sudo apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

#Add docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update -y
#Install docker engine, enable docker and add user
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
sudo systemctl enable --now docker
#sudo systemctl status docker
sudo usermod -aG docker $USER
newgrp docker

#Install vaultwarden
docker pull vaultwarden/server:latest
#Add dir to store vaultwarden data
sudo mkdir /srv/vw-data/
sudo chmod go-rwx /srv/vw-data/
#Start vaultwarden
sudo docker run -d --name vaultwarden -v /srv/vw-data:/data -p 80:80 -p 443:443 -p 3012:3012 --restart on-failure vaultwarden/server:latest

#Enable backups
sudo apt-get install sqlite3
sudo mkdir /srv/backup
# give group read,write,exec perms
sudo chmod go-rwx /srv/backup
#create backup service config
sudo touch /etc/systemd/system/vaultwarden-backup.service
sudo tee /etc/systemd/system/vaultwarden-backup.service > /dev/null <<'TXT'
[Unit]
Description=Vault backup
[Service]
Type=oneshot
WorkingDirectory=/srv/backup
ExecStart=/usr/bin/env sh -c 'sqlite3 /srv/vw-data/db.sqlite3 ".backup backup-$(date -Is | tr : _).sq3"'
ExecStart=/usr/bin/find . -type f -mtime +30 -name 'backup*' -delete
TXT
#start backup service
sudo systemctl start vaultwarden-backup.service
#create backup timer config
sudo touch /etc/systemd/system/vaultwarden-backup.timer
sudo tee /etc/systemd/system/vaultwarden-backup.timer > /dev/null <<'TXT'
[Unit]
Description= Vault backup timer

[Timer]
OnCalendar=06:00
Persistent=true

[Install]
WantedBy=multi-user.target
TXT
#start timer
sudo systemctl enable --now vaultwarden-backup.timer
#check status is active
sudo systemctl status vaultwarden-backup.timer
