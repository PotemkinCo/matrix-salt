# Private Pillar selects the server role; resource definitions remain shared.
base:
  '*':
{% if pillar['deployment']['role'] == 'matrix' %}
    - os
    - haproxy.ingress
{% elif pillar['deployment']['role'] == 'livekit' %}
    - livekit.svc
{% endif %}
