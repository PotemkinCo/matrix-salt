matrix:
  synapse:
    message_per_second: 100
    message_burst: 100
    room_creation_per_second: 5
    room_creation_burst: 10
    http_log_level: INFO
    http_client_log_level: INFO
  mas:
    rust_log: info,mas=info
    login_per_ip_burst: 20
    login_per_ip_per_second: 1.0
    login_per_account_burst: 10
    login_per_account_per_second: 0.5
    registration_burst: 10
    registration_per_second: 0.5
