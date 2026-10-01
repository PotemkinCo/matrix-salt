deployment:
  role: matrix
tls:
  cert_name: matrix
  hosts: [matrix.example.org]
  acme_account_thumbprint: REPLACE_WITH_ACCOUNT_THUMBPRINT
matrix:
  server:
    name: matrix.example.org
  salt:
    target: matrix
  livekit:
    sfu_url: wss://livekit.example.org
  role_passwords:
    postgres: REPLACE_WITH_RANDOM_PASSWORD
    synapse: REPLACE_WITH_RANDOM_PASSWORD
    mas: REPLACE_WITH_RANDOM_PASSWORD
  credentials:
    shared_secret: REPLACE_WITH_RANDOM_SECRET
    form_secret: REPLACE_WITH_RANDOM_SECRET
    macaroon_secret_key: REPLACE_WITH_RANDOM_SECRET
    mas_encryption: REPLACE_WITH_64_HEX_CHARACTERS
    as_token: REPLACE_WITH_RANDOM_TOKEN
    hs_token: REPLACE_WITH_RANDOM_TOKEN
