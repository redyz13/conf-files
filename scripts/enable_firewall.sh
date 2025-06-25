#!/bin/bash

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo systemctl enable ufw
sudo systemctl start ufw

sudo ufw status verbose
systemctl is-enabled ufw
systemctl status ufw | grep Active

