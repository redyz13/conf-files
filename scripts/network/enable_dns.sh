#!/usr/bin/env bash
set -Eeuo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/bin"
export PATH

exec sudo /usr/local/sbin/dnscrypt-toggle "${1:-status}"
