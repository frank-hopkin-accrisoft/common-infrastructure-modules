#!/bin/bash

sudo apt update && apt upgrade
sudo apt install apache2 curl -y
sudo apt install apt-transport-https ca-certificates curl gnupg-agent software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose
sudo usermod -aG docker *bitwarden*

curl -Lso bitwarden.sh https://go.btwrdn.co/bw-sh