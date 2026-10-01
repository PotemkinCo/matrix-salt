# Managed application files are written in place; unchanged content is a no-op.
{% set data_dir = "/home/ubuntu/salt_config" %}

salt-release-directory:
  file.directory:
    - name: {{ data_dir }}/current
    - user: ubuntu
    - group: ubuntu
    - mode: '0755'
    - makedirs: true

salt-release-synapse:
  file.managed:
    - name: {{ data_dir }}/current/matrix/synapse/homeserver.yaml
    - source: salt://matrix/synapse/homeserver.yaml
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - makedirs: true
    - require:
      - file: salt-release-directory

salt-release-mas:
  file.managed:
    - name: {{ data_dir }}/current/matrix/mas/config.yaml
    - source: salt://matrix/mas/config.yaml
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - makedirs: true
    - require:
      - file: salt-release-directory

salt-release-postgres:
  file.managed:
    - name: {{ data_dir }}/current/postgres/init-databases.sql
    - source: salt://postgres/init-databases.sql
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - makedirs: true
    - require:
      - file: salt-release-directory
