# ssh-notify

`ssh-notify` sends an [ntfy](https://ntfy.sh/) notification when an SSH login shell starts. The Bash profile hook invokes a fixed privileged action from the same script so `/etc/ssh-notify.conf` can remain root-only.

The notification logic requires Bash. If another login shell sources `/etc/profile.d/ssh-notify.sh`, the script returns immediately and silently so profile startup can continue normally.

The script recognizes `SSH_CONNECTION` or `SSH_CLIENT`, including sessions without a TTY, and uses `SSH_NOTIFY_SENT` to prevent duplicates. The login hook passes only the source address on stdin to `sudo -n /etc/profile.d/ssh-notify.sh --send`. Credentials are read by the root process and passed to `curl` on stdin. Failures are silent and curl keeps its one-second connection and two-second total timeouts.

## Requirements

- Linux with Bash and the `/etc/profile.d` login-shell model
- `curl`
- `sudo`
- An ntfy server and, when required, account credentials

## Install

Download or clone a release, then run as root:

```bash
install -o root -g root -m 755 ssh-notify.sh /etc/profile.d/ssh-notify.sh
install -o root -g root -m 600 ssh-notify.conf.template /etc/ssh-notify.conf
install -o root -g root -m 440 ssh-notify.sudoers /etc/sudoers.d/ssh-notify
visudo -cf /etc/sudoers.d/ssh-notify
```

Edit `/etc/ssh-notify.conf`, then validate it:

```bash
sudo /etc/profile.d/ssh-notify.sh --check-config
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

Keep the file owned by `root:root` and mode `600`; it may contain credentials. Existing configurations remain valid and an omitted `TOPIC` still defaults to `SSH`.

### Upgrading from 6.1.1 or earlier

Preserve `/etc/ssh-notify.conf`, install the executable script and sudoers rule as shown above, then protect any previous mode-`644` configuration:

```bash
chown root:root /etc/ssh-notify.conf
chmod 600 /etc/ssh-notify.conf
```

Without the sudoers rule, login still succeeds but non-root notifications are skipped.

## Diagnostics

```bash
./ssh-notify.sh --help
sudo ./ssh-notify.sh --check-config [CONFIG_FILE]
./ssh-notify.sh --self-test
```

`--check-config` validates without sending or printing secrets; use root for the protected system configuration. `--self-test` never reads the system configuration or contacts the network.

If notifications do not arrive, validate the configuration, confirm `curl` is installed, verify the ntfy URL/topic and publish permissions, and check that `SSH_CONNECTION` or `SSH_CLIENT` exists in the login shell. Missing configuration, invalid configuration, and delivery errors are deliberately quiet during login; use `--check-config` for details.

## Update and uninstall

To update, replace `/etc/profile.d/ssh-notify.sh` and `/etc/sudoers.d/ssh-notify` with the files from the latest GitHub Release, preserve `/etc/ssh-notify.conf`, and run `--check-config` and `--self-test`.

To uninstall:

```bash
rm /etc/profile.d/ssh-notify.sh
rm /etc/sudoers.d/ssh-notify
# Optionally remove saved settings and credentials:
rm /etc/ssh-notify.conf
```

## Releases and contributions

Functional changes on `main` pass ShellCheck, tests, and whitespace checks before a SemVer release is created. Releases attach `ssh-notify.sh`, `ssh-notify.conf.template`, and `ssh-notify.sudoers`.

The default release increment is minor. Commit messages containing `fix:` or `[patch]` select a patch increment; `BREAKING CHANGE:`, a Conventional Commit `!`, or `[major]` selects a major increment. Contributions should stay focused, keep the utility small, and run the same three checks locally:

```bash
shellcheck ssh-notify.sh
./ssh-notify.sh --self-test
sudo ./tests/security-test.sh
git diff --check
```

## Security and license

The root-owned configuration is sourced as Bash. The sudoers rule authorizes only `ssh-notify.sh --send`, not arbitrary arguments or shell access. A local user can trigger extra fixed notifications, but cannot read the credentials or choose the endpoint or command. Use HTTPS and a narrowly scoped ntfy account.

Licensed under the [Apache License 2.0](LICENSE).
