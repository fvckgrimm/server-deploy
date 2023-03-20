#!/bin/bash

# Install essential build tools and additional packages
sudo apt update
sudo apt install -y \
	build-essential git curl wget libssl-dev libreadline-dev zlib1g-dev libbz2-dev libsqlite3-dev tmux neovim \
	python3 python3-pip fonts-powerline exa rsync make gcc apt-transport-https bmon ca-certificates dnsutils \
	ffmpeg file g++ gnupg htop iftop jq libpcre3 libpcre3-dev libssl-dev lsb-release magic-wormhole net-tools nload \
	p7zip-full screen secure-delete smartmontools software-properties-common sshfs sysstat traceroute unrar \
	unzip whois zlib1g zlib1g-dev ncdu

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

cargo install bottom --locked

# Install Volta
curl https://get.volta.sh | bash

# Install Docker
curl -sSL https://get.docker.com/ | CHANNEL=stable sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | cut -d\" -f4)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose \
  && chmod +x /usr/bin/docker-compose \
  && docker-compose version

# Install Cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
&& sudo dpkg -i cloudflared-linux-amd64.deb \
&& rm cloudflared-linux-amd64.deb

# Install Nginx
echo "deb http://nginx.org/packages/mainline/ubuntu/ $(lsb_release -cs) nginx" \
  >> /etc/apt/sources.list.d/nginx.list \
  && echo "deb-src http://nginx.org/packages/mainline/ubuntu/ $(lsb_release -cs) nginx" \
  >> /etc/apt/sources.list.d/nginx.list \
  && curl -fsSL http://nginx.org/keys/nginx_signing.key | apt-key add - && apt update

# Install and test
apt install -y nginx \
  && nginx -v

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
curl -s https://api.github.com/repos/borgbackup/borg/releases/latest \
  | grep browser_download_url | grep 'linux' | cut -d '"' -f 4 | head -1 \
  | wget -i - -O ~/bin/borg \
  && chmod +x ~/bin/borg \
  && borg --version

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
sudo -H -u $USERNAME install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
curl -sSL https://github.com/zthxxx/jovial/raw/master/installer.sh | sudo -E bash -s ${USER:=`whoami`}
source ~/.zshrc

# Switch back to root user
sudo su

# Install ohmysh for root user and set jovial theme
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
curl -sSL https://github.com/zthxxx/jovial/raw/master/installer.sh | sudo -E bash -s ${USER:=`whoami`}
source ~/.zshrc

# Install golang
GOURL="https://go.dev/dl/$(curl -s "https://go.dev/dl/#stable" | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -1).linux-amd64.tar.gz" 
wget -c $GOURL -O - | tar -xz -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc
source ~/.zshrc

# Install lazydocker
go install github.com/jesseduffield/lazydocker@latest

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

# Optional Netmaker install
read -p "Do you want to install Netmaker(server/dashboard for wiregaurd)? (y/n): " choice
if [[ $choice == [Yy]* ]]; then
    sudo wget -qO /root/nm-quick-interactive.sh https://raw.githubusercontent.com/gravitl/netmaker/master/scripts/nm-quick-interactive.sh \
    && sudo chmod +x /root/nm-quick-interactive.sh && sudo /root/nm-quick-interactive.sh
else
    echo "Netmaker installation skipped. Installing netclient"
fi

# Install netclient
curl -sL 'https://apt.netmaker.org/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/netclient.asc
curl -sL 'https://apt.netmaker.org/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/netclient.list
sudo apt update
sudo apt install netclient

# Tools to build from source
# duf -- df alt
git clone https://github.com/muesli/duf && cd duf
go build && mv ./duf /usr/local/bin/ && cd ~ && rm -rf duf

# rclone
git clone https://github.com/rclone/rclone && cd rclone
VERS="a9-v$(git tag -l --sort=-v:refname | sed 's/v\([^-].*\)/\1/g' | head -1 | tr -d '-' ).$(git describe --long --tags | sed 's/\([^-].*\)-\([0-9]*\)-\(g.*\)/r\2.\3/g' | tr -d '-')"
go build -v --ldflags "-s -X github.com/rclone/rclone/fs.Version=${VERS}" && mv ./rclone /usr/local/bin/ && cd ~ && rm -rf rclone

# gotop
git clone https://github.com/xxxserxxx/gotop && cd gotop
VERS="a9-v$(git tag -l --sort=-v:refname | sed 's/v\([^-].*\)/\1/g' | head -1 | tr -d '-' ).$(git describe --long --tags | sed 's/\([^-].*\)-\([0-9]*\)-\(g.*\)/r\2.\3/g' | tr -d '-')"
DATE=$(date +%Y%m%dT%H%M%S)
go build -o gotop -ldflags "-X main.Version=${VERS} -X main.BuildDate=${DATE}" ./cmd/gotop && mv ./gotop /usr/local/bin/ && cd ~ && rm -rf gotop

# dust -- du alt
git clone https://github.com/bootandy/dust && cd dust
cargo build --release && cp ./target/release/dust /usr/local/bin && cd ~ && rm -rf dust

# fd -- find alt
git clone https://github.com/sharkdp/fd && cd fd
cargo build --release && cp ./target/release/fd /usr/local/bin && cd ~ && rm -rf fd

# ripgrep -- grep alt
git clone https://github.com/BurntSushi/ripgrep && cd ripgrep
cargo build --release --features 'pcre2' && cp ./target/release/rg /usr/local/bin && cd ~ && rm -rf ripgrep

# procs -- ps alt
git clone https://github.com/dalance/procs && cd procs
cargo build --release && cp ./target/release/procs /usr/local/bin && cd ~ && rm -rf procs

# jdupes -- file deduplication
## Example: jdupes -LZ data/
git clone https://github.com/jbruchon/jdupes && cd jdupes
make && make install && cd ~ && rm -rf jdupes

echo "Setup complete!"
