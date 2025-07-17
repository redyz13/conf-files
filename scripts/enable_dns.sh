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

if [[ -e /etc/resolv.conf ]]; then
    if lsattr /etc/resolv.conf | grep -q 'i'; then
        sudo chattr -i /etc/resolv.conf
    fi
    sudo rm -f /etc/resolv.conf
fi

echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null
sudo chattr +i /etc/resolv.conf

if ! command -v ufw &> /dev/null; then
    echo "Warning: ufw is not installed. Skipping firewall configuration."
    exit 0
fi

sudo ufw allow out on lo
sudo ufw allow out to 127.0.0.1 port 53 proto udp
sudo ufw allow out to 127.0.0.1 port 53 proto tcp
sudo ufw deny out to any port 53 proto udp
sudo ufw deny out to any port 53 proto tcp
sudo ufw allow out to ::1 port 53 proto udp
sudo ufw allow out to ::1 port 53 proto tcp
sudo ufw deny out to any port 53 proto udp
sudo ufw deny out to any port 53 proto tcp

