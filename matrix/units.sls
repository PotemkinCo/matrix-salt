{% import_json "versions.json" as versions %}
{% set quadlet_dir = '/home/ubuntu/.config/containers/systemd' %}
{% set mounted_files = {
  'postgres': ('salt-release-postgres',),
  'mas': ('salt-deployment-environment', 'salt-secret-mas-secrets-json', 'salt-secret-mas-signing-key', 'salt-mas-runtime', 'salt-mas-environment', 'salt-release-mas'),
  'synapse': ('salt-deployment-environment', 'salt-secret-synapse-secrets-json', 'salt-secret-synapse-signing-key', 'salt-secret-lk-jwt-appservice-yaml', 'salt-synapse-runtime', 'salt-synapse-log-config', 'salt-release-synapse'),
  'lk-jwt': ('salt-deployment-environment', 'salt-secret-lk-jwt-secrets-env', 'salt-secret-lk-jwt-appservice-yaml')
} %}

salt-quadlet-directory:
  file.directory:
    - name: {{ quadlet_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - user: salt-operator

salt-pod-quiescent:
  user_service.dead:
    - name: salt-pod.service
    - user: ubuntu
    - timeout: 900
    - prereq:
      - file: salt-pod-quadlet
    - require:
      - service: salt-user-manager

salt-pod-quadlet:
  file.managed:
    - name: {{ quadlet_dir }}/salt.pod
    - source: salt://systemd/quadlet/salt.pod
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - require:
      - file: salt-quadlet-directory

{% for name in ('postgres', 'mas', 'synapse', 'lk-jwt') %}
salt-{{ name }}-quiescent:
  user_service.dead:
    - name: salt-{{ name }}.service
    - user: ubuntu
    - timeout: 900
    - prereq:
      - file: salt-quadlet-{{ name }}
{% for state in mounted_files[name] %}
      - file: {{ state }}
{% endfor %}
    - require:
      - service: salt-user-manager

salt-quadlet-{{ name }}:
  file.managed:
    - name: {{ quadlet_dir }}/salt-{{ name }}.container
    - source: salt://systemd/quadlet/salt-{{ name }}.container
    - template: jinja
    - context:
        image: {{ versions.images[name|replace('-', '_')] }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - follow_symlinks: false
    - require:
      - file: salt-quadlet-directory
      - file: salt-pod-quadlet
{% endfor %}
