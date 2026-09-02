#!/bin/bash

# Release-managed by GitHub Actions
source /etc/ssh-notify.conf

# Config {

DATE=$(date +"%d/%m/%Y")
HEURE=$(date +"%H:%M:%S")
IP=$(echo $SSH_CLIENT | awk '{print $1}')
TOPIC="SSH"

#~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ }

# Check if $SSH_TTY is set (SSH connection)
if [ -n "$SSH_TTY" ]; then
    MESSAGE="👤 Utilisateur: $(whoami) "$'\n'"🖥 Host: $(hostname) "$'\n'"🌐 IP: $IP "$'\n'"📆 Date: $DATE "$'\n'"🕙 Heure: $HEURE"
else
    # For local connections (novnc, xterm, etc.)
    MESSAGE="👤 Utilisateur: $(whoami) "$'\n'"🖥 Host: $(hostname) "$'\n'"🌐 IP: local "$'\n'"📆 Date: $DATE "$'\n'"🕙 Heure: $HEURE"
fi

  curl -i --silent \
    -u $USERNAME:$PASSWORD \
    -H "Title: SSH connection" \
    -d " $MESSAGE" \
    $NTFY/$TOPIC > /dev/null 2>&1
