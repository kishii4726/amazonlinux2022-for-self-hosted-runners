#!/bin/bash
sudo dnf install -y jq git libicu-67.1-7.amzn2022.x86_64

cd /tmp || exit
sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

sudo su - ec2-user <<EOF
mkdir ~/actions-runner
curl -L https://github.com/actions/runner/releases/download/v2.288.1/actions-runner-linux-x64-2.288.1.tar.gz -o \
  ~/actions-runner/actions-runner-linux-x64-2.288.1.tar.gz
tar xzf ~/actions-runner/actions-runner-linux-x64-2.288.1.tar.gz -C ~/actions-runner
cd ~/actions-runner
./config.sh \
  --url "https://github.com/${owner}/${repository}" \
  --token $(curl -XPOST -sL -H "Authorization: token $(aws ssm get-parameters --with-decryption --names GITHUB_PERSONAL_ACCESS_TOKEN --region ap-northeast-1 | jq -r .Parameters[].Value)" \
  -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/${owner}/${repository}/actions/runners/registration-token" | jq -r .token) \
  --name $(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
  --runnergroup Default \
  --labels ${label} \
  --work "_work"
./run.sh
EOF