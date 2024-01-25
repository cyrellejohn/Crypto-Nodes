#!/bin/bash

# Global Variables
ARKEO_NODENAME="kakitani"
GO_VERSION="1.21.6"
GENESIS_URL="http://seed.arkeo.network:26657/genesis"
ADDRBOOK_URL="https://snapshots-testnet.stake-town.com/arkeo/addrbook.json"
SEEDS="20e1000e88125698264454a884812746c2eb4807@seeds.lavenderfive.com:22856,df0561c0418f7ae31970a2cc5adaf0e81ea5923f@arkeo-testnet-seed.itrocket.net:18656"
SNAPSHOT_URL="https://snapshots-testnet.stake-town.com/arkeo/arkeo_latest.tar.lz4"

# Update and Install Dependencies
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y build-essential curl wget jq make gcc chrony git ccze htop lz4

# Increase File Descriptor Limit
echo 'fs.file-max = 65536' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

# Install Go
rm -rf $HOME/go /usr/local/go
wget "https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz"
sudo tar -C /usr/local -xzf "go$GO_VERSION.linux-amd64.tar.gz"
rm "go$GO_VERSION.linux-amd64.tar.gz"

# Configure Go Environment
echo -e "\n# Go environment setup" >> $HOME/.profile
echo "export GOROOT=/usr/local/go" >> $HOME/.profile
echo "export GOPATH=\$HOME/go" >> $HOME/.profile
echo "export GO111MODULE=on" >> $HOME/.profile
echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> $HOME/.profile
source $HOME/.profile
go version || { echo "Go installation failed"; exit 1; }

# Install Docker [Optional]
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Clone and Install Arkeo Binary
if [ ! -d "arkeo" ]; then
    git clone https://github.com/arkeonetwork/arkeo
fi
cd arkeo && make proto-gen && make install TAG=testnet
arkeod version || { echo "Arkeo installation failed"; exit 1; }

# Initialize Node
arkeod config chain-id arkeo
arkeod init "$ARKEO_NODENAME" --chain-id arkeo

# Download Genesis and Addrbook
curl -s $GENESIS_URL | jq '.result.genesis' > $HOME/.arkeo/config/genesis.json
curl -s $ADDRBOOK_URL > $HOME/.arkeo/config/addrbook.json
sudo ufw enable && sudo ufw allow 22 && sudo ufw allow 26656

# Configuration Variables
CONFIG_TOML=$HOME/.arkeo/config/config.toml
APP_TOML=$HOME/.arkeo/config/app.toml
INDEXER="null"
FILTER_PEERS="true"
ENABLE=false

# App Toml Specific Variables
MINIMUM_GAS_PRICES="0.001uarkeo"
PRUNING="custom"
PRUNING_KEEP_RECENT="100"
PRUNING_KEEP_EVERY="0"
PRUNING_INTERVAL="10"
SNAPSHOT_INTERVAL="0"

# Update config.toml
sed -i.bak \
  -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" \
  -e "s/^indexer *=.*/indexer = \"$INDEXER\"/" \
  -e "s/^filter_peers *=.*/filter_peers = \"$FILTER_PEERS\"/" \
  -e "s/^enable *=.*/enable = \"$ENABLE\"/" \
  "$CONFIG_TOML"

# Set Minimum Gas Price and Pruning in app.toml
sed -i.bak \
  -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"$MINIMUM_GAS_PRICES\"/" \
  -e "s/^pruning *=.*/pruning = \"$PRUNING\"/" \
  -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$PRUNING_KEEP_RECENT\"/" \
  -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$PRUNING_KEEP_EVERY\"/" \
  -e "s/^pruning-interval *=.*/pruning-interval = \"$PRUNING_INTERVAL\"/" \
  -e "s/^snapshot_interval *=.*/snapshot_interval = \"$SNAPSHOT_INTERVAL\"/" \
  "$APP_TOML"

# Configure Systemd Service
sudo tee /etc/systemd/system/arkeod.service > /dev/null << EOF
[Unit]
Description=Arkeo Node
After=network-online.target

[Service]
User=$USER
Type=simple
ExecStart=$(which arkeod) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Reset and Download Snapshot [Optional]
arkeod tendermint unsafe-reset-all --home $HOME/.arkeo --keep-addr-book
curl -L $SNAPSHOT_URL | lz4 -dc - | tar -xf - -C $HOME/.arkeo

# Launch Node
sudo systemctl daemon-reload
sudo systemctl enable arkeod
sudo systemctl start arkeod

# Monitor Node Logs
sudo journalctl -u arkeod -f -o cat
