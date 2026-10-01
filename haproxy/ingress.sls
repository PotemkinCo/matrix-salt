{% set domain = pillar['matrix']['server']['name'] %}
include:
  - matrix.deploy
  - matrix.services
  - haproxy.bootstrap
  - haproxy.cert

salt-matrix-well-known-client:
  file.managed:
    - name: /etc/haproxy/well-known-client.json
    - contents: |
        {"m.homeserver":{"base_url":"https://{{ domain }}"},"org.matrix.msc2965.authentication":{"issuer":"https://{{ domain }}/","account":"https://{{ domain }}/account/"},"m.rtc_foci":[{"type":"livekit","livekit_service_url":"https://{{ domain }}"}],"org.matrix.msc4143.rtc_foci":[{"type":"livekit","livekit_service_url":"https://{{ domain }}"}]}
    - user: root
    - group: root
    - mode: '0644'

salt-matrix-well-known-server:
  file.managed:
    - name: /etc/haproxy/well-known-server.json
    - contents: |
        {"m.server":"{{ domain }}:443"}
    - user: root
    - group: root
    - mode: '0644'

salt-matrix-ingress-config:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg
    - source: salt://haproxy/matrix.cfg.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - check_cmd: /usr/sbin/haproxy -c -f
    - require:
      - pkg: salt-haproxy-package
      - file: salt-matrix-well-known-client
      - file: salt-matrix-well-known-server
      - cmd: salt-cert-installed

salt-matrix-discovery-stop-before-config:
  service.dead:
    - name: haproxy
    - require:
      - cmd: salt-cert-installed
    - prereq:
      - file: salt-matrix-well-known-client
      - file: salt-matrix-well-known-server

salt-matrix-ingress-stop-before-config:
  service.dead:
    - name: haproxy
    - require:
      - cmd: salt-cert-installed
      - file: salt-matrix-well-known-client
      - file: salt-matrix-well-known-server
    - prereq:
      - file: salt-matrix-ingress-config

salt-matrix-ingress-service:
  service.running:
    - name: haproxy
    - enable: true
    - require:
      - service: salt-matrix-ingress-stop-before-config
      - file: salt-matrix-ingress-config
      - file: salt-matrix-well-known-client
      - file: salt-matrix-well-known-server
