#!/bin/bash

CLIENT_IP="$1"
PORT=22

get_all_ssh_rule_numbers() {
  sudo ufw status numbered | grep "$PORT" | awk -F'[][]' '{print $2}' | tac
}

get_matching_rule_numbers() {
  sudo ufw status numbered | grep "$CLIENT_IP" | grep "$PORT" | awk -F'[][]' '{print $2}' | tac
}

delete_rules() {
  for num in "$@"; do
    sudo ufw --force delete "$num"
  done
}

rule_exists_for_ip() {
  [[ $(get_matching_rule_numbers | wc -l) -gt 0 ]]
}

enable_ssh() {
  echo "Enabling SSH for $CLIENT_IP on port $PORT..."
  sudo systemctl start sshd
  if ! rule_exists_for_ip; then
    sudo ufw allow from "$CLIENT_IP" to any port "$PORT" proto tcp
    echo "SSH rule added."
  else
    echo "SSH rule already exists, skipping."
  fi
}

disable_ssh_for_ip() {
  echo "Disabling SSH for $CLIENT_IP on port $PORT..."
  delete_rules $(get_matching_rule_numbers)
  sudo systemctl stop sshd
  echo "SSH disabled."
}

disable_all_ssh() {
  echo "Disabling ALL SSH access on port $PORT..."
  delete_rules $(get_all_ssh_rule_numbers)
  sudo systemctl stop sshd
  echo "All SSH access disabled."
}

if [[ -z "$CLIENT_IP" ]]; then
  disable_all_ssh
elif rule_exists_for_ip; then
  disable_ssh_for_ip
else
  enable_ssh
fi

