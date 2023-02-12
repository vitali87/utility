#!/bin/zsh

# Update package lists
sudo apt-get update

# Install required libraries
sudo apt-get install bc tar bzip2 unzip unrar p7zip-full lzma curl jq net-tools dnsutils coreutils less wget python3-pip dmidecode unzip lsof tar xz-utils bzip2 webp ghostscript jq imagemagick rename bc ffmpeg gifsicle openssl enscript pdftk -y

# Install speedtest-cli  using pip
sudo pip3 install speedtest-cli

# Check if Rust is installed
if ! command -v rustc > /dev/null 2>&1; then
  echo "Rust is not installed. Installing now..."
  curl https://sh.rustup.rs -sSf | sh
  source "$HOME/.cargo/env"
fi
cargo install xsv