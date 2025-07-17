#!/usr/bin/env bash

# REGION: install elm
# download
curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz

# unzip
gunzip elm.gz

# give "executable" permissions
chmod +x elm

# NOTE: no "sudo" access, so we will keep usage local/relative

# REGION: build clients
# app
cd ./client/scripts/
./prodbuild.sh
cd ../../

# REGION: build server
cd ./server
cargo build --release
cd ../
