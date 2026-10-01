#!/bin/bash

# Release-managed by GitHub Actions.

# /etc/profile.d files may be sourced by non-Bash login shells. Return before
# they have to parse any of the Bash syntax below.
if [ -z "${BASH_VERSION:-}" ]; then
    # shellcheck disable=SC2317 # Used when a non-Bash shell executes the file.
    return 0 2>/dev/null || exit 0
fi

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

    # Suppress output so a broken configuration cannot disclose a value.
    # shellcheck disable=SC1090
    source "$config_file" >/dev/null 2>&1 || {
        printf 'error: could not load configuration file: %s\n' "$config_file" >&2
        return 1
    }

    ssh_notify_validate_config
}

ssh_notify_curl() {
    curl "$@"
}

ssh_notify_curl_config_escape() {
    local value=$1

    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\r'/\\r}
    value=${value//$'\n'/\\n}
    printf '%s' "$value"
}

ssh_notify_send() {
    local config_file=$1 ip=$2 login_user=$3
    local NTFY='' USERNAME='' PASSWORD='' TOPIC='SSH'
    local message date_now time_now curl_config=''

    ssh_notify_load_config "$config_file" || return 1

    if [[ -n $USERNAME ]]; then
        printf -v curl_config 'user = "%s:%s"\n' \
            "$(ssh_notify_curl_config_escape "$USERNAME")" \
            "$(ssh_notify_curl_config_escape "$PASSWORD")"
    fi

    date_now=$(date +'%d/%m/%Y')
    time_now=$(date +'%H:%M:%S')
    message="User: $login_user"$'\n'"Host: $(hostname)"$'\n'"IP: $ip"$'\n'"Date: $date_now"$'\n'"Time: $time_now"

    # Credentials are supplied on stdin, never in curl's argv or environment.
    ssh_notify_curl --disable --config - --silent --connect-timeout 1 --max-time 2 \
        --header 'Title: SSH connection' \
        --data "$message" \
        "${NTFY%/}/$TOPIC" <<< "$curl_config"
}

ssh_notify_helper_send() {
    local ip
    [[ $EUID -eq 0 ]] || return 1
    PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    export PATH
    IFS= read -r ip || return 1
    [[ $ip =~ ^[0-9A-Fa-f:.]+$ && ${#ip} -le 45 ]] || return 1
    ssh_notify_send '/etc/ssh-notify.conf' "$ip" "${SUDO_USER:-$(id -un)}"
}

ssh_notify_run_helper() {
    local ip=$1 script_file=${BASH_SOURCE[0]}

    if [[ $EUID -eq 0 ]]; then
        printf '%s\n' "$ip" | "$script_file" --send
    else
        printf '%s\n' "$ip" | sudo -n -- "$script_file" --send
    fi
}

ssh_notify_handle_login() {
    local ip

    if { [[ -n ${SSH_CONNECTION:-} ]] || [[ -n ${SSH_CLIENT:-} ]]; } &&
        [[ ${SSH_NOTIFY_SENT:-} != 1 ]]; then
        # Child shells inherit the marker, so there is at most one attempt.
        export SSH_NOTIFY_SENT=1
        if [[ -n ${SSH_CONNECTION:-} ]]; then
            ip=${SSH_CONNECTION%% *}
        else
            ip=${SSH_CLIENT%% *}
        fi
        ssh_notify_run_helper "$ip" >/dev/null 2>&1 || :
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
    local passed=0 failed=0 attempts=0 fake_status=0 anonymous=0
    local curl_args='' curl_input='' output status

    ssh_notify_load_config() {
        NTFY='https://ntfy.invalid'
        TOPIC='SSH'
        if [[ $anonymous -eq 1 ]]; then
            USERNAME=''
            PASSWORD=''
        else
            USERNAME='test-user'
            PASSWORD='secret-password-marker'
        fi
    }

    ssh_notify_curl() {
        attempts=$((attempts + 1))
        curl_args=$*
        curl_input=$(cat)
        return "$fake_status"
    }

    ssh_notify_run_helper() {
        attempts=$((attempts + 1))
        return "$fake_status"
    }

    ssh_notify_test_case() {
        local name=$1 expected=$2 actual=$3
        if [[ $expected == "$actual" ]]; then
            printf 'ok - %s\n' "$name"
            passed=$((passed + 1))
        else
            printf 'not ok - %s\n' "$name"
            failed=$((failed + 1))
        fi
    }

    unset SSH_CLIENT SSH_CONNECTION SSH_TTY SSH_NOTIFY_SENT
    attempts=0
    ssh_notify_handle_login
    ssh_notify_test_case 'local context makes no attempt' 0 "$attempts"

    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    unset SSH_CLIENT SSH_NOTIFY_SENT
    attempts=0
    ssh_notify_handle_login
    ssh_notify_test_case 'SSH context makes one helper attempt' 1 "$attempts"

    export SSH_CLIENT='192.0.2.10 54321 22'
    unset SSH_CONNECTION SSH_NOTIFY_SENT
    attempts=0
    ssh_notify_handle_login
    ssh_notify_handle_login
    ssh_notify_test_case 'SSH_CLIENT without TTY notifies only once' 1 "$attempts"

    export SSH_CONNECTION='192.0.2.10 54321 192.0.2.20 22'
    unset SSH_CLIENT SSH_NOTIFY_SENT
    attempts=0
    fake_status=7
    ssh_notify_handle_login
    status=$?
    ssh_notify_test_case 'helper failure does not break login' '0:1' "$status:$attempts"
    fake_status=0

    anonymous=1
    attempts=0
    ssh_notify_send '/self-test/config' '192.0.2.10' 'alice'
    ssh_notify_test_case 'anonymous configuration sends' '1:' "$attempts:$curl_input"

    anonymous=0
    attempts=0
    ssh_notify_send '/self-test/config' '192.0.2.10' 'alice'
    if [[ $curl_input == *secret-password-marker* && $curl_args != *secret-password-marker* ]]; then status=0; else status=1; fi
    ssh_notify_test_case 'password stays out of curl argv' 0 "$status"

    output=$(ssh_notify_check_config '/self-test/config' 2>&1)
    if [[ $output != *secret-password-marker* ]]; then status=0; else status=1; fi
    ssh_notify_test_case '--check-config hides credentials' 0 "$status"

    unset SSH_CLIENT SSH_CONNECTION SSH_TTY SSH_NOTIFY_SENT
    if bash -c 'source "$1"; reached=1; [[ $reached -eq 1 ]] &&
        [[ -z $(compgen -A function ssh_notify_) ]]' \
        bash "${BASH_SOURCE[0]}"; then
        status=0
    else
        status=1
    fi
    ssh_notify_test_case 'Bash sourcing leaves a clean namespace' 0 "$status"

    output=$(/bin/sh -c '. "$1"; printf PROFILE_OK' sh "${BASH_SOURCE[0]}")
    ssh_notify_test_case 'non-Bash profile sourcing is ignored' PROFILE_OK "$output"

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
        --send)
            [[ $# -eq 1 ]] || return 2
            ssh_notify_helper_send
            ;;
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
    unset -f ssh_notify_validate_config ssh_notify_load_config \
        ssh_notify_curl ssh_notify_curl_config_escape ssh_notify_send \
        ssh_notify_helper_send ssh_notify_run_helper ssh_notify_handle_login \
        ssh_notify_check_config ssh_notify_self_test ssh_notify_usage \
        ssh_notify_main 2>/dev/null || :
fi
