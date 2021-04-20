#!/bin/sh
. env.sh
cargo build
cp dist-assets/binaries/x86_64-unknown-linux-gnu/sslocal dist-assets/
cp dist-assets/binaries/x86_64-unknown-linux-gnu/openvpn dist-assets/
cp target/debug/libtalpid_openvpn_plugin.* dist-assets/
