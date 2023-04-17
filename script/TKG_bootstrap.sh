#!/bin/bash

IPADDRESS="$(ip addr show | awk '/inet / {if ($2 ~ /^172\.31\./) {gsub("/[0-9]+", "", $2); print $2}}')"

sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    jq \
    vim \
    curl \
    unzip \
    gzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

AWS_ACCESS_KEY_ID="" ## 추가하세요
AWS_SECRET_ACCESS_KEY=""
AWS_REGION=“ap-northeast-2

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set region $AWS_REGION

sudo apt-get remove docker docker-engine docker.io containerd runc

sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo chmod a+r /etc/apt/keyrings/docker.gpg
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 작업 전에 public access로 변경
wget https://starboy7525.s3.ap-northeast-2.amazonaws.com/tanzu/kubectl-linux-v1.23.8.vmware.gz
wget https://starboy7525.s3.ap-northeast-2.amazonaws.com/tanzu/tanzu-cli-bundle-linux.tar.gz
gunzip kubectl-linux-v1.23.8.vmware.gz
tar xfz tanzu-cli-bundle-linux.tar.gz

install cli/core/v*/tanzu-core-linux_amd64 /usr/local/bin/tanzu

chmod ugo+x kubectl-linux-v1.23.8.vmware
sudo mv kubectl-linux-v1.23.8.vmware /usr/local/bin/kubectl

wget https://github.com/vmware-tanzu/carvel-ytt/releases/latest/download/ytt-linux-amd64
wget https://github.com/vmware-tanzu/carvel-kapp/releases/latest/download/kapp-linux-amd64
wget https://github.com/vmware-tanzu/carvel-kbld/releases/latest/download/kbld-linux-amd64
wget https://github.com/vmware-tanzu/carvel-imgpkg/releases/latest/download/imgpkg-linux-amd

chmod ugo+x ytt-linux-amd64
sudo mv ytt-linux-amd64 /usr/local/bin/ytt

chmod ugo+x kapp-linux-amd64
sudo mv kapp-linux-amd64 /usr/local/bin/kapp

chmod ugo+x kbld-linux-amd64
sudo mv kbld-linux-amd64 /usr/local/bin/kbld

chmod ugo+x imgpkg-linux-amd64
sudo mv imgpkg-linux-amd64 /usr/local/bin/imgpkg


curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.14.0/kind-linux-amd64
chmod +x kind && sudo mv ./kind /usr/local/bin/kind

echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc

source ~/.bashrc

aws ec2 create-key-pair --key-name default --output json | jq .KeyMaterial -r > default.pem

tanzu init

tanzu mc create —ui —bind $IPADDRESS:8080  browser none



