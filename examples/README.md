# Private setup

Run these commands from the repository root. The examples contain placeholders,
not usable credentials. Use private directories outside the checkout; retain these
inputs for every later apply. Domains, SSH addresses and credentials belong only there.

## Controller and Pillar

```sh
umask 077
MATRIX_PILLAR="$HOME/.config/matrix-salt/pillar"
MATRIX_CONTROLLER="$HOME/.config/matrix-salt/controller"
MATRIX_SALT_VENV="$HOME/.cache/matrix-salt/salt-venv"
mkdir -p "$MATRIX_PILLAR" "$MATRIX_CONTROLLER"
cp -a examples/pillar/. "$MATRIX_PILLAR/"
cp controller/master.example "$MATRIX_CONTROLLER/master"
mkdir -p "$MATRIX_PILLAR/hosts/matrix/secrets" "$MATRIX_PILLAR/hosts/livekit/secrets"
chmod -R go-rwx "$MATRIX_PILLAR" "$MATRIX_CONTROLLER"
```

Run the copies only on initial setup; they overwrite existing settings. In the private
`master`, replace every `/ABSOLUTE/...` path with your checkout, Pillar, normal SSH config,
and private controller-runtime paths. The runtime directory must also be outside the
checkout and protected with mode `0700`; private files use `0600`. Remove private
controller caches/logs when a run finishes if you do not need to retain them.

Edit `hosts/matrix/settings.sls` and `hosts/livekit/settings.sls`: choose your domains,
LiveKit public IP, TLS host lists and passwords. Matrix's SFU URL must match the
LiveKit signaling domain. Keep the role labels and SSH aliases `matrix` and `livekit`.
On a fresh deployment use the example Redis volume name; preserve an existing volume
name if adopting data. Matrix `server.name` becomes part of every Matrix user ID.

Use `openssl rand -hex 32` to generate a **different value for each** password,
secret and token placeholder. This also produces the required 64-character MAS
encryption key. Put the shared LiveKit API key/secret only in `rtc.sls`: both hosts
consume that one input. Database role passwords in Matrix settings supply initial
PostgreSQL environment files, existing-role reconciliation and application configs.
Use single-line hexadecimal values in the generated environment files. Preserve
MAS encryption and signing keys after initial setup.

## Signing keys

```sh
python3 -c 'import base64,secrets; print("ed25519 a_1", base64.b64encode(secrets.token_bytes(32)).decode().rstrip("="))' > "$MATRIX_PILLAR/hosts/matrix/secrets/synapse_signing.key"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$MATRIX_PILLAR/hosts/matrix/secrets/mas_signing.key"
```

Run once for a fresh installation. Reuse existing signing keys when adopting data.

## ACME account keys

Stateless HTTP-01 requires each host's account key to match its configured thumbprint.
Download the officially selected acme.sh version into your private directory:

```sh
MATRIX_ACME_VERSION=$(python3 -c 'import json; print(json.load(open("versions.json"))["acme_sh"])')
curl -fsSL "https://raw.githubusercontent.com/acmesh-official/acme.sh/$MATRIX_ACME_VERSION/acme.sh" -o "$MATRIX_PILLAR/acme.sh"
```

Run the following once with `MATRIX_ROLE=matrix`, then repeat with
`MATRIX_ROLE=livekit`. Account registration contacts Let's Encrypt and reports
`ACCOUNT_THUMBPRINT`; copy that value into the role's `tls.acme_account_thumbprint`.

```sh
MATRIX_ROLE=matrix
sh "$MATRIX_PILLAR/acme.sh" --register-account --server letsencrypt --home "$MATRIX_PILLAR/acme/$MATRIX_ROLE"
cp "$MATRIX_PILLAR/acme/$MATRIX_ROLE/ca/acme-v02.api.letsencrypt.org/directory/account.key" "$MATRIX_PILLAR/hosts/$MATRIX_ROLE/secrets/acme-account.key"
```

Salt installs the matching account key before certificate issuance. DNS and public
TCP 80 must work. Keep account keys and thumbprints together on subsequent applies.

## Salt and operation

```sh
MATRIX_SALT_VERSION=$(python3 -c 'import json; print(json.load(open("versions.json"))["salt_controller"])')
python3 -m venv "$MATRIX_SALT_VENV"
"$MATRIX_SALT_VENV/bin/pip" install "salt==$MATRIX_SALT_VERSION"
export PATH="$MATRIX_SALT_VENV/bin:$PATH"
```

Use the standard `salt-ssh` highstate commands in the root README. The controller
reads your standard `~/.ssh/config`.
Services use Alvistack's Podman repository and HAProxy Technologies' repository.
Salt compilation/startup failures must be resolved before considering a rollout complete.
Verify zero-change reapplication and application/public health after deploying.

Read deployment metadata:

```sh
ssh matrix cat /home/ubuntu/salt_config/deploy-state/activation.json
ssh livekit cat /home/ubuntu/salt_config/deploy-state/activation.json
```

Issue a one-use token valid for seven days (the command prints the token):

```sh
ssh matrix 'podman exec salt-mas /usr/local/bin/mas-cli --config=/config.yaml --config=/secrets.json --config=/mas-runtime.yaml manage issue-user-registration-token --usage-limit=1 --expires-in=604800'
```

Tokens are not revocable through this CLI. Keep the token and all private inputs out
of Git, chat transcripts and public logs. Neither a Salt success nor active systemd
units prove an authenticated media call works; verify with compatible clients.
