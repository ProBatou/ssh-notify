#!/bin/bash

source /etc/ssh-notify.conf

# Config {

DATE=$(date +"%d/%m/%Y")
HEURE=$(date +"%H:%M:%S")
IP=$(echo $SSH_CLIENT | awk '{print $1}')
TOPIC="SSH"
MESSAGE="👤 Utilisateur: $(whoami) "$'\n'"🖥 Host: $(hostname) "$'\n'"🌐 IP: $IP "$'\n'"📆 Date: $DATE "$'\n'"🕙 Heure: $HEURE"

#~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ }

  curl -i --silent \
    -u $USERNAME:$PASSWORD \
    -H "Title: SSH connection" \
    -d " $MESSAGE" \
    $NTFY/$TOPIC > /dev/null
