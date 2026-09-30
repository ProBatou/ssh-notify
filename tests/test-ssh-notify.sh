#!/bin/bash

set -u

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT=$ROOT/ssh-notify.sh
FIXTURES=$ROOT/tests/fixtures
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

export PATH="$FIXTURES:$PATH"
export SSH_NOTIFY_TEST_LOG=$TEST_TMP/curl.log

pass=0
fail=0

source_script() {
    # Exercise the repository script without reading production credentials.
    # shellcheck disable=SC1090
    source <(sed "s|source /etc/ssh-notify.conf|source $FIXTURES/ssh-notify.conf|" "$SCRIPT")
}

attempts() {
    if [ -f "$SSH_NOTIFY_TEST_LOG" ]; then
        grep -c '^attempt$' "$SSH_NOTIFY_TEST_LOG" || :
    else
        printf '0\n'
    fi
}

check_case() {
    local name=$1
    local expected=$2
    shift 2
    : >"$SSH_NOTIFY_TEST_LOG"

    if (unset SSH_CLIENT SSH_CONNECTION SSH_TTY SSH_NOTIFY_SENT; "$@") &&
        [ "$(attempts)" -eq "$expected" ]; then
        printf 'ok - %s\n' "$name"
        pass=$((pass + 1))
    else
        printf 'not ok - %s (expected %s attempt(s), got %s)\n' \
            "$name" "$expected" "$(attempts)"
        fail=$((fail + 1))
    fi
}

local_shell() {
    source_script
}

code_server_shell() {
    export TERM=xterm-256color
    export VSCODE_IPC_HOOK_CLI=$TEST_TMP/code-server.sock
    source_script
}

ssh_with_tty() {
    export SSH_CLIENT='192.0.2.10 54321 22'
    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    export SSH_TTY=/dev/pts/1
    source_script
}

ssh_without_tty() {
    export SSH_CLIENT='192.0.2.10 54321 22'
    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    unset SSH_TTY
    source_script
}

ssh_client_only() {
    export SSH_CLIENT='192.0.2.10 54321 22'
    unset SSH_CONNECTION SSH_TTY
    source_script
}

ssh_with_child() {
    export SSH_CLIENT='192.0.2.10 54321 22'
    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    source_script
    bash -c "source '$SCRIPT'" 2>/dev/null
}

failed_delivery() {
    local started elapsed
    export SSH_CLIENT='192.0.2.10 54321 22'
    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    export SSH_NOTIFY_FAKE_DELAY=0.1 SSH_NOTIFY_FAKE_STATUS=7
    started=$(date +%s)
    source_script
    elapsed=$(($(date +%s) - started))
    [ "$elapsed" -lt 2 ] &&
        ! grep -Eq '^bad-(connect-timeout|max-time)$' "$SSH_NOTIFY_TEST_LOG"
}

source_keeps_parent_alive() {
    local reached=0
    source_script
    reached=1
    [ "$reached" -eq 1 ]
}

check_case 'local shell is ignored' 0 local_shell
check_case 'code-server/Codex-like local shell is ignored' 0 code_server_shell
check_case 'SSH session with TTY notifies once' 1 ssh_with_tty
check_case 'SSH session without TTY notifies once' 1 ssh_without_tty
check_case 'SSH_CLIENT alone identifies an SSH session' 1 ssh_client_only
check_case 'SSH child shell does not duplicate notification' 1 ssh_with_child
check_case 'failed delivery is bounded and harmless' 1 failed_delivery
check_case 'sourcing never terminates the parent shell' 0 source_keeps_parent_alive

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
