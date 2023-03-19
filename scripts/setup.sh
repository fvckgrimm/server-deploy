#!/bin/bash

# Install essential build tools and additional packages
sudo apt update
sudo apt install -y \
	build-essential golang-go git curl wget libssl-dev libreadline-dev zlib1g-dev libbz2-dev libsqlite3-dev tmux neovim \
	python3 python3-pip fonts-powerline exa rclone rsync make gcc apt-transport-https bmon ca-certificates dnsutils \
	ffmpeg file g++ gnupg htop iftop jq libpcre3 libpcre3-dev libssl-dev lsb-release magic-wormhole net-tools nload \
	p7zip-full screen secure-delete smartmontools software-properties-common sshfs sysstat traceroute unrar \
	syscat unzip whois zlib1g zlib1g-dev ncdu

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

cargo install bottom --locked

# Install Volta
curl https://get.volta.sh | bash

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install -y docker-compose

# Install nano syntax highlighting
curl https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | sh

# Set nano configuration options
echo "set nohelp
set linenumbers
set autoindent
set tempfile
set tabsize 2
set tabstospaces
set positionlog" >> ~/.nanorc

# Install BorgBackup
wget https://github.com/borgbackup/borg/releases/download/1.2.3/borg-linux64 -O ~/bin/borg \
  && chmod +x ~/bin/borg

# Prompt for user and password
read -p "Enter username for new user: " USERNAME
read -p "Enter password for new user: " PASSWORD

# Create new user with home directory
sudo useradd -m $USERNAME

# Set password for new user
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Add user to sudo group
sudo usermod -aG sudo $USERNAME

# Switch to new user
sudo su - $USERNAME << EOF
cd ~
mkdir .ssh
touch .ssh/authorized_keys
chmod 700 .ssh
chmod 600 .ssh/authorized_keys
EOF

# Install Zsh for new user
sudo -H -u $USERNAME sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
curl -sSL https://github.com/zthxxx/jovial/raw/master/installer.sh | sudo -E bash -s ${USER:=`whoami`}
source ~/.zshrc

# Switch back to root user
sudo su

# Install Zsh for root user and set jovial theme
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
curl -sSL https://github.com/zthxxx/jovial/raw/master/installer.sh | sudo -E bash -s ${USER:=`whoami`}
source ~/.zshrc

# Add aliases to .zshrc
echo "alias ls='exa -L=1 -lhFTag'
alias at='tmux attach'" >> ~/.zshrc
source ~/.zshrc

sudo -H -u $USERNAME sh -c "echo \"alias ls='exa -L=1 -lhFTag'\" >> ~/.zshrc"
sudo -H -u $USERNAME sh -c "echo \"alias at='tmux attach'\" >> ~/.zshrc"

# Edit sshd config to disable root login and change default port
read -p "Enter a new SSH port (leave blank to use default 22): " SSH_PORT

if [ -n "$SSH_PORT" ]; then
  sudo sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
fi

sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Restart sshd service to apply changes
sudo service sshd restart

# Edit hostname
read -p "Enter new hostname (leave blank for default): " HOSTNAME
if [ ! -z "$HOSTNAME" ]; then
    sudo hostnamectl set-hostname $HOSTNAME
fi

# Install netmaker 
sudo wget -qO /root/nm-quick-interactive.sh https://raw.githubusercontent.com/gravitl/netmaker/master/scripts/nm-quick-interactive.sh \
&& sudo chmod +x /root/nm-quick-interactive.sh && sudo /root/nm-quick-interactive.sh

echo "Setup complete!"
