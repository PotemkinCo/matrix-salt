{% set vars = pillar["matrix"] %}
{% set server = vars["server"] %}
{% set mas = vars["mas"] %}
{% set target = vars["salt"]["target"] %}
{% set data_dir = "/home/ubuntu/salt_config" %}
{% set runtime_dir = data_dir ~ "/runtime" %}
{% set secrets_dir = data_dir ~ "/secrets" %}
{% set deploy_state_dir = data_dir ~ "/deploy-state" %}

salt-data-directory:
  file.directory:
    - name: {{ data_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - makedirs: true
    - require:
      - user: salt-operator

salt-runtime-directory:
  file.directory:
    - name: {{ runtime_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - require:
      - file: salt-data-directory

salt-secrets-directory:
  file.directory:
    - name: {{ secrets_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - require:
      - file: salt-data-directory

salt-deploy-state-directory:
  file.directory:
    - name: {{ deploy_state_dir }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0700'
    - require:
      - file: salt-data-directory

salt-deployment-environment:
  file.managed:
    - name: {{ data_dir }}/salt-deployment.env
    - contents: |
        SALT_DATA_DIR={{ data_dir }}
        SERVER_NAME={{ server["name"] }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - show_changes: false
    - require:
      - user: salt-operator

salt-synapse-runtime:
  file.managed:
    - name: {{ runtime_dir }}/synapse.runtime.yaml
    - source: salt://matrix/synapse/runtime.yaml.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - show_changes: false
    - require:
      - file: salt-runtime-directory

salt-synapse-log-config:
  file.managed:
    - name: {{ runtime_dir }}/synapse.log.config
    - source: salt://matrix/synapse/log.config.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - show_changes: false
    - require:
      - file: salt-runtime-directory

salt-mas-runtime:
  file.managed:
    - name: {{ runtime_dir }}/mas.runtime.yaml
    - source: salt://matrix/mas/runtime.yaml.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - show_changes: false
    - require:
      - file: salt-runtime-directory

salt-mas-environment:
  file.managed:
    - name: {{ runtime_dir }}/mas.environment
    - contents: |
        RUST_LOG={{ mas["rust_log"] }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0644'
    - show_changes: false
    - require:
      - file: salt-runtime-directory

# Initial PostgreSQL environment and application configs share these private Pillar passwords.
{% for role, key in (
  ("postgres", "POSTGRES_PASSWORD"),
  ("synapse", "SYNAPSE_DB_PASSWORD"),
  ("mas", "MAS_DB_PASSWORD")
) %}
{% set name = role ~ (".secrets.env" if role == "postgres" else "-db.secrets.env") %}
salt-secret-{{ name|replace(".", "-")|replace("_", "-") }}:
  file.managed:
    - name: {{ secrets_dir }}/{{ name }}
    - contents: |
        {{ key }}={{ vars["role_passwords"][role] }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - show_changes: false
    - require:
      - file: salt-secrets-directory
{% endfor %}

salt-secret-lk-jwt-secrets-env:
  file.managed:
    - name: {{ secrets_dir }}/lk-jwt.secrets.env
    - contents: |
        LIVEKIT_KEY={{ pillar["rtc"]["key"] }}
        LIVEKIT_SECRET={{ pillar["rtc"]["secret"] }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0600'
    - show_changes: false
    - require:
      - file: salt-secrets-directory

{% for name, mode in (
  ("synapse_signing.key", "0444"),
  ("mas_signing.key", "0444")
) %}
salt-secret-{{ name|replace(".", "-")|replace("_", "-") }}:
  file.managed:
    - name: {{ secrets_dir }}/{{ name }}
    - source: salt://hosts/{{ target }}/secrets/{{ name }}
    - user: ubuntu
    - group: ubuntu
    - mode: '{{ mode }}'
    - show_changes: false
    - require:
      - file: salt-secrets-directory
{% endfor %}

# The database states and application configs consume the same password mapping.
{% from 'postgres/passwords.jinja' import passwords with context %}
{% for name, role in (
  ("synapse.secrets.json", "synapse"),
  ("mas.secrets.json", "mas")
) %}
salt-secret-{{ name|replace(".", "-")|replace("_", "-") }}:
  file.managed:
    - name: {{ secrets_dir }}/{{ name }}
    - source: salt://matrix/{{ role }}/secrets.json.j2
    - template: jinja
    - context:
        db_password: {{ passwords[role] | tojson }}
    - user: ubuntu
    - group: ubuntu
    - mode: '0444'
    - show_changes: false
    - require:
      - file: salt-secrets-directory
{% endfor %}

salt-secret-lk-jwt-appservice-yaml:
  file.managed:
    - name: {{ secrets_dir }}/lk-jwt.appservice.yaml
    - source: salt://matrix/lk-jwt/appservice.yaml.j2
    - template: jinja
    - user: ubuntu
    - group: ubuntu
    - mode: '0444'
    - show_changes: false
    - require:
      - file: salt-secrets-directory
