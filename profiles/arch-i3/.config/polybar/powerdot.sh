#!/bin/bash
MODE_FILE="/etc/tlp.d/99-mode.conf"
if grep -q "TLP_DEFAULT_MODE=BAT" "$MODE_FILE" 2>/dev/null; then
  printf ""
else
  printf ""
fi

