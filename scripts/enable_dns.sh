#!/bin/bash

set -e

if ! command -v cloudflared &> /dev/null; then
    if ! command -v yay &> /dev/null; then
        echo "Error: AUR helper (yay) is required to install cloudflared."
        exit 1
    fi
    yay -S --noconfirm cloudflared
fi

sudo tee /etc/systemd/system/cloudflared-proxy-dns.service > /dev/null <<EOF
[Unit]
Description=DNS over HTTPS proxy
Wants=network-online.target nss-lookup.target
Before=nss-lookup.target

[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
DynamicUser=yes
ExecStart=/usr/bin/cloudflared proxy-dns

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cloudflared-proxy-dns

sudo rm -f /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
sudo chattr +i /etc/resolv.conf

