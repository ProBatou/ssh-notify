# ssh-notify

`ssh-notify` sends an [ntfy](https://ntfy.sh/) notification when an SSH login shell starts. It is a single Bash script loaded through `/etc/profile.d`, with one external configuration file.

The script recognizes SSH sessions through `SSH_CONNECTION` or `SSH_CLIENT`, including sessions without a TTY. It exports `SSH_NOTIFY_SENT` after the first attempt so inherited shells do not send duplicates. Local shells—including code-server and Codex terminals—are ignored. Delivery is best-effort, with a one-second connection timeout and a two-second total timeout, so ntfy failures do not block login.

## Requirements

- Linux with Bash and the `/etc/profile.d` login-shell model
- `curl`
- An ntfy server and, when required, account credentials

## Install

Download or clone a release, then run as root:

```bash
cp ssh-notify.sh /etc/profile.d/ssh-notify.sh
cp ssh-notify.conf.template /etc/ssh-notify.conf
chmod 644 /etc/profile.d/ssh-notify.sh
chmod 600 /etc/ssh-notify.conf
```

Edit `/etc/ssh-notify.conf`, then validate it:

```bash
/etc/profile.d/ssh-notify.sh --check-config
```

The next SSH login shell will attempt a notification. Existing SSH sessions that have already set `SSH_NOTIFY_SENT=1` will not send another.

## Configuration

The configuration is trusted Bash syntax and supports four variables:

| Variable | Meaning |
| --- | --- |
| `NTFY` | Required ntfy base URL, such as `https://ntfy.example.com` |
| `TOPIC` | Required topic name; defaults to `SSH` for compatibility |
| `USERNAME` | Basic-auth username; optional when anonymous publishing is allowed |
| `PASSWORD` | Basic-auth password; set together with `USERNAME` |

Basic authentication:

```bash
NTFY="https://ntfy.example.com"
TOPIC="SSH"
USERNAME="example-user"
PASSWORD="example-password"
```

Anonymous publishing:

```bash
NTFY="https://ntfy.example.com"
TOPIC="SSH"
USERNAME=""
PASSWORD=""
```

Keep the file owned by root and mode `600`; it may contain credentials. Existing configurations using `NTFY`, `USERNAME`, and `PASSWORD` remain valid because an omitted `TOPIC` defaults to `SSH`.

## Diagnostics

```bash
./ssh-notify.sh --help
./ssh-notify.sh --check-config [CONFIG_FILE]
./ssh-notify.sh --self-test
```

`--check-config` loads and validates the configuration without sending a notification or printing secrets. `--self-test` uses internal fakes: it never reads `/etc/ssh-notify.conf` and never contacts a network service.

If notifications do not arrive, validate the configuration, confirm `curl` is installed, verify the ntfy URL/topic and publish permissions, and check that `SSH_CONNECTION` or `SSH_CLIENT` exists in the login shell. Missing configuration, invalid configuration, and delivery errors are deliberately quiet during login; use `--check-config` for details.

## Update and uninstall

To update, replace `/etc/profile.d/ssh-notify.sh` with the script from the latest GitHub Release, preserve `/etc/ssh-notify.conf`, and run `--check-config` and `--self-test`.

To uninstall:

```bash
rm /etc/profile.d/ssh-notify.sh
# Optionally remove saved settings and credentials:
rm /etc/ssh-notify.conf
```

## Releases and contributions

Functional changes on `main` automatically pass ShellCheck, the built-in self-test, and whitespace checks before a SemVer GitHub Release is created. Releases attach `ssh-notify.sh` and `ssh-notify.conf.template`; GitHub also provides source archives. Documentation-only changes do not create releases. The latest release is suitable for consumers such as DebBuilder.

The default release increment is minor. Commit messages containing `fix:` or `[patch]` select a patch increment; `BREAKING CHANGE:`, a Conventional Commit `!`, or `[major]` selects a major increment. Contributions should stay focused, keep the utility small, and run the same three checks locally:

```bash
shellcheck ssh-notify.sh
./ssh-notify.sh --self-test
git diff --check
```

## Security and license

The configuration is sourced as Bash, so only root should be able to edit it. Use HTTPS for remote ntfy servers and a narrowly scoped account when authentication is required. Notification text includes the login user, host, source IP, and time.

Licensed under the [Apache License 2.0](LICENSE).
