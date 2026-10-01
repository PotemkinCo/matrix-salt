# Matrix + MAS + calls, with Salt-SSH

Synapse, Matrix Authentication Service, PostgreSQL and MatrixRTC JWT on `matrix`;
LiveKit and Redis on `livekit`. Containers use rootless Podman/Quadlet, HAProxy
provides HTTPS/TURN TLS, and acme.sh renews certificates. Standard Salt-SSH applies
configuration without a resident Salt agent. Versions and images are in `versions.json`.

## Requirements

- Two separate **Ubuntu 24.04 amd64** servers with Python 3, SSH key access as
  `ubuntu`, passwordless sudo and trusted host keys. Define `matrix` and `livekit`
  in your standard `~/.ssh/config`.
- DNS for the Matrix domain pointing to `matrix`, and signaling/TURN domains
  pointing to `livekit`. Publish AAAA records only when IPv6 works.
- Both hosts: TCP 80/443. Matrix: UDP 443. LiveKit: TCP 7881 and UDP 3478,
  30000–40000, 50000–60000. Restrict SSH at the external firewall.
- Operator computer: Git, Python 3.11+, OpenSSH, OpenSSL and curl. Install the Salt
  version from `versions.json` using the [setup instructions](examples/README.md).

## Apply

Prepare the private controller, Pillar, credentials and keys using
[examples/README.md](examples/README.md). Keep them outside this checkout. Set
`MATRIX_CONTROLLER` and `MATRIX_PILLAR` to their absolute directories. From a clean
checkout, record its commit in private Pillar, then preview and apply both roles:

```sh
(
  set -e
  test -z "$(git status --porcelain --untracked-files=all)"
  printf 'deployment:\n  commit: %s\n' "$(git rev-parse HEAD)" > "$MATRIX_PILLAR/deployment.sls"
  salt-ssh -c "$MATRIX_CONTROLLER" --sudo --wipe livekit state.highstate test=True
  salt-ssh -c "$MATRIX_CONTROLLER" --sudo --wipe matrix state.highstate test=True
  salt-ssh -c "$MATRIX_CONTROLLER" --sudo --wipe livekit state.highstate
  salt-ssh -c "$MATRIX_CONTROLLER" --sudo --wipe matrix state.highstate
)
```

Configuration changes stop affected services before writing and start them afterward.
Unchanged inputs should make zero changes; later applies restart stopped services.
Salt writes the applied commit and image references to each host's private activation
record. Preserve private inputs, signing keys and persistent application data.

Issue a one-use registration token as shown in the setup guide, register at
`https://<matrix-domain>/register`, then verify sign-in and calls between two accounts
on different networks. This repository has not been verified on fresh servers.

## Scope

Federation, email delivery and password recovery are disabled. Registration requires
an operator-issued token. No Element Web frontend, backups or monitoring are installed.
LiveKit UFW allows incoming traffic by default and denies backend TCP 7880/5349;
Salt owns its user rule files. The operator uses the fixed generic account `ubuntu`.
The retained `user_service` modules let Salt manage its systemd user services.
Controller caches/logs and Salt test output may contain secrets; keep them private.
Image tags are mutable, and failed certificate name changes can require intervention.

Apache-2.0; upstream module attribution is in `NOTICE`.
