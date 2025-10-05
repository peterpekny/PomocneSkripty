#!/bin/bash

echo "########## -- updating DNS -- ##########"
echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 10.0.0.1" | sudo tee /etc/resolv.conf

echo "########## -- Test DNS -- ##########"
ping -c2 google.com
if [ $? != 0 ]; then
       echo "Something with DNS is wrong, exiting"
       exit 1
fi

echo "########## -- upgrading repositories -- ##########"
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%F)
sleep 2

echo "########## -- upgrading to use archive.ubuntu.com and security.ubuntu.com -- ##########"
sudo tee /etc/apt/sources.list > /dev/null <<'EOF'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
sleep 2

echo "########## -- cleaning apt cache -- ##########"
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get clean
sleep 2

echo "########## -- updating apt -- ##########"
sudo apt-get -o Acquire::ForceIPv4=true update
sleep 2

echo "########## -- reinstalling ubuntu-keyring, ca-certificates, apt-transport-https -- ##########"
sudo apt-get install --reinstall -y ubuntu-keyring ca-certificates apt-transport-https
sleep 2

echo "########## -- changing to https -- ##########"
sudo sed -i 's|http://|https://|g' /etc/apt/sources.list
sleep 2

echo "########## -- updating apt -- ##########"
sudo apt-get update
sleep 2

echo "########## -- upgrading all packages -- ##########"
sudo apt-get -y upgrade
sleep 2

echo "########## -- upgrading distribution -- ##########"
sudo apt-get -y dist-upgrade
sleep 2

echo "########## -- removing unneeded packages -- ##########"
sudo apt-get -y autoremove
sleep 2

echo "########## -- final update apt -- ##########"
sudo apt-get update
sleep 2

echo "########## -- all done -- ##########"
