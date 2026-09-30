#!/bin/bash

# Release-managed by GitHub Actions.

ssh_notify_validate_config() {
    local errors=0

    if [[ -z ${NTFY:-} ]]; then
        printf 'error: NTFY is required\n' >&2
        errors=1
    elif [[ ! $NTFY =~ ^https?://[^[:space:]]+$ ]]; then
        printf 'error: NTFY must be an http:// or https:// URL\n' >&2
        errors=1
    fi

    if [[ -z ${TOPIC:-} ]]; then
        printf 'error: TOPIC is required\n' >&2
        errors=1
    elif [[ $TOPIC == *[[:space:]/]* ]]; then
        printf 'error: TOPIC must not contain whitespace or slashes\n' >&2
        errors=1
    fi

    if { [[ -n ${USERNAME:-} ]] && [[ -z ${PASSWORD:-} ]]; } ||
        { [[ -z ${USERNAME:-} ]] && [[ -n ${PASSWORD:-} ]]; }; then
        printf 'error: USERNAME and PASSWORD must both be set or both be empty\n' >&2
        errors=1
    fi

    return "$errors"
}

ssh_notify_load_config() {
    local config_file=$1

    if [[ ! -r $config_file ]]; then
        printf 'error: cannot read configuration file: %s\n' "$config_file" >&2
        return 1
    fi

    # shellcheck disable=SC1090
    source "$config_file" || {
        printf 'error: could not load configuration file: %s\n' "$config_file" >&2
        return 1
    }

    ssh_notify_validate_config
}

ssh_notify_curl() {
    curl "$@"
}

ssh_notify_send() {
    local config_file=$1
    local NTFY='' USERNAME='' PASSWORD='' TOPIC='SSH'
    local ip message date_now time_now
    local -a auth=()

    ssh_notify_load_config "$config_file" || return 1

    if [[ -n $USERNAME ]]; then
        auth=(--user "$USERNAME:$PASSWORD")
    fi

    if [[ -n ${SSH_CONNECTION:-} ]]; then
        ip=${SSH_CONNECTION%% *}
    else
        ip=${SSH_CLIENT%% *}
    fi

    date_now=$(date +'%d/%m/%Y')
    time_now=$(date +'%H:%M:%S')
    message="User: $(whoami)"$'\n'"Host: $(hostname)"$'\n'"IP: $ip"$'\n'"Date: $date_now"$'\n'"Time: $time_now"

    ssh_notify_curl --silent --connect-timeout 1 --max-time 2 \
        "${auth[@]}" \
        --header 'Title: SSH connection' \
        --data "$message" \
        "${NTFY%/}/$TOPIC" >/dev/null 2>&1
}

ssh_notify_handle_login() {
    local config_file=${1:-/etc/ssh-notify.conf}

    if { [[ -n ${SSH_CONNECTION:-} ]] || [[ -n ${SSH_CLIENT:-} ]]; } &&
        [[ ${SSH_NOTIFY_SENT:-} != 1 ]]; then
        # Child shells inherit the marker, so there is at most one attempt.
        export SSH_NOTIFY_SENT=1
        ssh_notify_send "$config_file" >/dev/null 2>&1 || :
    fi

    # A skipped or failed notification must not affect profile startup.
    return 0
}

ssh_notify_check_config() {
    local config_file=${1:-/etc/ssh-notify.conf}
    local NTFY='' USERNAME='' PASSWORD='' TOPIC='SSH'

    if ! command -v curl >/dev/null 2>&1; then
        printf 'error: curl is required\n' >&2
        return 1
    fi

    if ssh_notify_load_config "$config_file"; then
        printf 'Configuration is valid: %s\n' "$config_file"
        return 0
    fi

    printf 'Configuration is invalid: %s\n' "$config_file" >&2
    return 1
}

ssh_notify_self_test() {
    local passed=0 failed=0 attempts=0 fake_status=0

    ssh_notify_load_config() {
        NTFY='https://ntfy.invalid'
        USERNAME='test-user'
        PASSWORD='test-password'
        TOPIC='SSH'
        ssh_notify_validate_config
    }

    ssh_notify_curl() {
        attempts=$((attempts + 1))
        return "$fake_status"
    }

    ssh_notify_test_case() {
        local name=$1 expected=$2 status=$3

        if [[ $attempts -eq $expected && $status -eq 0 ]]; then
            printf 'ok - %s\n' "$name"
            passed=$((passed + 1))
        else
            printf 'not ok - %s (expected %s attempt(s), got %s)\n' \
                "$name" "$expected" "$attempts"
            failed=$((failed + 1))
        fi
    }

    unset SSH_CLIENT SSH_CONNECTION SSH_TTY SSH_NOTIFY_SENT
    attempts=0
    ssh_notify_handle_login '/self-test/config'
    ssh_notify_test_case 'local context makes no attempt' 0 "$?"

    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    export SSH_TTY='/dev/pts/1'
    unset SSH_CLIENT SSH_NOTIFY_SENT
    attempts=0
    ssh_notify_handle_login '/self-test/config'
    ssh_notify_test_case 'SSH context makes one attempt' 1 "$?"

    unset SSH_TTY SSH_NOTIFY_SENT
    attempts=0
    ssh_notify_handle_login '/self-test/config'
    ssh_notify_test_case 'SSH without a TTY still notifies' 1 "$?"

    export SSH_CLIENT='192.0.2.10 54321 22'
    unset SSH_CONNECTION SSH_NOTIFY_SENT
    attempts=0
    ssh_notify_handle_login '/self-test/config'
    ssh_notify_handle_login '/self-test/config'
    ssh_notify_test_case 'inherited session guard prevents duplicates' 1 "$?"

    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    unset SSH_CLIENT SSH_NOTIFY_SENT
    attempts=0
    fake_status=7
    ssh_notify_handle_login '/self-test/config'
    ssh_notify_test_case 'failed delivery does not break shell logic' 1 "$?"
    fake_status=0

    unset SSH_CLIENT SSH_CONNECTION SSH_TTY SSH_NOTIFY_SENT
    attempts=0
    if bash -c 'source "$1"; reached=1; [[ $reached -eq 1 ]]' \
        bash "${BASH_SOURCE[0]}"; then
        ssh_notify_test_case 'sourcing does not exit the parent shell' 0 0
    else
        ssh_notify_test_case 'sourcing does not exit the parent shell' 0 1
    fi

    printf '\n%d passed, %d failed\n' "$passed" "$failed"
    [[ $failed -eq 0 ]]
}

ssh_notify_usage() {
    cat <<'EOF'
Usage: ssh-notify.sh OPTION [CONFIG_FILE]

Options:
  --check-config [FILE]  Validate FILE (default: /etc/ssh-notify.conf)
  --self-test            Run deterministic checks without network access
  --help                 Show this help

When sourced from /etc/profile.d, the script ignores positional parameters and
quietly attempts one notification per inherited SSH session.
EOF
}

ssh_notify_main() {
    case ${1:-} in
        --check-config)
            [[ $# -le 2 ]] || {
                printf 'error: --check-config accepts at most one file\n' >&2
                return 2
            }
            ssh_notify_check_config "${2:-/etc/ssh-notify.conf}"
            ;;
        --self-test)
            [[ $# -eq 1 ]] || {
                printf 'error: --self-test accepts no arguments\n' >&2
                return 2
            }
            ssh_notify_self_test
            ;;
        --help|-h)
            ssh_notify_usage
            ;;
        *)
            ssh_notify_usage >&2
            return 2
            ;;
    esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    ssh_notify_main "$@"
    exit $?
else
    ssh_notify_handle_login
fi
