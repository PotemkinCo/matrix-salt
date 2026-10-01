deployment:
  role: livekit
tls:
  cert_name: livekit
  hosts: [livekit.example.org, turn.example.org]
  acme_account_thumbprint: REPLACE_WITH_ACCOUNT_THUMBPRINT
livekit:
  signaling_host: livekit.example.org
  turn_host: turn.example.org
  node_ip: 203.0.113.10
  redis_volume: salt-livekit-redis-data
  credentials:
    REDIS_PASSWORD: REPLACE_WITH_RANDOM_PASSWORD
