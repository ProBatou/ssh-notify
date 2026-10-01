#!/bin/bash

set -eu
[[ $EUID -eq 0 ]] || exit 1

config_file=$(mktemp)
trap 'rm -f -- "$config_file"' EXIT
printf '%s\n' \
    'NTFY="https://ntfy.invalid"' \
    'TOPIC="SSH"' \
    'USERNAME="private"' \
    'PASSWORD="secret-password-marker"' > "$config_file"
chmod 600 "$config_file"

runuser -u nobody -- test -r "$config_file" && exit 1
output=$(runuser -u nobody -- ./ssh-notify.sh --check-config "$config_file" 2>&1 || :)
[[ $output != *secret-password-marker* ]]
printf 'ok - non-root cannot read or disclose the protected configuration\n'
