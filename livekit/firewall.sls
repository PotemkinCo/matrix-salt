# The LiveKit host admits incoming traffic by default. Only the two LiveKit backend listeners need
# explicit denies. UFW's own config files and service own activation.
{% set backend_ports = [7880, 5349] %}

salt-livekit-ufw-package:
  pkg.installed:
    - name: ufw

salt-livekit-ufw-ipv6:
  file.replace:
    - name: /etc/default/ufw
    - pattern: '^IPV6=.*$'
    - repl: 'IPV6=yes'
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

salt-livekit-ufw-default-incoming:
  file.replace:
    - name: /etc/default/ufw
    - pattern: '^DEFAULT_INPUT_POLICY=.*$'
    - repl: 'DEFAULT_INPUT_POLICY="ACCEPT"'
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

salt-livekit-ufw-enabled:
  file.replace:
    - name: /etc/ufw/ufw.conf
    - pattern: '^ENABLED=.*$'
    - repl: 'ENABLED=yes'
    - append_if_not_found: true
    - backup: false
    - require:
      - pkg: salt-livekit-ufw-package

{% for suffix, network in (('', '0.0.0.0/0'), ('6', '::/0')) %}
salt-livekit-ufw-user{{ suffix }}-rules:
  file.managed:
    - name: /etc/ufw/user{{ suffix }}.rules
    - source: salt://livekit/ufw-user.rules.j2
    - template: jinja
    - context:
        backend_ports: {{ backend_ports }}
        network: '{{ network }}'
    - user: root
    - group: root
    - mode: '0640'
    - require:
      - pkg: salt-livekit-ufw-package
{% endfor %}

salt-livekit-firewall-stop-before-config:
  service.dead:
    - name: ufw
    - require:
      - pkg: salt-livekit-ufw-package
    - prereq:
      - file: salt-livekit-ufw-ipv6
      - file: salt-livekit-ufw-default-incoming
      - file: salt-livekit-ufw-enabled
{% for suffix in ('', '6') %}
      - file: salt-livekit-ufw-user{{ suffix }}-rules
{% endfor %}

salt-livekit-firewall:
  service.running:
    - name: ufw
    - enable: true
    - require:
      - service: salt-livekit-firewall-stop-before-config
      - file: salt-livekit-ufw-ipv6
      - file: salt-livekit-ufw-default-incoming
      - file: salt-livekit-ufw-enabled
{% for suffix in ('', '6') %}
      - file: salt-livekit-ufw-user{{ suffix }}-rules
{% endfor %}
    - require_in:
      - service: salt-acme-bootstrap-service
