#!/bin/bash

sudo apt install -y gcc libdbus-1-dev rpm ruby ruby-dev rubygems build-essential protobuf-compiler
sudo gem install --no-document ruby-xz:0.2.3 fpm:1.9.3
wget https://golang.org/dl/go1.16.3.linux-arm64.tar.gz -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/go.tar.gz
echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable-aarch64-unknown-linux-gnu
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
nvm install 12
npm install -g npm
