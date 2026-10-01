{% import_json "versions.json" as versions %}
{% set livekit = pillar["livekit"] %}
{% set commit = pillar["deployment"].get("commit", "") %}
{% set data_dir = "/home/ubuntu/salt_config/livekit" %}
{% set quadlet_dir = "/home/ubuntu/.config/containers/systemd" %}
{% if commit is not string or commit|length != 40 or commit|reject("in", "0123456789abcdef")|list|length > 0 %}
  {{ salt["test.raise_exception"]("ValueError", "pillar deployment.commit must be a full lowercase Git commit id") }}
{% endif %}
{% set activation = {
  "status": "succeeded",
  "commit": commit,
  "images": {
    "LIVEKIT_IMAGE": versions.images.livekit,
    "REDIS_IMAGE": versions.images.redis
  }
} %}
{% set quadlet_images = {
  "salt-livekit.container": versions.images.livekit,
  "salt-livekit-redis.container": versions.images.redis
} %}

include:
  - livekit.firewall
  - haproxy.bootstrap
  - haproxy.cert
  - os.access
  - os.rootless

salt-livekit-data-directory:
  file.directory:
    - name: /home/ubuntu/salt_config
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - user: salt-operator

salt-livekit-configuration-directory:
  file.directory:
    - name: {{ data_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - file: salt-livekit-data-directory

salt-livekit-deploy-state-directory:
  file.directory:
    - name: /home/ubuntu/salt_config/deploy-state
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - file: salt-livekit-data-directory

salt-livekit-quadlet-directory:
  file.directory:
    - name: {{ quadlet_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true

salt-livekit-redis-config:
  file.managed:
    - name: {{ data_dir }}/redis.conf
    - source: salt://livekit/redis.conf.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0444'
    - show_changes: false
    - require:
      - file: salt-livekit-configuration-directory

salt-livekit-redis-health-environment:
  file.managed:
    - name: {{ data_dir }}/redis-health.env
    - source: salt://livekit/redis-health.env.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - show_changes: false
    - require:
      - file: salt-livekit-configuration-directory

salt-livekit-config:
  file.managed:
    - name: {{ data_dir }}/livekit.yaml
    - source: salt://livekit/config.yaml.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0444'
    - show_changes: false
    - require:
      - file: salt-livekit-configuration-directory

{% for name in ("salt-livekit.container", "salt-livekit-redis.container", "salt-livekit-redis-data.volume") %}
salt-livekit-quadlet-{{ name|replace(".", "-") }}:
  file.managed:
    - name: {{ quadlet_dir }}/{{ name }}
    - source: salt://systemd/quadlet/{{ name }}
    - template: jinja
{% if name in quadlet_images %}
    - context:
        image: {{ quadlet_images[name] }}
{% endif %}
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - require:
      - file: salt-livekit-quadlet-directory
{% endfor %}

salt-livekit-redis-stop-before-config:
  user_service.dead:
    - name: salt-livekit-redis.service
    - user: ubuntu
    - timeout: 40
    - require:
      - service: salt-user-manager
    - prereq:
      - file: salt-livekit-redis-config
      - file: salt-livekit-redis-health-environment
      - file: salt-livekit-quadlet-salt-livekit-redis-container
      - file: salt-livekit-quadlet-salt-livekit-redis-data-volume

salt-livekit-stop-before-config:
  user_service.dead:
    - name: salt-livekit.service
    - user: ubuntu
    - timeout: 140
    - require:
      - service: salt-user-manager
    - prereq:
      - file: salt-livekit-config
      - file: salt-livekit-quadlet-salt-livekit-container

salt-livekit-redis-running:
  user_service.running:
    - name: salt-livekit-redis.service
    - user: ubuntu
    - timeout: 960
    - require:
      - user_service: salt-livekit-redis-stop-before-config
      - service: salt-user-manager
      - service: salt-livekit-firewall
      - file: salt-livekit-redis-config
      - file: salt-livekit-redis-health-environment
      - file: salt-livekit-quadlet-salt-livekit-redis-container
      - file: salt-livekit-quadlet-salt-livekit-redis-data-volume

salt-livekit-running:
  user_service.running:
    - name: salt-livekit.service
    - user: ubuntu
    - timeout: 960
    - require:
      - user_service: salt-livekit-redis-running
      - user_service: salt-livekit-stop-before-config
      - service: salt-user-manager
      - service: salt-livekit-firewall
      - file: salt-livekit-config
      - file: salt-livekit-quadlet-salt-livekit-container

salt-livekit-haproxy-config:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg
    - source: salt://haproxy/livekit.cfg.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - check_cmd: /usr/sbin/haproxy -c -f
    - require:
      - pkg: salt-haproxy-package
      - cmd: salt-cert-installed
      - user_service: salt-livekit-running

salt-livekit-haproxy-stop-before-config:
  service.dead:
    - name: haproxy
    - require:
      - cmd: salt-cert-installed
    - prereq:
      - file: salt-livekit-haproxy-config

salt-livekit-haproxy-service:
  service.running:
    - name: haproxy
    - enable: true
    - require:
      - service: salt-livekit-haproxy-stop-before-config
      - file: salt-livekit-haproxy-config

salt-activation:
  file.serialize:
    - name: /home/ubuntu/salt_config/deploy-state/activation.json
    - serializer: json
    - dataset: {{ activation | tojson }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - makedirs: true
    - show_changes: false
    - require:
      - file: salt-livekit-deploy-state-directory
      - user_service: salt-livekit-redis-running
      - user_service: salt-livekit-running
      - service: salt-livekit-haproxy-service
