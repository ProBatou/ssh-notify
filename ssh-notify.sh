#!/bin/bash

# Release-managed by GitHub Actions

# SSH_CONNECTION and SSH_CLIENT are set by sshd for the entire session,
# including sessions without a TTY. Local profile shells set neither.
if { [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; } &&
    [ "${SSH_NOTIFY_SENT:-}" != "1" ]; then
    # Child shells inherit this marker and do not send duplicate notifications.
    export SSH_NOTIFY_SENT=1

    # Configuration is external and may be unavailable; notification delivery
    # must never make shell startup fail.
    # shellcheck disable=SC1091
    if source /etc/ssh-notify.conf 2>/dev/null; then
        DATE=$(date +"%d/%m/%Y")
        HEURE=$(date +"%H:%M:%S")
        TOPIC="SSH"

        if [ -n "${SSH_CONNECTION:-}" ]; then
            IP=${SSH_CONNECTION%% *}
        else
            IP=${SSH_CLIENT%% *}
        fi

        MESSAGE="👤 Utilisateur: $(whoami) "$'\n'"🖥 Host: $(hostname) "$'\n'"🌐 IP: $IP "$'\n'"📆 Date: $DATE "$'\n'"🕙 Heure: $HEURE"

        curl --silent \
            --connect-timeout 1 \
            --max-time 2 \
            --user "${USERNAME:-}:${PASSWORD:-}" \
            --header "Title: SSH connection" \
            --data " $MESSAGE" \
            "${NTFY:-}/$TOPIC" >/dev/null 2>&1 || :
    fi
fi

# Keep a failed or skipped notification from becoming the profile's status.
:
